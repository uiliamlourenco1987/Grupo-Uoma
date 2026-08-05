-- ============================================================
-- Log central do sistema (app_log)
-- RODAR NO BANCO DO FATURAMENTO  ->  kopuvuhmqbpvlwksypgm
-- (é o banco que o app e o robô já usam. O portal, mesmo sendo
--  do banco do RH, grava os erros dele NESTE mesmo app_log.)
-- Basta rodar UMA vez. Não mexe em nenhuma outra tabela.
-- ============================================================
create table if not exists public.app_log(
  id       bigint generated always as identity primary key,
  t        timestamptz not null default now(),
  tipo     text not null default 'info',   -- erro | aviso | info
  msg      text not null default '',
  quem     text default '',
  ver      text default '',
  aparelho text default '',
  origem   text default 'app'              -- app | portal | robo
);

alter table public.app_log enable row level security;
grant select, insert on public.app_log to anon, authenticated;

drop policy if exists app_log_read  on public.app_log;
create policy app_log_read  on public.app_log for select using (true);

drop policy if exists app_log_write on public.app_log;
create policy app_log_write on public.app_log for insert with check (true);

create index if not exists app_log_t_idx on public.app_log(t desc);
