-- ============================================================
--  rh_acessos.sql  —  RODAR NO SUPABASE DO RH (projeto gpgycgkqkzedoyilrsmw)
--  SQL Editor > New query > colar tudo > Run.  (pode re-rodar)
--
--  Deixa o pessoal do RH (cargo RH) VALIDAR/CRIAR os cadastros de acesso,
--  MAS sem poder mexer na diretoria (não cria diretor nem se promove).
--  Não altera as policies existentes da diretoria — só ADICIONA as do RH
--  (RLS é permissivo: as policies somam com OU).
-- ============================================================

-- Quem está logado tem cargo RH?
create or replace function public.is_rh() returns boolean
language sql security definer set search_path = public stable as $$
  select exists(select 1 from usuarios where id = auth.uid()
                and (permissoes->>'perfil') = 'rh');
$$;
grant execute on function public.is_rh() to authenticated;

-- RH enxerga todos (pra listar no Controle de Acessos)
drop policy if exists usuarios_rh_sel on usuarios;
create policy usuarios_rh_sel on usuarios for select to authenticated
  using (is_rh());

-- RH cria acessos — menos diretoria
drop policy if exists usuarios_rh_ins on usuarios;
create policy usuarios_rh_ins on usuarios for insert to authenticated
  with check (is_rh() and coalesce(role,'') <> 'diretoria');

-- RH edita acessos — nunca linhas de diretoria, nem promove a diretoria
drop policy if exists usuarios_rh_upd on usuarios;
create policy usuarios_rh_upd on usuarios for update to authenticated
  using (is_rh() and coalesce(role,'') <> 'diretoria')
  with check (is_rh() and coalesce(role,'') <> 'diretoria');

-- A função de criar login (usada pelo botão do portal) passa a aceitar RH,
-- mas o RH não pode criar/gravar diretoria.
create or replace function public.portal_criar_usuario(
  p_id uuid, p_email text, p_nome text,
  p_empresas text default 'todas', p_role text default 'visualizacao',
  p_permissoes jsonb default '{}'::jsonb
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not (is_diretoria() or is_rh()) then
    raise exception 'Sem permissão: apenas diretoria ou RH podem cadastrar acessos.';
  end if;
  if is_rh() and not is_diretoria() and coalesce(p_role,'') = 'diretoria' then
    raise exception 'O RH não pode criar/definir acessos de diretoria.';
  end if;
  insert into usuarios (id, email, nome, empresas, role, permissoes)
  values (p_id, p_email, p_nome,
    coalesce(p_empresas,'todas'), coalesce(p_role,'visualizacao'), coalesce(p_permissoes,'{}'::jsonb))
  on conflict (id) do update set
    email = excluded.email, nome = excluded.nome, empresas = excluded.empresas,
    role = excluded.role, permissoes = excluded.permissoes;
end $$;
grant execute on function public.portal_criar_usuario(uuid,text,text,text,text,jsonb) to authenticated;
