-- ============================================================================
-- METAS NOVAS — Agosto/2026 + Tatiana (supervisora interna) + Campanha SUSTENTARE
-- RODAR NO BANCO DO RH (projeto gpgycgkqkzedoyilrsmw)
-- Dados vindos da tela antiga (prints sincronizados 22:22) + encarte da campanha.
-- Idempotente.
-- ============================================================================

-- 0) Tatiana — supervisora interna, SEM código de venda (código sintético) -----
insert into public.vendedores(codigo,nome,setor,is_supervisor,tem_meta,soma_setor,ativo)
values ('TATIANA','Tatiana','INTERNO',true,false,null,true)
on conflict (codigo) do update set nome=excluded.nome,setor=excluded.setor,
  is_supervisor=excluded.is_supervisor,tem_meta=excluded.tem_meta,soma_setor=excluded.soma_setor;

-- 1) Mês de agosto (em andamento) --------------------------------------------
insert into public.metas_meses(mes,label,status) values ('2026-08','Agosto / 2026','andamento')
on conflict (mes) do update set label=excluded.label, status='andamento';

-- 2) Metas de agosto por vendedor (só OBJETIVOS; realizado vem dos relatórios) -
-- Externa: posit alvo = 90% da carteira (regra); meta_posit não é por vendedor.
insert into public.metas_mensais(mes,codigo,obj_fat,obj_mix,meta_posit,carteira,
  part_fat,part_mix,part_posit,part_inad) values
  ('2026-08','020',150000,250,0,59,true ,true ,true ,true ),  -- Adriano
  ('2026-08','013',100000,250,0,29,true ,true ,true ,true ),  -- Cristiano
  ('2026-08','003',125000,250,0,42,true ,true ,true ,true ),  -- Denilson
  ('2026-08','004', 90000,250,0,37,true ,true ,true ,true ),  -- Gabriela
  ('2026-08','007',120000,250,0,45,true ,true ,true ,true ),  -- Hernandes
  ('2026-08','006',230000,250,0,32,true ,true ,true ,true ),  -- Suzana
  ('2026-08','016',     0,650,0, 0,false,true ,false,false),  -- Genivaldo (sup): só mix manual; resto soma auto
  -- Interna: meta_posit = nº de vendas alvo; carteira = clientes
  ('2026-08','015',180000,1350,1000, 89,true ,true ,true ,true ), -- Anderson
  ('2026-08','017',180000,1350,1000, 52,true ,true ,true ,true ), -- Renan
  ('2026-08','008',120000,1100,1000,  0,true ,true ,true ,true ), -- Mauricio
  ('2026-08','021', 25000, 400, 400,922,true ,true ,true ,true ), -- Delivery
  ('2026-08','TATIANA',0,1450,0, 0,false,true ,false,false)       -- Tatiana (sup): só mix manual
on conflict (mes,codigo) do update set obj_fat=excluded.obj_fat,obj_mix=excluded.obj_mix,
  meta_posit=excluded.meta_posit,carteira=excluded.carteira,part_fat=excluded.part_fat,
  part_mix=excluded.part_mix,part_posit=excluded.part_posit,part_inad=excluded.part_inad;
-- (Marcio 011 sem meta em agosto — sem linha. Empresa/Balcão/Uiliam sem meta.)

-- 3) Campanha SUSTENTARE (do encarte) — modo "o maior" (VALOR) em cada critério
do $$
declare cid bigint;
begin
  select id into cid from public.campanhas where nome='Campanha SUSTENTARE' limit 1;
  if cid is null then
    insert into public.campanhas(nome,fornecedor,marcas,ini,fim,escopo,minimo,sup_valor,ativa)
      values ('Campanha SUSTENTARE','SUSTENTARE',array['SUSTENTARE'],
              '2026-08-01','2026-09-30','TODOS',0,0,true)
      returning id into cid;
    insert into public.campanha_criterios(campanha_id,indicador,modo,premio1,premio2,premio3,ordem) values
      (cid,'Produtos (variedade)','VALOR',150,100,0,0),
      (cid,'Quantidade',          'VALOR',150,100,0,1),
      (cid,'Positivacao (clientes)','VALOR',150,100,0,2);
    insert into public.campanha_participantes(campanha_id,codigo,participa)
      select cid, cod, true
      from unnest(array['003','004','006','007','011','013','020','016',   -- externos + Genivaldo
                        '008','015','017','021']) cod;                     -- internos
  end if;
end $$;

-- Conferência:
--   select mes,count(*) from public.metas_mensais where mes='2026-08' group by 1;
--   select nome,fornecedor,ini,fim,escopo from public.campanhas;
--   select indicador,modo,premio1,premio2 from public.campanha_criterios order by ordem;
