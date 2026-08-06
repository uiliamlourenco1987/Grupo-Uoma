-- ============================================================================
-- METAS NOVAS — esquema completo
-- RODAR NO BANCO DO RH  (projeto gpgycgkqkzedoyilrsmw)
--
-- Modelo: tudo em tabelas, amarrado pelo CÓDIGO do vendedor.
--   • Interno (você paga): vendedores, regras, fornecedor-bônus, metas mensais.
--   • Fornecedor: campanhas (critérios + metas por critério + participantes + link).
-- Regras/valores/% só o RH/Diretoria edita. Leitura pelos usuários logados.
-- Idempotente: pode rodar mais de uma vez.
-- ============================================================================

create extension if not exists pgcrypto;   -- p/ tokens dos links

-- ---------- Permissões (quem pode editar) ----------------------------------
-- Editor de REGRAS/VALORES/CAMPANHAS = Diretoria ou RH.
create or replace function public.mn_editor() returns boolean
  language sql stable as $$
  select coalesce((select (permissoes->>'perfil') in ('diretoria','rh') or role = 'diretoria'
                   from public.usuarios where id = auth.uid()), false);
$$;
-- Quem lança METAS do mês = Diretoria/RH/Faturamento/Supervisão.
create or replace function public.mn_gestor_metas() returns boolean
  language sql stable as $$
  select coalesce((select (permissoes->>'perfil') in ('diretoria','rh','faturamento','supervisao') or role = 'diretoria'
                   from public.usuarios where id = auth.uid()), false);
$$;

-- ============================================================================
-- 1) VENDEDORES  — a pessoa vem do RH; aqui só os atributos de venda (por código)
-- ============================================================================
create table if not exists public.vendedores(
  codigo        text primary key,                 -- CODVENDEDOR (chave de tudo)
  nome          text not null,
  setor         text not null default 'EXTERNO' check (setor in ('EXTERNO','INTERNO')),
  is_supervisor boolean not null default false,
  usuario_id    uuid,                             -- link opcional p/ usuarios(id) do RH
  ativo         boolean not null default true,
  criado_em     timestamptz default now()
);

-- ============================================================================
-- 2) REGRAS por setor  — os VALORES/% que definem o pagamento (só RH/Diretoria)
-- ============================================================================
create table if not exists public.metas_regras(
  setor                   text primary key check (setor in ('EXTERNO','INTERNO')),
  -- bônus por meta batida (valor + tipo R$/%)
  bonus_fat numeric default 120,  bonus_fat_tipo   text default 'R$',
  bonus_mix numeric default 100,  bonus_mix_tipo   text default 'R$',
  bonus_posit numeric default 100, bonus_posit_tipo text default 'R$',
  bonus_inad numeric default 200, bonus_inad_tipo  text default 'R$',
  -- alvos
  posit_alvo numeric default 90,                  -- % (>= 90% bate)
  inad_meta  numeric default 10,                  -- % (externo 10 / interno 5)
  inad_desconta_transito boolean default false,   -- FALSE = vencido ÷ a receber (regra real)
  -- trava de carteira (participa de posit/inad)
  min_clientes int default 30,
  min_carteira numeric default 20000,
  -- comissão de salário
  com_individual_pct numeric default 0,
  com_equipe_ativo   boolean default false,
  com_equipe_meta_pct numeric default 90,
  com_equipe_pct_acima numeric default 0.5,
  com_equipe_pct_abaixo numeric default 0.3,
  -- supervisor (só ganha se a EQUIPE bater)
  sup_base_pct   numeric default 0.8,             -- externo: % base
  sup_pp_fat numeric default 0.1, sup_pp_inad numeric default 0.1,
  sup_pp_mix numeric default 0.05, sup_pp_posit numeric default 0.05,
  sup_pp_teto numeric default 0.3,
  sup_valor_indice numeric default 100,           -- interno: R$ por índice batido
  atualizado_em timestamptz default now()
);
insert into public.metas_regras(setor) values ('EXTERNO') on conflict (setor) do nothing;
insert into public.metas_regras(setor, inad_meta) values ('INTERNO', 5) on conflict (setor) do nothing;

-- ============================================================================
-- 3) BÔNUS POR FORNECEDOR (interno, você paga) — valor por setor + critério
-- ============================================================================
create table if not exists public.metas_fornecedor_bonus(
  id bigint generated always as identity primary key,
  marca         text not null,
  criterio      text not null default 'FAT' check (criterio in ('FAT','PESO')),
  valor_externo numeric default 0,
  valor_interno numeric default 0,
  ativo         boolean default true,
  criado_em     timestamptz default now()
);
-- alvo individual do fornecedor, por vendedor e mês
create table if not exists public.metas_fornecedor_alvo(
  mes    text not null,
  codigo text not null references public.vendedores(codigo) on delete cascade,
  bonus_id bigint not null references public.metas_fornecedor_bonus(id) on delete cascade,
  alvo   numeric default 0,
  primary key (mes, codigo, bonus_id)
);

-- ============================================================================
-- 4) MESES + METAS MENSAIS (por vendedor)
-- ============================================================================
create table if not exists public.metas_meses(
  mes    text primary key,                        -- 'AAAA-MM'
  label  text,
  status text default 'andamento' check (status in ('andamento','fechado')),
  dias_uteis int default 0,
  dias_trab  int default 0,
  fechado_em timestamptz
);

create table if not exists public.metas_mensais(
  mes    text not null references public.metas_meses(mes) on delete cascade,
  codigo text not null references public.vendedores(codigo) on delete cascade,
  -- alvos
  obj_fat    numeric default 0,
  obj_mix    numeric default 0,
  meta_posit numeric default 0,       -- interno: nº de vendas alvo
  carteira   numeric default 0,       -- externo: carteira de clientes (base da positivação)
  -- realizado
  vendido    numeric default 0,
  mix_vend   numeric default 0,
  positivados numeric default 0,      -- ext: clientes positivados · int: nº de vendas
  peso       numeric default 0,
  recebido   numeric default 0,
  -- financeiro (inadimplência = vencido ÷ a receber; trânsito é separado)
  areceber numeric default 0,
  vencido  numeric default 0,
  transito numeric default 0,
  -- participação por pessoa (RH liga/desliga)
  part_fat boolean default true,
  part_mix boolean default true,
  part_posit boolean default true,
  part_inad boolean default true,
  primary key (mes, codigo)
);
create index if not exists metas_mensais_mes_idx on public.metas_mensais(mes);

-- ============================================================================
-- 5) CAMPANHAS (do fornecedor)
-- ============================================================================
create table if not exists public.campanhas(
  id bigint generated always as identity primary key,
  nome        text,
  fornecedor  text,                                -- marca patrocinadora
  marcas      text[] default '{}',
  ini date, fim date,
  escopo      text default 'TODOS' check (escopo in ('TODOS','EXTERNO','INTERNO')),
  minimo      numeric default 0,                   -- mínimo p/ participar (sobre o valor)
  sup_valor   numeric default 0,                   -- supervisor: valor separado (fora do ranking)
  imagens     text[] default '{}',                 -- urls (Storage) das imagens do fornecedor
  token_forn  text unique default encode(gen_random_bytes(16),'hex'),  -- link do fornecedor
  token_colab text unique default encode(gen_random_bytes(12),'hex'),  -- link dos colaboradores
  ativa       boolean default true,
  criada_em   timestamptz default now()
);

-- critérios da campanha (multi-critério) — cada um com seu modo e pódio
create table if not exists public.campanha_criterios(
  id bigint generated always as identity primary key,
  campanha_id bigint not null references public.campanhas(id) on delete cascade,
  indicador text not null,                         -- Faturamento/Peso/Mix/Positivacao/Itens
  modo      text not null default 'CRESCIMENTO' check (modo in ('CRESCIMENTO','META','VALOR')),
  premio1 numeric default 0, premio2 numeric default 0, premio3 numeric default 0,
  ordem   int default 0
);
-- 'VALOR' (o maior) só faz sentido no Faturamento — validado na aplicação.

-- quem participa da campanha
create table if not exists public.campanha_participantes(
  campanha_id bigint not null references public.campanhas(id) on delete cascade,
  codigo      text not null references public.vendedores(codigo) on delete cascade,
  participa   boolean default true,
  primary key (campanha_id, codigo)
);

-- META INDIVIDUAL por CRITÉRIO (só p/ modo 'META') — cada critério tem a sua
create table if not exists public.campanha_metas(
  criterio_id bigint not null references public.campanha_criterios(id) on delete cascade,
  codigo      text   not null references public.vendedores(codigo) on delete cascade,
  meta        numeric default 0,
  primary key (criterio_id, codigo)
);

-- ============================================================================
-- 6) RLS — leitura pelos logados; edição de VALORES só RH/Diretoria
-- ============================================================================
do $$
declare t text;
begin
  foreach t in array array[
    'vendedores','metas_regras','metas_fornecedor_bonus','metas_fornecedor_alvo',
    'metas_meses','metas_mensais','campanhas','campanha_criterios',
    'campanha_participantes','campanha_metas'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    -- leitura: qualquer usuário logado
    execute format('drop policy if exists %I on public.%I', t||'_read', t);
    execute format('create policy %I on public.%I for select to authenticated using (true)', t||'_read', t);
  end loop;
end $$;

-- escrita: REGRAS / VALORES / FORNECEDOR / CAMPANHAS  -> só RH/Diretoria (mn_editor)
do $$
declare t text;
begin
  foreach t in array array[
    'metas_regras','metas_fornecedor_bonus','vendedores',
    'campanhas','campanha_criterios','campanha_participantes','campanha_metas'
  ] loop
    execute format('drop policy if exists %I on public.%I', t||'_write', t);
    execute format('create policy %I on public.%I for all to authenticated using (public.mn_editor()) with check (public.mn_editor())', t||'_write', t);
  end loop;
end $$;

-- escrita: METAS do mês / alvos / meses  -> RH/Diretoria/Faturamento/Supervisão
do $$
declare t text;
begin
  foreach t in array array['metas_meses','metas_mensais','metas_fornecedor_alvo'] loop
    execute format('drop policy if exists %I on public.%I', t||'_write', t);
    execute format('create policy %I on public.%I for all to authenticated using (public.mn_gestor_metas()) with check (public.mn_gestor_metas())', t||'_write', t);
  end loop;
end $$;

-- ============================================================================
-- 7) LINK DO FORNECEDOR (sem login) — RPC por token, só leitura, expira no fim
-- ============================================================================
create or replace function public.campanha_por_token(p_token text)
returns jsonb language sql stable security definer set search_path = public as $$
  select case when c.id is null then null else jsonb_build_object(
    'id', c.id, 'nome', c.nome, 'fornecedor', c.fornecedor, 'marcas', c.marcas,
    'ini', c.ini, 'fim', c.fim, 'escopo', c.escopo, 'minimo', c.minimo,
    'sup_valor', c.sup_valor, 'imagens', c.imagens,
    'expirada', (c.fim is not null and c.fim < current_date),
    'criterios', coalesce((select jsonb_agg(jsonb_build_object(
        'id',cr.id,'indicador',cr.indicador,'modo',cr.modo,
        'premio1',cr.premio1,'premio2',cr.premio2,'premio3',cr.premio3,'ordem',cr.ordem
      ) order by cr.ordem) from campanha_criterios cr where cr.campanha_id=c.id),'[]'::jsonb),
    'participantes', coalesce((select jsonb_agg(v.nome order by v.nome)
       from campanha_participantes cp join vendedores v on v.codigo=cp.codigo
       where cp.campanha_id=c.id and cp.participa),'[]'::jsonb)
  ) end
  from campanhas c
  where c.token_forn = p_token and c.ativa
    and (c.fim is null or c.fim >= current_date);   -- expira no fim da campanha
$$;
grant execute on function public.campanha_por_token(text) to anon, authenticated;

-- Conferência rápida (deve listar as duas linhas de regras):
--   select setor, bonus_fat, inad_meta, min_clientes, min_carteira from public.metas_regras;
