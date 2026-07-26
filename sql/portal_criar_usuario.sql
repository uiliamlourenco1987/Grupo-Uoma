-- ============================================================
--  portal_criar_usuario()  —  RODAR NO SUPABASE DO RH (projeto gpgycgkqkzedoyilrsmw)
--  SQL Editor > New query > colar tudo > Run.  (pode re-rodar)
--
--  Por quê: a tabela `usuarios` tem FK para `auth.users(id)`. Ao criar um
--  colaborador PELO PORTAL, o insert é feito pelo papel `authenticated`, e a
--  validação da FK lê `auth.users` — papel que não tem esse privilégio →
--  "permission denied for table users". (No painel do Supabase funciona porque
--  usa o papel admin.) Esta função grava o perfil rodando como DONO
--  (SECURITY DEFINER), contornando a trava, e só permite que a DIRETORIA chame.
-- ============================================================

create or replace function public.portal_criar_usuario(
  p_id uuid,
  p_email text,
  p_nome text,
  p_empresas text default 'todas',
  p_role text default 'visualizacao',
  p_permissoes jsonb default '{}'::jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- só a diretoria pode criar/editar acessos (auth.uid() = quem chamou, mesmo em definer)
  if not is_diretoria() then
    raise exception 'Sem permissão: apenas a diretoria pode cadastrar acessos.';
  end if;

  insert into usuarios (id, email, nome, empresas, role, permissoes)
  values (
    p_id, p_email, p_nome,
    coalesce(p_empresas, 'todas'),
    coalesce(p_role, 'visualizacao'),
    coalesce(p_permissoes, '{}'::jsonb)
  )
  on conflict (id) do update set
    email      = excluded.email,
    nome       = excluded.nome,
    empresas   = excluded.empresas,
    role       = excluded.role,
    permissoes = excluded.permissoes;
end
$$;

grant execute on function public.portal_criar_usuario(uuid,text,text,text,text,jsonb) to authenticated;
