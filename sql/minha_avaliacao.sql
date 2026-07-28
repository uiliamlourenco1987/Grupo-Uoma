-- ============================================================
--  minha_avaliacao()  —  RODAR NO SUPABASE DO RH (projeto gpgycgkqkzedoyilrsmw)
--  SQL Editor > New query > colar tudo > Run.  (CREATE OR REPLACE: pode re-rodar)
--
--  Cada pessoa vê SÓ a própria nota (contorna o RLS das tabelas aval_*).
--  Retorna: nota do mês + posição no ranking + média geral da EMPRESA e do GRUPO.
--  Regras da DIRETORIA (usuarios.role='diretoria'):
--    • NÃO leva o -25 por não avaliar;  • fica FORA do ranking e das médias;
--    • a nota do diretor só aparece pra ele mesmo.
-- ============================================================

create extension if not exists unaccent;

create or replace function public.minha_avaliacao(p_comp text default null)
returns table(
  competencia text, nota int, media_pares numeric,
  faltas int, atrasos int, suspensoes int, advertencias int, obs text,
  posicao int, total int,
  media_empresa numeric, media_grupo numeric
)
language plpgsql security definer set search_path = public as $$
declare v_nome text; v_key text; v_comp text; v_houve boolean; v_dir text[];
begin
  select nome into v_nome from usuarios where id = auth.uid();
  if v_nome is null then return; end if;
  v_key := upper(unaccent(btrim(v_nome)));

  select coalesce(array_agg(upper(unaccent(btrim(nome)))), '{}') into v_dir
  from usuarios where role = 'diretoria';

  v_comp := coalesce(
    p_comp,
    (select r.competencia from aval_rh r where upper(unaccent(btrim(r.nome)))=v_key
       order by to_date('01/'||r.competencia,'DD/MM/YYYY') desc limit 1),
    (select x.competencia from aval_ranking x where upper(unaccent(btrim(x.nome)))=v_key
       order by to_date('01/'||x.competencia,'DD/MM/YYYY') desc limit 1)
  );
  if v_comp is null then return; end if;

  v_houve := exists(select 1 from aval_respostas where competencia = v_comp);

  return query
  with rh as (select * from aval_rh where competencia = v_comp),
  rk as (select nome, empresa, media from aval_ranking where competencia = v_comp),
  base as (
    select upper(unaccent(btrim(coalesce(rh.nome, rk.nome)))) as k,
      coalesce(rh.empresa, rk.empresa) as empresa, rk.media as media,
      coalesce(rh.faltas,0) f, coalesce(rh.atrasos,0) a, coalesce(rh.suspensoes,0) s,
      coalesce(rh.advertencias,0) adv, coalesce(rh.comunicacao_rh,0) crh,
      coalesce(rh.cordialidade,0) cord, rh.obs
    from rh full outer join rk on upper(unaccent(btrim(rh.nome)))=upper(unaccent(btrim(rk.nome)))
  ),
  scored as (
    select b.*,
      (v_houve and not (b.k = any(v_dir)) and not exists(
         select 1 from aval_respostas ar where ar.competencia=v_comp
           and upper(unaccent(btrim(ar.avaliador)))=b.k)) as pen,
      greatest(0, least(100, 80 - b.f*5 - b.a*2 - b.s*15 - b.adv*8 + b.crh + b.cord)) as scrh,
      case when b.media is not null then b.media/5*100 else null end as scp
    from base b
  ),
  fin as (
    select sc.*, greatest(0, coalesce(
        case when scrh is not null and scp is not null then scrh*0.7 + scp*0.3
             when scp is not null then scp*0.3 else scrh*0.7 end, 0)
      + case when pen then -25 else 0 end) as notaf
    from scored sc
  ),
  ranked as (
    select f.*, rank() over (partition by f.empresa order by f.notaf desc) as pos,
                count(*) over (partition by f.empresa) as tot
    from fin f where not (f.k = any(v_dir))
  )
  select v_comp, round(fc.notaf)::int, fc.media, fc.f, fc.a, fc.s, fc.adv, fc.obs,
         rk2.pos::int, rk2.tot::int,
         (select round(avg(f2.notaf),1) from fin f2 where not (f2.k = any(v_dir)) and f2.empresa = fc.empresa) as media_empresa,
         (select round(avg(f3.notaf),1) from fin f3 where not (f3.k = any(v_dir))) as media_grupo
  from fin fc left join ranked rk2 on rk2.k = fc.k
  where fc.k = v_key
  limit 1;
end $$;

grant execute on function public.minha_avaliacao(text) to authenticated;
