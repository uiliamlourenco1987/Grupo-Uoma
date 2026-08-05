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
        scopes=["https://www.googleapis.com/auth/drive.readonly"])
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

def baixar(svc, fid, nome):
    req = svc.files().get_media(fileId=fid, supportsAllDrives=True)
    buf = io.BytesIO(); dl = MediaIoBaseDownload(buf, req)
    done = False
    while not done:
        _, done = dl.next_chunk()
    p = os.path.join(tempfile.gettempdir(), nome)
    with open(p, "wb") as f: f.write(buf.getvalue())
    return p

def main():
    svc = drive()
    japroc = sb_get_processados()
    res = svc.files().list(q=f"'{FOLDER}' in parents and trashed=false",
                           fields="files(id,name,modifiedTime)", pageSize=200,
                           supportsAllDrives=True, includeItemsFromAllDrives=True).execute()
    arquivos = res.get("files", [])
    print(f"{len(arquivos)} arquivo(s) na pasta · competência {COMP}")
    novos = 0
    for a in arquivos:
        fid, nome, mod = a["id"], a["name"], a.get("modifiedTime")
        low = nome.lower()
        if japroc.get(fid) == mod:
            continue  # já processado (e não mudou)
        try:
            if "desempenho" in low and low.endswith(".csv"):
                p = baixar(svc, fid, nome)
                rows = parsers.parse_desempenho(p)
                payload = [dict(r, competencia=COMP, arquivo=nome) for r in rows]
                sb_upsert("robo_desempenho", payload, "competencia,vendedor")
                print(f"  ✓ {nome}: {len(payload)} vendedores gravados")
                novos += 1
            else:
                print(f"  · ignorado (sem handler ainda): {nome}")
                continue
            sb_upsert("robo_arquivos", [{"file_id": fid, "nome": nome, "modificado": mod}], "file_id")
        except Exception as e:
            print(f"  ✗ ERRO em {nome}: {e}")
    print(f"Concluído. {novos} arquivo(s) novo(s) processado(s).")

if __name__ == "__main__":
    main()
