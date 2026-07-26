-- ============================================================
--  minha_folha()  —  RODAR NO SUPABASE DO RH (projeto gpgycgkqkzedoyilrsmw)
--  SQL Editor > New query > colar tudo > Run.
--
--  Por quê: a tabela `folha` tem RLS que só deixa o RH ler a folha inteira.
--  O painel do colaborador precisa que CADA pessoa veja SÓ o PRÓPRIO holerite.
--  Esta função SECURITY DEFINER descobre quem está logado (usuarios.nome =
--  auth.uid()), acha a folha dela pelo nome (normalizado) na competência mais
--  recente e devolve só a linha dela (como JSON) — nunca a dos outros.
-- ============================================================

create extension if not exists unaccent;

create or replace function public.minha_folha(p_comp text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nome text;
  v_key  text;
  v_comp text;
  v_row  jsonb;
begin
  select nome into v_nome from usuarios where id = auth.uid();
  if v_nome is null then return null; end if;
  v_key := upper(unaccent(btrim(v_nome)));

  v_comp := coalesce(
    p_comp,
    (select f.competencia from folha f
       where upper(unaccent(btrim(f.nome))) = v_key
       order by to_date('01/'||f.competencia,'DD/MM/YYYY') desc
       limit 1)
  );
  if v_comp is null then return null; end if;

  select to_jsonb(f) into v_row
  from folha f
  where upper(unaccent(btrim(f.nome))) = v_key
    and f.competencia = v_comp
  order by to_date('01/'||f.competencia,'DD/MM/YYYY') desc
  limit 1;

  return v_row;
end
$$;

grant execute on function public.minha_folha(text) to authenticated;
