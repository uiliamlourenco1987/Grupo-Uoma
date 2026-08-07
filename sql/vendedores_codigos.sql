-- ============================================================================
-- METAS NOVAS — vendedores com CÓDIGO REAL + regras de soma
-- RODAR NO BANCO DO RH (projeto gpgycgkqkzedoyilrsmw)
--
-- Cadastra os 19 códigos reais (do ERP) e define, por vendedor:
--   • tem_meta    → entra em meta/ranking/tela do vendedor
--   • soma_setor  → em qual TOTAL de equipe a venda dele soma:
--                     'EXTERNO' | 'INTERNO' | NULL (só no total da diretoria)
--   • is_supervisor
-- Regra do dono: diretoria soma TODOS; equipe/vendedor só os com meta;
--   Balcão(001)+Delivery(021) somam na interna; Genivaldo(016) na externa;
--   Empresa(012)+Uiliam(005) e as contas de sistema só entram na diretoria.
--
-- Também MIGRA o histórico (metas_mensais) da chave NOME p/ o código real.
-- Idempotente: pode rodar de novo.
-- ============================================================================

-- 0) colunas novas -----------------------------------------------------------
alter table public.vendedores
  add column if not exists tem_meta   boolean not null default true,
  add column if not exists soma_setor text;   -- 'EXTERNO' | 'INTERNO' | NULL

-- 1) cadastrar TODOS com o código real --------------------------------------
insert into public.vendedores(codigo,nome,setor,is_supervisor,tem_meta,soma_setor,ativo) values
  ('003','Denilson',      'EXTERNO',false,true ,'EXTERNO',true),
  ('004','Gabriela',      'EXTERNO',false,true ,'EXTERNO',true),
  ('006','Suzana',        'EXTERNO',false,true ,'EXTERNO',true),
  ('007','Hernandes',     'EXTERNO',false,true ,'EXTERNO',true),
  ('011','Marcio',        'EXTERNO',false,true ,'EXTERNO',true),
  ('013','Cristiano',     'EXTERNO',false,true ,'EXTERNO',true),
  ('020','Jose Adriano',  'EXTERNO',false,true ,'EXTERNO',true),
  ('016','Genivaldo',     'EXTERNO',true ,false,'EXTERNO',true),   -- supervisor; venda extra soma na externa
  ('008','Mauricio',      'INTERNO',false,true ,'INTERNO',true),
  ('015','Anderson Silva','INTERNO',false,true ,'INTERNO',true),
  ('017','Renan',         'INTERNO',false,true ,'INTERNO',true),
  ('021','Delivery',      'INTERNO',false,true ,'INTERNO',true),   -- soma na interna
  ('001','Balcao',        'INTERNO',false,false,'INTERNO',true),   -- sem meta; soma na interna
  ('012','Empresa',       'INTERNO',false,false,null    ,true),   -- só diretoria
  ('005','Uiliam',        'INTERNO',false,false,null    ,true),   -- venda William/empresa; só diretoria
  ('002','Telemarketing', 'INTERNO',false,false,null    ,true),   -- confirmar
  ('009','Vitoria',       'INTERNO',false,false,null    ,true),   -- confirmar
  ('010','Inativos e Inadimplentes','INTERNO',false,false,null,true),
  ('999','Vda Sem Financeiro',      'INTERNO',false,false,null,true)
on conflict (codigo) do update set
  nome=excluded.nome, setor=excluded.setor, is_supervisor=excluded.is_supervisor,
  tem_meta=excluded.tem_meta, soma_setor=excluded.soma_setor, ativo=excluded.ativo;

-- 2) migrar o histórico (metas_mensais): NOME -> código real -----------------
update public.metas_mensais set codigo='020' where codigo='ADRIANO';
update public.metas_mensais set codigo='013' where codigo='CRISTIANO';
update public.metas_mensais set codigo='003' where codigo='DENILSON';
update public.metas_mensais set codigo='016' where codigo='GENIVALDO';
update public.metas_mensais set codigo='004' where codigo='GABRIELA';
update public.metas_mensais set codigo='007' where codigo='HERNANDES';
update public.metas_mensais set codigo='006' where codigo='SUZANA';
update public.metas_mensais set codigo='011' where codigo='MARCIO';
update public.metas_mensais set codigo='015' where codigo='ANDERSON';
update public.metas_mensais set codigo='017' where codigo='RENAN';
update public.metas_mensais set codigo='008' where codigo='MAURICIO';
update public.metas_mensais set codigo='021' where codigo='DELIVERY';
update public.metas_mensais set codigo='012' where codigo='EMPRESA';
update public.metas_mensais set codigo='001' where codigo='BALCAO';

-- migrar alvos de fornecedor, se houver
update public.metas_fornecedor_alvo set codigo='020' where codigo='ADRIANO';
update public.metas_fornecedor_alvo set codigo='013' where codigo='CRISTIANO';
update public.metas_fornecedor_alvo set codigo='003' where codigo='DENILSON';
update public.metas_fornecedor_alvo set codigo='016' where codigo='GENIVALDO';
update public.metas_fornecedor_alvo set codigo='004' where codigo='GABRIELA';
update public.metas_fornecedor_alvo set codigo='007' where codigo='HERNANDES';
update public.metas_fornecedor_alvo set codigo='006' where codigo='SUZANA';
update public.metas_fornecedor_alvo set codigo='011' where codigo='MARCIO';
update public.metas_fornecedor_alvo set codigo='015' where codigo='ANDERSON';
update public.metas_fornecedor_alvo set codigo='017' where codigo='RENAN';
update public.metas_fornecedor_alvo set codigo='008' where codigo='MAURICIO';
update public.metas_fornecedor_alvo set codigo='021' where codigo='DELIVERY';
update public.metas_fornecedor_alvo set codigo='012' where codigo='EMPRESA';
update public.metas_fornecedor_alvo set codigo='001' where codigo='BALCAO';

-- 3) remover as linhas antigas de vendedores (chave = NOME) -------------------
delete from public.vendedores
 where codigo in ('ADRIANO','CRISTIANO','DENILSON','GENIVALDO','GABRIELA','HERNANDES',
                  'SUZANA','MARCIO','ANDERSON','RENAN','MAURICIO','DELIVERY','EMPRESA','BALCAO');

-- Conferência:
--   select codigo,nome,setor,is_supervisor,tem_meta,soma_setor from public.vendedores order by codigo;
--   select mes,count(*) from public.metas_mensais group by 1 order by 1;
