-- ============================================================================
-- METAS NOVAS — Faturamento/Mix + Desempenho  (tudo no BANCO DO RH)
-- RODAR NO BANCO DO RH (projeto gpgycgkqkzedoyilrsmw)
--
-- Duas tabelas alimentadas pelas DUAS PLANILHAS novas:
--   • fat_vendas   ← "Mix / Faturamento" (linha a linha: produto/cliente/marca/
--                     vendedor/peso/valor). Dela sai: mix, top produtos, top
--                     clientes, valor do quilo (geral e por marca), faturamento.
--   • desempenho   ← "Relatório de Desempenho" (1 linha por vendedor): vendas,
--                     positivação, carteira, média, inadimplência etc.
-- Chave = CÓDIGO real do vendedor (CODVENDEDOR). Tabelas separadas; a gente
-- junta por código depois. Idempotente.
-- ============================================================================

-- ---------- 1) FAT_VENDAS (linha a linha do Mix/Faturamento) ----------------
create table if not exists public.fat_vendas(
  id           bigint generated always as identity primary key,
  competencia  text not null,               -- 'AAAA-MM' (escolhido na importação)
  data         date,
  doc          text,
  empresa      text,
  codpro       text,
  descpro      text,
  embalagem    text,
  marca        text,
  codcli       text,
  nomecli      text,
  codvendedor  text,
  vendedor     text,
  quantidade   numeric default 0,
  peso         numeric default 0,
  vlrliquido   numeric default 0,
  tipooperacao text,
  criado_em    timestamptz default now()
);
create index if not exists fat_vendas_comp_idx     on public.fat_vendas(competencia);
create index if not exists fat_vendas_comp_vend_idx on public.fat_vendas(competencia, codvendedor);
create index if not exists fat_vendas_comp_marca_idx on public.fat_vendas(competencia, marca);
create index if not exists fat_vendas_comp_cli_idx   on public.fat_vendas(competencia, codcli);

-- ---------- 2) DESEMPENHO (1 linha por vendedor, por competência) -----------
create table if not exists public.desempenho(
  competencia        text not null,
  empresa            text,
  codigo             text not null,          -- CODVENDEDOR real
  vendedor           text,
  vendas             numeric default 0,
  custo              numeric default 0,
  lucro              numeric default 0,      -- % de lucro
  positivacao        numeric default 0,      -- nº de clientes positivados
  venda_media        numeric default 0,
  peso               numeric default 0,
  mix_produto        numeric default 0,      -- nº de produtos distintos
  carteira_clientes  numeric default 0,
  clientes_atendidos numeric default 0,
  qtd_devolucao      numeric default 0,
  pct_compraram      numeric default 0,      -- %
  pct_nao_compraram  numeric default 0,      -- %
  clientes_novos     numeric default 0,
  areceber           numeric default 0,
  a_vencer           numeric default 0,
  vencidos           numeric default 0,
  transito           numeric default 0,
  inadimplencia      numeric default 0,      -- %
  atualizado_em      timestamptz default now(),
  primary key (competencia, codigo)
);

-- ---------- 3) RLS: leitura logados; escrita p/ gestores --------------------
do $$
declare t text;
begin
  foreach t in array array['fat_vendas','desempenho'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('drop policy if exists %I on public.%I', t||'_read', t);
    execute format('create policy %I on public.%I for select to authenticated using (true)', t||'_read', t);
    execute format('drop policy if exists %I on public.%I', t||'_write', t);
    execute format('create policy %I on public.%I for all to authenticated using (public.mn_gestor_metas()) with check (public.mn_gestor_metas())', t||'_write', t);
  end loop;
end $$;
grant usage, select on sequence public.fat_vendas_id_seq to authenticated;

-- Conferência:
--   select competencia, count(*) from public.fat_vendas group by 1 order by 1;
--   select competencia, count(*) from public.desempenho group by 1 order by 1;
