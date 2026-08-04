-- Marcadores de participação do colaborador (Avaliação)
-- Rodar uma vez no banco do RH (Supabase → SQL Editor).

-- 1) Participa do ranking e da avaliação dos colegas? (colaboradores de casa: false)
alter table colaboradores
  add column if not exists participa_ranking boolean not null default true;

-- 2) Participa da avaliação do RH? (em treinamento: false até o RH confirmar)
alter table colaboradores
  add column if not exists participa_rh boolean not null default true;
