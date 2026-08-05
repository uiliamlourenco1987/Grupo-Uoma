# Robô de relatórios — Grupo Uoma

Lê relatórios padronizados de uma pasta do **Google Drive** e grava no **Supabase
do Faturamento** (`kopuvuhmqbpvlwksypgm`). Roda sozinho via GitHub Actions.

## FASE 1 (segura)
Começa pelo **Desempenho** → grava numa tabela própria `robo_desempenho`
(NÃO mexe no faturamento que já funciona). Depois ligamos essa tabela no app.

## SQL — rodar no projeto do FATURAMENTO (kopuvuhmqbpvlwksypgm)
```sql
create table if not exists robo_desempenho (
  competencia text not null,
  vendedor    text not null,
  codigo      text,
  vendas numeric, positivacao int, peso numeric, mix int,
  carteira int, atendidos int,
  areceber numeric, vencido numeric, transito numeric, inad numeric,
  arquivo text,
  importado_em timestamptz default now(),
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
