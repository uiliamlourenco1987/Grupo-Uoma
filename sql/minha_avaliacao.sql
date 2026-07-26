-- ============================================================
--  minha_avaliacao()  —  RODAR NO SUPABASE DO RH (projeto gpgycgkqkzedoyilrsmw)
--  SQL Editor > New query > colar tudo > Run.
--
--  Por quê: as tabelas de avaliação (aval_rh, aval_ranking) têm RLS que só
--  deixa o RH ler. O painel do Vendedor precisa que CADA pessoa veja SÓ a
--  PRÓPRIA nota. Esta função SECURITY DEFINER faz exatamente isso: descobre
--  quem está logado (usuarios.nome = auth.uid()), acha a avaliação dela pelo
--  nome (normalizado) e devolve só a linha dela — nunca a dos outros.
--
--  A nota segue a MESMA fórmula do app do RH (calcRanking):
--    scRH = clamp(80 - faltas*5 - atrasos*2 - suspensoes*15 - advertencias*8
--                 + comunicacao_rh + cordialidade, 0..100)
--    scP  = media_dos_pares/5*100
--    nota = scRH*0.7 + scP*0.3  (-25 se a pessoa não respondeu a avaliação
--                                 dos colegas naquela competência)
--  A posição é o ranking dentro da empresa da pessoa, naquela competência.
-- ============================================================

create extension if not exists unaccent;

create or replace function public.minha_avaliacao(p_comp text default null)
returns table(
  competencia   text,
  nota          int,
  media_pares   numeric,
  faltas        int,
  atrasos       int,
  suspensoes    int,
  advertencias  int,
  obs           text,
  posicao       int,
  total         int
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nome  text;
  v_key   text;
  v_comp  text;
  v_houve boolean;
begin
  -- quem está logado
  select nome into v_nome from usuarios where id = auth.uid();
  if v_nome is null then return; end if;
  v_key := upper(unaccent(btrim(v_nome)));

  -- competência: a informada, senão a mais recente que a pessoa tem
  v_comp := coalesce(
    p_comp,
    (select r.competencia from aval_rh r
       where upper(unaccent(btrim(r.nome))) = v_key
       order by to_date('01/'||r.competencia,'DD/MM/YYYY') desc limit 1),
    (select x.competencia from aval_ranking x
       where upper(unaccent(btrim(x.nome))) = v_key
       order by to_date('01/'||x.competencia,'DD/MM/YYYY') desc limit 1)
  );
  if v_comp is null then return; end if;

  v_houve := exists(select 1 from aval_respostas where competencia = v_comp);

  return query
  with rh as (select * from aval_rh where competencia = v_comp),
  rk as (select nome, empresa, media from aval_ranking where competencia = v_comp),
  base as (
    select
      upper(unaccent(btrim(coalesce(rh.nome, rk.nome)))) as k,
      coalesce(rh.empresa, rk.empresa)                    as empresa,
      rk.media                                            as media,
      coalesce(rh.faltas,0)        as f,
      coalesce(rh.atrasos,0)       as a,
      coalesce(rh.suspensoes,0)    as s,
      coalesce(rh.advertencias,0)  as adv,
      coalesce(rh.comunicacao_rh,0) as crh,
      coalesce(rh.cordialidade,0)  as cord,
      rh.obs                       as obs
    from rh
    full outer join rk
      on upper(unaccent(btrim(rh.nome))) = upper(unaccent(btrim(rk.nome)))
  ),
  scored as (
    select b.*,
      (v_houve and not exists(
         select 1 from aval_respostas ar
          where ar.competencia = v_comp
            and upper(unaccent(btrim(ar.avaliador))) = b.k)) as pen,
      greatest(0, least(100,
        80 - b.f*5 - b.a*2 - b.s*15 - b.adv*8 + b.crh + b.cord)) as scrh,
      case when b.media is not null then b.media/5*100 else null end as scp
    from base b
  ),
  fin as (
    select sc.*,
      greatest(0,
        coalesce(
          case
            when scrh is not null and scp is not null then scrh*0.7 + scp*0.3
            when scp  is not null                     then scp*0.3
            else scrh*0.7
          end, 0)
        + case when pen then -25 else 0 end
      ) as notaf
    from scored sc
  ),
  ranked as (
    select f.*,
           rank()  over (partition by f.empresa order by f.notaf desc) as pos,
           count(*) over (partition by f.empresa)                      as tot
    from fin f
  )
  select v_comp, round(r.notaf)::int, r.media, r.f, r.a, r.s, r.adv, r.obs, r.pos::int, r.tot::int
  from ranked r
  where r.k = v_key
  limit 1;
end
$$;

grant execute on function public.minha_avaliacao(text) to authenticated;
