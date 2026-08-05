# Robô de relatórios — Grupo Uoma

Lê relatórios padronizados de uma pasta do **Google Drive** e grava no **Supabase
do Faturamento** (`kopuvuhmqbpvlwksypgm`). Roda sozinho via GitHub Actions.

## FASE 1 (segura)
Começa pelo **Desempenho** → grava numa tabela própria `robo_desempenho`
(NÃO mexe no faturamento que já funciona). Depois ligamos essa tabela no app.

## SQL — rodar no projeto do FATURAMENTO (kopuvuhmqbpvlwksypgm)
```sql
-- espelha o relatório de desempenho 1:1 (mesmos nomes de coluna)
drop table if exists robo_desempenho;
create table robo_desempenho (
  competencia text not null,
  empresa text, codigo text, vendedor text not null,
  vendas numeric, custo numeric, lucro numeric,
  positivacao int, vendamedia numeric,
  peso numeric, mixproduto int,
  carteiraclientes int, clientesatendidos int, qtddevolucao int,
  por_clientecompraram numeric, clientesnaocompraram numeric, clientesnovos int,
  areceber numeric, totalavencer numeric, totalvencidos numeric, totaltransito numeric,
  inadimplencia numeric,
  arquivo text, importado_em timestamptz default now(),
  primary key (competencia, vendedor)
);

create table if not exists robo_arquivos (
  file_id text primary key,
  nome text,
  modificado text,
  processado_em timestamptz default now()
);
```

## Segredos (GitHub → Settings → Secrets and variables → Actions)
- `GOOGLE_CREDS_JSON`     — conteúdo do .json da conta-robô
- `SUPABASE_URL`          — https://kopuvuhmqbpvlwksypgm.supabase.co
- `SUPABASE_SERVICE_KEY`  — service_role do projeto do faturamento
- `DRIVE_FOLDER_ID`       — id da pasta compartilhada no Drive

## Rodar
Automático a cada 15 min, ou manual em Actions → robo-relatorios → Run workflow.
