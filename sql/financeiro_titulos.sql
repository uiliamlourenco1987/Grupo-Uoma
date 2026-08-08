-- ============================================================
-- Financeiro · Contas a Receber (títulos)
-- Banco do RH (projeto gpgycgkqkzedoyilrsmw)
-- Rode UMA vez no SQL Editor do Supabase.
-- ============================================================

create extension if not exists pgcrypto;

-- Quem pode mexer no financeiro (financeiro ou diretoria).
create or replace function public.is_fin_ou_dir() returns boolean
  language sql stable security definer set search_path=public as $$
  select coalesce((
    select (u.permissoes->>'perfil')='financeiro' or u.role='diretoria'
    from public.usuarios u where u.id = auth.uid()
  ), false);
$$;

create table if not exists public.titulos_receber(
  id             uuid primary key default gen_random_uuid(),
  empresa        text not null,             -- 'loja' | 'padoquinha' | 'merenda'
  cliente        text not null,
  documento      text not null default '',  -- nº da NF/título (identifica o título)
  emissao        date,
  vencimento     date,
  valor          numeric not null default 0,
  pago           boolean not null default false,
  data_pagamento date,
  vendedor       text,
  obs            text,
  criado_por     uuid default auth.uid(),
  atualizado_em  timestamptz not null default now(),
  unique(empresa, documento)               -- reimportar atualiza pelo par empresa+documento
);
alter table public.titulos_receber enable row level security;

drop policy if exists tr_rw on public.titulos_receber;
create policy tr_rw on public.titulos_receber
  for all to authenticated
  using (is_fin_ou_dir())
  with check (is_fin_ou_dir());
