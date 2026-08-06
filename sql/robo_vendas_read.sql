-- ============================================================
-- LEITURA do robô pelo site (chave anon/publishable)
-- RODAR NO BANCO DO FATURAMENTO -> kopuvuhmqbpvlwksypgm
--
-- Por quê: o site (app de Metas) lê robo_vendas / robo_desempenho
-- com a chave PUBLISHABLE (anon) para gerar os índices e as campanhas.
-- Se essas tabelas não tiverem SELECT liberado para 'anon', o site
-- recebe VAZIO silenciosamente e os índices mostram "0 vendas do robô"
-- mesmo havendo dados. Este script garante a leitura (idempotente).
--
-- Segurança: só LEITURA para anon. A ESCRITA continua exclusiva do robô,
-- que usa a service_role (que ignora RLS). A chave anon NÃO grava aqui.
-- Rodar UMA vez.
-- ============================================================

-- 1) Permissão de leitura (SELECT) para o site
grant usage on schema public to anon, authenticated;
grant select on public.robo_vendas      to anon, authenticated;
grant select on public.robo_desempenho  to anon, authenticated;

-- 2) Se algum dia o RLS for LIGADO nessas tabelas, garantir uma policy de leitura.
--    (Com RLS desligado, o grant acima já basta; com RLS ligado, sem policy, anon lê 0.)
do $$
begin
  if exists (select 1 from pg_tables where schemaname='public' and tablename='robo_vendas') then
    begin execute 'alter table public.robo_vendas enable row level security'; exception when others then null; end;
    if not exists (select 1 from pg_policies where schemaname='public' and tablename='robo_vendas' and policyname='robo_vendas_read') then
      execute 'create policy robo_vendas_read on public.robo_vendas for select using (true)';
    end if;
  end if;

  if exists (select 1 from pg_tables where schemaname='public' and tablename='robo_desempenho') then
    begin execute 'alter table public.robo_desempenho enable row level security'; exception when others then null; end;
    if not exists (select 1 from pg_policies where schemaname='public' and tablename='robo_desempenho' and policyname='robo_desempenho_read') then
      execute 'create policy robo_desempenho_read on public.robo_desempenho for select using (true)';
    end if;
  end if;
end $$;

-- 3) Views auxiliares que o site também lê (se existirem): concede leitura.
do $$
declare v text;
begin
  foreach v in array array['robo_vendas_produtos_vend','robo_vendas_vend_marca'] loop
    if exists (select 1 from information_schema.views where table_schema='public' and table_name=v) then
      execute format('grant select on public.%I to anon, authenticated', v);
    end if;
  end loop;
end $$;

-- 4) Conferência rápida (deve retornar linhas se houver dados 2025):
--    select competencia, count(*) from public.robo_vendas group by 1 order by 1;
