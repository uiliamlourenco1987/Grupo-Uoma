-- ============================================================
-- Banco de índices mensais (indices_mensais)
-- RODAR NO BANCO DO FATURAMENTO -> kopuvuhmqbpvlwksypgm
-- Uma linha por: competência × escopo × chave.
--   escopo = GERAL (chave '') | EQUIPE (chave EXTERNO/INTERNO) | VENDEDOR (chave = nome)
-- O botão "🧮 Gerar índices do mês" no app preenche/atualiza esta tabela.
-- Rodar UMA vez.
-- ============================================================
create table if not exists public.indices_mensais(
  competencia    text    not null,           -- '2026-08'
  escopo         text    not null,           -- GERAL | EQUIPE | VENDEDOR
  chave          text    not null default '',-- '' | EXTERNO/INTERNO | nome do vendedor
  faturamento    numeric default 0,
  notas          int     default 0,          -- nº de notas (DOC) distintas
  ticket_medio   numeric default 0,          -- faturamento ÷ notas
  mix_produtos   int     default 0,          -- produtos diferentes (CODPRO)
  mix_por_nota   numeric default 0,          -- média de produtos distintos por nota (ticket de produto por nota)
  itens_por_nota numeric default 0,          -- média de unidades por nota
  posit_pct      numeric default 0,
  clientes_atend int     default 0,
  carteira       int     default 0,
  inad_pct       numeric default 0,
  areceber       numeric default 0,
  vencido        numeric default 0,
  transito       numeric default 0,
  peso           numeric default 0,
  atualizado_em  timestamptz default now(),
  primary key (competencia, escopo, chave)
);

alter table public.indices_mensais enable row level security;
grant select, insert, update, delete on public.indices_mensais to anon, authenticated;

drop policy if exists im_read on public.indices_mensais;
create policy im_read on public.indices_mensais for select using (true);
drop policy if exists im_write on public.indices_mensais;
create policy im_write on public.indices_mensais for insert with check (true);
drop policy if exists im_upd on public.indices_mensais;
create policy im_upd on public.indices_mensais for update using (true) with check (true);
drop policy if exists im_del on public.indices_mensais;
create policy im_del on public.indices_mensais for delete using (true);

create index if not exists indices_mensais_comp_idx on public.indices_mensais(competencia);
