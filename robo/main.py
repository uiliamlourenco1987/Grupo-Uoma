#!/usr/bin/env python3
"""
Robô Grupo Uoma — lê relatórios de uma pasta do Google Drive e grava no Supabase.
FASE 1 (segura): grava o Desempenho numa tabela própria (robo_desempenho),
sem tocar no faturamento que já funciona. Depois ligamos essa tabela no app.

Segredos (via variáveis de ambiente / GitHub Secrets):
  GOOGLE_CREDS_JSON     -> conteúdo do .json da conta-robô
  SUPABASE_URL          -> https://kopuvuhmqbpvlwksypgm.supabase.co
  SUPABASE_SERVICE_KEY  -> chave service_role do projeto
  DRIVE_FOLDER_ID       -> id da pasta compartilhada no Drive
  COMPETENCIA           -> (opcional) 'AAAA-MM'; se vazio, usa o mês atual
"""
import os, json, tempfile
from datetime import datetime
import requests
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload
import io
import parsers

SB_URL = os.environ["SUPABASE_URL"].rstrip("/")
SB_KEY = os.environ["SUPABASE_SERVICE_KEY"]
FOLDER = os.environ["DRIVE_FOLDER_ID"]
COMP   = os.environ.get("COMPETENCIA") or datetime.now().strftime("%Y-%m")
SBH = {"apikey": SB_KEY, "Authorization": f"Bearer {SB_KEY}", "Content-Type": "application/json"}

def drive():
    creds = service_account.Credentials.from_service_account_info(
        json.loads(os.environ["GOOGLE_CREDS_JSON"]),
        scopes=["https://www.googleapis.com/auth/drive"])
    return build("drive", "v3", credentials=creds, cache_discovery=False)

def sb_get_processados():
    r = requests.get(f"{SB_URL}/rest/v1/robo_arquivos?select=file_id,modificado", headers=SBH, timeout=30)
    r.raise_for_status()
    return {x["file_id"]: x.get("modificado") for x in r.json()}

def sb_upsert(table, rows, on_conflict):
    if not rows: return
    h = dict(SBH); h["Prefer"] = "resolution=merge-duplicates"
    r = requests.post(f"{SB_URL}/rest/v1/{table}?on_conflict={on_conflict}",
                      headers=h, data=json.dumps(rows), timeout=60)
    r.raise_for_status()

def baixar(svc, a):
    fid, nome, mime = a["id"], a["name"], a.get("mimeType", "")
    if mime == "application/vnd.google-apps.spreadsheet":
        req = svc.files().export_media(fileId=fid, mimeType="text/csv")   # CSV virou planilha Google
    else:
        req = svc.files().get_media(fileId=fid, supportsAllDrives=True)
    buf = io.BytesIO(); dl = MediaIoBaseDownload(buf, req)
    done = False
    while not done:
        _, done = dl.next_chunk()
    fname = nome if "." in nome else nome + ".csv"
    p = os.path.join(tempfile.gettempdir(), fname)
    with open(p, "wb") as f: f.write(buf.getvalue())
    return p

def _norm(s):
    import unicodedata
    return ''.join(c for c in unicodedata.normalize('NFD', (s or '').lower()) if c.isalnum())

def achar_subpastas(svc):
    """Descobre subpastas 'Não Processados' (entrada) e 'Processados' (destino)."""
    res = svc.files().list(
        q=f"'{FOLDER}' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false",
        fields="files(id,name)", supportsAllDrives=True, includeItemsFromAllDrives=True).execute()
    inbox = done = None
    for f in res.get("files", []):
        n = _norm(f["name"])
        if n.startswith("nao") or "aprocessar" in n:      # "Não Processados" / "A Processar"
            inbox = f
        elif "processad" in n:                            # "Processados"
            done = f
    return inbox, done

def mover(svc, fid, de, para):
    svc.files().update(fileId=fid, addParents=para, removeParents=de,
                       supportsAllDrives=True, fields="id").execute()

def main():
    svc = drive()
    japroc = sb_get_processados()
    inbox, done = achar_subpastas(svc)
    src = inbox["id"] if inbox else FOLDER
    print(f"Lendo de: {inbox['name'] if inbox else 'pasta principal'}"
          + (f" · movendo processados p/ '{done['name']}'" if done else " · (sem pasta Processados — não vou mover)"))
    res = svc.files().list(
        q=f"'{src}' in parents and trashed=false and mimeType!='application/vnd.google-apps.folder'",
        fields="files(id,name,modifiedTime,mimeType)", pageSize=200,
        supportsAllDrives=True, includeItemsFromAllDrives=True).execute()
    arquivos = res.get("files", [])
    print(f"{len(arquivos)} arquivo(s) a processar · competência {COMP}")
    for a in arquivos:
        print(f"   - {a['name']}  [{a.get('mimeType')}]")
    novos = 0
    for a in arquivos:
        fid, nome, mod = a["id"], a["name"], a.get("modifiedTime")
        if a.get("mimeType") == "application/vnd.google-apps.folder":
            continue
        if japroc.get(fid) == mod:
            print(f"  = já processado (sem mudança): {nome}")
            if done:
                try:
                    mover(svc, fid, src, done["id"])
                    print(f"    → movido para '{done['name']}'")
                except Exception as e:
                    print(f"    (não consegui mover: {e})")
            continue
        try:
            p = baixar(svc, a)
            head = open(p, "rb").read(2000).decode("latin-1", "replace").upper()
            # reconhece pelo CONTEÚDO (colunas), não pelo nome do arquivo
            if "POSITIVACAO" in head and "INADIMPLENCIA" in head:
                rows = parsers.parse_desempenho(p)
                payload = [dict(r, competencia=COMP, arquivo=nome) for r in rows]
                sb_upsert("robo_desempenho", payload, "competencia,vendedor")
                print(f"  ✓ Desempenho '{nome}': {len(payload)} vendedores gravados")
                novos += 1
            elif "CODPRO" in head and "IDENTIFICADOR" in head and "MARCA" in head:
                rows = parsers.parse_vendas(p)
                from collections import Counter
                meses = Counter(r["data"][:7] for r in rows if r.get("data"))
                comp = meses.most_common(1)[0][0] if meses else COMP
                payload = [dict(r, competencia=comp, arquivo=nome) for r in rows]
                for i in range(0, len(payload), 500):
                    sb_upsert("robo_vendas", payload[i:i + 500], "identificador")
                print(f"  ✓ Vendas '{nome}': {len(payload)} itens (competência {comp})")
                novos += 1
            else:
                print(f"  · ignorado (não reconheci o relatório): {nome}")
                continue
            sb_upsert("robo_arquivos", [{"file_id": fid, "nome": nome, "modificado": mod}], "file_id")
            if done:
                try:
                    mover(svc, fid, src, done["id"])
                    print(f"    → movido para '{done['name']}'")
                except Exception as e:
                    print(f"    (não consegui mover — a conta-robô precisa de acesso de Editor: {e})")
        except Exception as e:
            print(f"  ✗ ERRO em {nome}: {e}")
    print(f"Concluído. {novos} arquivo(s) novo(s) processado(s).")

if __name__ == "__main__":
    main()
