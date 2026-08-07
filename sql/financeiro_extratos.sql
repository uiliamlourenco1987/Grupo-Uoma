-- ============================================================
-- Financeiro · Extratos bancários por empresa
-- Banco do RH (projeto gpgycgkqkzedoyilrsmw)
-- Rode UMA vez no SQL Editor do Supabase.
--
-- Cria: bucket de arquivos "extratos" (privado), a tabela de metadados
-- e as permissões (só Financeiro e Diretoria leem/enviam/apagam).
-- ============================================================

create extension if not exists pgcrypto;

-- Quem pode mexer no financeiro: perfil "financeiro" ou diretoria.
create or replace function public.is_fin_ou_dir() returns boolean
  language sql stable security definer set search_path=public as $$
  select coalesce((
    select (u.permissoes->>'perfil')='financeiro' or u.role='diretoria'
    from public.usuarios u where u.id = auth.uid()
  ), false);
$$;

-- Bucket privado pros arquivos de extrato.
insert into storage.buckets (id, name, public)
values ('extratos','extratos', false)
on conflict (id) do nothing;

-- Metadados de cada extrato enviado.
create table if not exists public.extratos(
  id            uuid primary key default gen_random_uuid(),
  empresa       text not null,            -- 'loja' | 'padoquinha' | 'merenda'
  competencia   text not null,            -- 'AAAA-MM'
  banco         text,
  arquivo_path  text not null,            -- caminho no bucket 'extratos'
  arquivo_nome  text,
  obs           text,
  criado_por    uuid default auth.uid(),
  criado_em     timestamptz not null default now()
);
alter table public.extratos enable row level security;

drop policy if exists extratos_rw on public.extratos;
create policy extratos_rw on public.extratos
  for all to authenticated
  using (is_fin_ou_dir())
  with check (is_fin_ou_dir());

-- Permissões nos ARQUIVOS do bucket (storage.objects).
drop policy if exists extratos_obj_read on storage.objects;
create policy extratos_obj_read on storage.objects
  for select to authenticated
  using (bucket_id='extratos' and is_fin_ou_dir());

drop policy if exists extratos_obj_write on storage.objects;
create policy extratos_obj_write on storage.objects
  for insert to authenticated
  with check (bucket_id='extratos' and is_fin_ou_dir());

drop policy if exists extratos_obj_del on storage.objects;
create policy extratos_obj_del on storage.objects
  for delete to authenticated
  using (bucket_id='extratos' and is_fin_ou_dir());
