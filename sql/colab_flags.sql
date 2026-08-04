-- Marcadores de participação do colaborador (Avaliação)
-- Rodar uma vez no banco do RH (Supabase → SQL Editor).

-- Participa do ranking (colaboradores de casa: marque false)
alter table colaboradores
  add column if not exists participa_ranking boolean not null default true;

-- Liberado para avaliações (em treinamento fica false até o RH confirmar)
alter table colaboradores
  add column if not exists avaliacao_ok boolean not null default true;
