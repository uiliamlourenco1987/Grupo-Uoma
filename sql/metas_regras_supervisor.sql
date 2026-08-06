-- ============================================================================
-- METAS NOVAS — supervisor interno por índice
-- RODAR NO BANCO DO RH (projeto gpgycgkqkzedoyilrsmw)
-- Adiciona R$ por índice do SUPERVISOR INTERNO (Faturamento/Mix/Positivação/
-- Inadimplência). O supervisor externo continua em % base + p.p. por índice.
-- Idempotente: pode rodar mais de uma vez.
-- ============================================================================

alter table public.metas_regras
  add column if not exists sup_val_fat   numeric default 0,
  add column if not exists sup_val_mix   numeric default 0,
  add column if not exists sup_val_posit numeric default 0,
  add column if not exists sup_val_inad  numeric default 0;

-- Conferência:
--   select setor, sup_val_fat, sup_val_mix, sup_val_posit, sup_val_inad
--   from public.metas_regras;
