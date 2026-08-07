-- ============================================================
-- Perfis & Autoridade (5 níveis por função)
-- Banco do RH (projeto gpgycgkqkzedoyilrsmw)
-- Rode UMA vez no SQL Editor do Supabase.
--
-- Escala por função: 0 Sem acesso · 1 Ver · 2 Operar · 3 Gerenciar · 4 Total
-- Cada perfil guarda um mapa { "funcao": nivel } em `autoridade` (jsonb).
-- A tela de Acessos (aba "Perfis & Autoridade") cria/edita isso.
-- ============================================================

create table if not exists public.perfis(
  slug          text primary key,
  nome          text not null,
  emoji         text default '👤',
  protegido     boolean not null default false,
  autoridade    jsonb   not null default '{}'::jsonb,
  atualizado_em timestamptz not null default now()
);

alter table public.perfis enable row level security;

-- Leitura: qualquer usuário autenticado (o portal precisa ler pra montar o menu de cada um).
drop policy if exists perfis_read on public.perfis;
create policy perfis_read on public.perfis
  for select to authenticated using (true);

-- Escrita (criar/editar/apagar perfis): só diretoria.
drop policy if exists perfis_write on public.perfis;
create policy perfis_write on public.perfis
  for all to authenticated
  using (is_diretoria())
  with check (is_diretoria());

-- ---- Seed dos perfis padrão (não sobrescreve se já existirem) --------------
insert into public.perfis(slug,nome,emoji,protegido,autoridade) values
  ('vendedor','Vendedor','🧑‍💼',false,
    '{"minha_meta":1,"campanhas":1,"solucoes":2,"avaliar_colegas":2,"fale_diretoria":2}'::jsonb),
  ('supervisao','Supervisão','🎖️',false,
    '{"metas":1,"campanhas":1,"painel_vendas":1,"separacao":1,"avaliacoes":1,"solucoes":2,"avaliar_colegas":2,"fale_diretoria":2}'::jsonb),
  ('faturamento','Faturamento / Depósito','🧾',false,
    '{"metas":2,"importar":2,"campanhas":1,"faturamento":3,"separacao":2,"sep_deposito":2,"sep_loja":2,"painel_sep":1,"painel_vendas":1,"estoque":1,"solucoes":2,"avaliar_colegas":2,"fale_diretoria":2}'::jsonb),
  ('rh','RH','🛡️',false,
    '{"metas":1,"regras":3,"importar":2,"campanhas":1,"avaliacoes":4,"folha":4,"acessos":3,"solucoes":2,"avaliar_colegas":2,"fale_diretoria":2}'::jsonb),
  ('financeiro','Financeiro','💵',false,
    '{"financeiro":3,"faturamento":1,"solucoes":2,"avaliar_colegas":2,"fale_diretoria":2}'::jsonb),
  ('colaborador','Colaborador','👤',false,
    '{"solucoes":2,"avaliar_colegas":2,"fale_diretoria":2}'::jsonb),
  ('producao','Produção','🍞',false,
    '{"solucoes":2,"avaliar_colegas":2,"fale_diretoria":2}'::jsonb),
  ('compradores','Compradores','🛒',false,
    '{"estoque":2,"solucoes":2,"avaliar_colegas":2,"fale_diretoria":2}'::jsonb),
  ('diretoria','Diretoria','👑',true,'{}'::jsonb)
on conflict (slug) do nothing;

-- Diretoria é tratada como autoridade TOTAL no código (perfil/role = diretoria),
-- por isso o mapa dela fica vazio e protegido.
