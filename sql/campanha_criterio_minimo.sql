-- ============================================================================
-- METAS NOVAS — mínimo por CRITÉRIO da campanha
-- RODAR NO BANCO DO RH (projeto gpgycgkqkzedoyilrsmw)
-- Cada critério passa a ter o seu próprio "mínimo para participar" (piso).
-- Idempotente.
-- ============================================================================
alter table public.campanha_criterios
  add column if not exists minimo numeric default 0;
