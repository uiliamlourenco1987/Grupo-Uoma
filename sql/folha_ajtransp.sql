-- Adiciona a coluna Ajuda Transporte na folha (rodar 1x no Supabase do RH)
alter table folha add column if not exists ajtransp numeric default 0;
