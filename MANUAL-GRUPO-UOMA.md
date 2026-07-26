# 📘 Manual de Bolso — Portal Grupo Uoma
### Estado: **v3.5** · 27/07/2026 · a fonte da verdade pra continuar daqui

Portal único do colaborador do **Grupo Uoma** (Loja do Sorveteiro e Confeiteiro · Padoquinha · Merenda Certa), evoluindo pra **ERP do grupo**. Login único, modular, um app.

---

## 1. Visão em uma frase
Uma **porta única**: cada pessoa loga uma vez e vê **só o que o perfil dela permite** — mural, campanhas, estoque, RH, folha, e os canais de comunicação (Erro Zero, Soluções, Fale com a diretoria). As permissões são **dado**, não código: a diretoria liga/desliga tudo no painel de Acessos.

---

## 2. Arquitetura (o mapa)

**Dois bancos Supabase, um login:**

| Banco | Projeto (ref) | Guarda | Chave pública (segura, já exposta no site) |
|---|---|---|---|
| **RH** (base do grupo) | `gpgycgkqkzedoyilrsmw` | login/auth, `usuarios`, `colaboradores`, `folha`, `aval_*`, `empresas`, mural, `mensagens`, `ideias` | `sb_publishable_PtttNHZXuxyuV224G5qhQw_ONYW8soj` |
| **Faturamento** (operação) | `kopuvuhmqbpvlwksypgm` | `metas` (blob c/ campanhas), estoque (`inv_ciclo`, `inv_contagem`, `inv_catalogo`) | `sb_publishable_flmTo5yyGUafV5OwkeYijQ_HvBbDWBr` |

- O portal **loga pelo RH** (Supabase Auth) e **lê dos dois bancos** — cada módulo lê de onde o dado mora. **Sem login duplo.**
- ⚠️ **Nunca** usar chave `service_role` nem token `sbp_...` no código do site (são secretas). Só as `sb_publishable_...` (públicas, seguras).

**Arquivos (repo `uiliamlourenco1987/Grupo-Uoma`, deploy via GitHub Pages / branch main):**
- `entrar.html` — tela de login (RH Auth).
- `home.html` — o portal inteiro (mural, módulos, canais). É o arquivão.
- `contato.html` — página **pública** do cliente (Erro Zero sem login).
- `estoque/` — o app coletor de inventário (copiado do Estoquelsc, mesma origem).

---

## 3. Perfis e permissões
- **Papéis (`usuarios.role`):** `diretoria` (admin total), `edicao`, `visualizacao` (colaborador).
- **Empresas (`usuarios.empresas`):** `loja`, `padoquinha`, `merenda` (várias, separadas por vírgula) ou `todas` (grupo).
- **Permissão por módulo (`usuarios.permissoes` jsonb):** ex. `{"faturamento":"ver","campanhas":"editar"}`. Valores: `ver` / `editar`.
- **Regra do menu:** diretoria vê tudo; os demais veem **só o que estiver liberado** (começa zerado). Base pra todos: Início/mural, Fale com a diretoria, Soluções.
- **Dono protegido:** `uiliamcesar@hotmail.com` é sempre diretoria, irrestrito, e **ninguém edita** (trava no painel + no banco).

---

## 4. Módulos e canais (o que já funciona)

| Item | O que faz | Quem |
|---|---|---|
| **Mural** | Comunicados: publicar, comentar, apagar | Publica: diretoria/edição · comenta: todos |
| **Home** | Boas-vindas, apresentação das 3 empresas, avaliação, logos por empresa | Todos |
| **Acessos** | Perfil + empresas + permissão por módulo; **＋ Novo colaborador**; **Colaboradores por empresa** (roster do RH agrupado, com "criar acesso") | Só diretoria |
| **Campanhas** | Ver + **criar/editar/excluir** + **encarte PDF** (grava no banco do faturamento) | Ver: liberados · Editar: diretoria ou permissão |
| **Estoque** | Painel de inventário (`inv_ciclo`) + **coletor completo embutido** | Liberados |
| **Metas de vendas** | Resumo: meta × realizado por vendedor (equipe ext/int) + KPIs. *Leitura* | Liberados |
| **Faturamento** | Resumo: KPIs + financeiro (a receber/vencido/trânsito) + top vendedores. *Leitura* | Liberados |
| **Separação** | Resumo: últimas separações enviadas (ok/parcial/falta), tabela `enviadas`. *Leitura* | Liberados |
| **🚨 Erro Zero** | Problema urgente → chega direto na diretoria; **abrir/anotar/status** (Novo→Análise→Resolvido); alerta na tela conta os não resolvidos | Reporta: colaborador (empresa+setor) e cliente (contato.html) · Gerencia: diretoria |
| **💡 Soluções** | Kanban de ideias/melhorias (Recebida→Análise→Ajuste→Aprovada→Implantada→Descartada) + parecer + premiada | Envia/acompanha: todos · Gerencia: diretoria ou permissão "Soluções" |
| **💬 Fale com a diretoria** | Bate-papo direto | Todos |
| **Painel de versões** | Histórico do que muda a cada versão (rodapé) | Só diretoria |

---

## 5. Banco — tabelas que o portal usa

**RH (`gpgycgkqkzedoyilrsmw`):**
- `usuarios` — id, email, nome, **role**, **empresas**, **permissoes** (jsonb). *(logins do portal)*
- `colaboradores` — id, nome, **cpf**, **empresa**, **cargo**, **setor**, **salario_base**, **senha(PIN)**, email, situacao, participa_aval. **SENSÍVEL** → protegida.
- `folha` — folha de pagamento. **SENSÍVEL** → protegida.
- `aval_*` — avaliação (perguntas, regras, respostas, scores, rh, media). Sensíveis já protegidas por `pode_editar()`.
- `empresas` — id, nome, cor.
- `comunicados`, `comentarios` — mural.
- `mensagens` — Erro Zero + Fale + contato: id, autor_id, autor_nome, **tipo** (colaborador/cliente), empresa, setor, contato, texto, **status** (novo/analise/resolvido), **anotacao**, lida, created_at.
- `ideias` — Soluções Kanban: id, autor_id, autor_nome, empresa, setor, titulo, descricao, **status**, **parecer**, **premiado**, premio, created_at, updated_at.

**Faturamento (`kopuvuhmqbpvlwksypgm`):**
- `metas` (id=1, `data` jsonb) — dentro dela: `campanhas`, `meses[mês].vend` (vendedores/vendas).
- `inv_ciclo`, `inv_contagem`, `inv_catalogo` — inventário cíclico (estoque).

**Funções (RH):**
- `is_diretoria()` — security definer; true se role='diretoria'.
- `pode_editar()` — trava do RH/diretoria (já existia; usada na avaliação e **agora também** protege colaboradores/folha).
- `lista_setores()` — security definer; devolve setores distintos (setor+cargo) **sem** expor nada sensível.

---

## 6. Segurança (o que está fechado e o que vigiar)
- ✅ **`colaboradores` e `folha`** (salário, CPF, PIN) agora só abrem com `pode_editar()` (RH/diretoria). Colaborador comum **não lê** mais. *(fechado hoje)*
- ✅ **Avaliação** já protegida por `pode_editar()`.
- ✅ **Dono** blindado (não pode ser alterado por ninguém).
- 🔎 **Vigiar:** a *view* `aval_media_empresa` tem `SECURITY DEFINER` (aviso do Supabase) — revisar depois. As chaves publishable são públicas de propósito; a proteção real é a **RLS** de cada tabela.
- 🔒 **Regra de ouro:** dado sensível novo? Já nasce com RLS restrita (nunca `using(true)` pra `authenticated`).

---

## 7. SQL pendente (rodar no Supabase do RH quando faltar)
> Já rodados/confirmados: `lista_setores()`, proteção `colaboradores`/`folha`, coluna `empresas`/`permissoes`, `is_diretoria()` + políticas de `usuarios`.

**a) Tabela `mensagens` (Erro Zero / Fale / contato):**
```sql
create table if not exists mensagens (
  id bigint generated always as identity primary key,
  autor_id uuid, autor_nome text, tipo text default 'colaborador',
  empresa text, setor text, contato text, texto text not null,
  status text default 'novo', anotacao text,
  lida boolean default false, created_at timestamptz default now()
);
alter table mensagens add column if not exists status text default 'novo';
alter table mensagens add column if not exists anotacao text;
alter table mensagens enable row level security;
drop policy if exists msg_insert_auth on mensagens;
create policy msg_insert_auth on mensagens for insert to authenticated with check (autor_id = auth.uid());
drop policy if exists msg_insert_anon on mensagens;
create policy msg_insert_anon on mensagens for insert to anon with check (tipo = 'cliente');
drop policy if exists msg_read_dir on mensagens;
create policy msg_read_dir on mensagens for select to authenticated using (is_diretoria());
drop policy if exists msg_update_dir on mensagens;
create policy msg_update_dir on mensagens for update to authenticated using (is_diretoria()) with check (is_diretoria());
```

**b) Tabela `ideias` (Soluções Kanban):**
```sql
create table if not exists ideias (
  id bigint generated always as identity primary key,
  autor_id uuid, autor_nome text, empresa text, setor text,
  titulo text not null, descricao text,
  status text default 'recebida', parecer text,
  premiado boolean default false, premio text,
  created_at timestamptz default now(), updated_at timestamptz default now()
);
alter table ideias enable row level security;
drop policy if exists ideias_insert on ideias;
create policy ideias_insert on ideias for insert to authenticated with check (autor_id = auth.uid());
drop policy if exists ideias_read on ideias;
create policy ideias_read on ideias for select to authenticated using (true);
drop policy if exists ideias_update on ideias;
create policy ideias_update on ideias for update to authenticated
using (is_diretoria() or exists(select 1 from usuarios u where u.id=auth.uid() and u.permissoes->>'solucoes'='editar'))
with check (is_diretoria() or exists(select 1 from usuarios u where u.id=auth.uid() and u.permissoes->>'solucoes'='editar'));
```

**c) Blindagem do dono (proteção do seu acesso):**
```sql
drop policy if exists usuarios_admin_update on usuarios;
create policy usuarios_admin_update on usuarios for update to authenticated
using (is_diretoria() and id <> (select id from auth.users where email='uiliamcesar@hotmail.com'))
with check (is_diretoria() and id <> (select id from auth.users where email='uiliamcesar@hotmail.com'));
```

---

## 8. Como continuar (convenções de trabalho)
- **Um arquivo, sem build.** HTML/CSS/JS puro, mobile-first, autocontido.
- **Preview antes de subir.** Toda mudança é vista (screenshot/artifact) antes de publicar.
- **Versão a cada mudança.** Sobe o número no topo do array `VERSIONS` (dentro do `home.html`); a versão da barra lateral **segue sozinha** (lê `VERSIONS[0]`). Para o usuário forçar a nova versão: `?v=NN` no fim do endereço.
- **Anti-cache** já embutido; mesmo assim `?v=NN` garante.
- **Deploy:** commit + push na `main` → GitHub Pages publica.
- **Dois bancos:** RH = pessoas/acesso/RH/folha/mural/canais · Faturamento = campanhas/estoque.

---

## 9. Próximos passos / backlog
1. Rodar os 3 SQLs pendentes (mensagens, ideias, blindagem do dono) → liga Erro Zero e Soluções 100%.
2. **Premiação das Soluções** — mecanismo de recompensa (valor/placa) pra ideia validada que gerou economia/agilidade.
3. **Login por PIN** — usar `colaboradores.senha` (PIN) pro colaborador comum entrar sem e-mail/senha.
4. **Minha avaliação** na home — ligar aos dados reais (`aval_scores`) em vez de exemplo.
5. **Sub-permissões finas** por módulo (ex.: no Faturamento, "ver só as vendas") conforme cada módulo amadurece.
5b. **Metas/Faturamento completos** — hoje são *resumos de leitura* (meta×realizado, vendas, financeiro, separações enviadas). Falta trazer o **detalhe** (bônus, inadimplência, mix, positivação) e a **edição** (planejar metas, lançar) — porta o motor `metasCalc` do faturamento, com sua revisão (mexe em número de bônus).
6. Texto oficial da apresentação da **Merenda Certa** (hoje provisório).
7. Revisar a view `aval_media_empresa` (aviso SECURITY DEFINER).

---

## 10. Histórico de versões
- **v3.5** — Acessos: colaboradores divididos por empresa (validar) + criar acesso pré-preenchido
- **v3.4** — Metas, Faturamento e Separação no portal (resumos de leitura)
- **v3.3** — Erro Zero: abrir, anotar e classificar (Novo/Análise/Resolvido)
- **v3.2** — Setores da planilha real do RH (função segura)
- **v3.1** — Setores em lista + pré-cadastro em massa
- **v3.0** — Soluções & Melhorias (Kanban)
- **v2.9** — Painel de versões em dia (amarrado à barra)
- **v2.8** — Apresentações reais (Loja e Padoquinha)
- **v2.7** — Encarte PDF nas campanhas
- **v2.6** — Erro Zero + dono protegido + apresentações
- **v2.5** — Setor obrigatório no canal
- **v2.4** — Estoque no portal (painel + coletor)
- **v2.3** — Empresa obrigatória + alerta na tela
- **v2.2** — Painel de versões + canal com a diretoria
- **v2.1** — Colaborador começa zerado
- **v2.0** — Cadastro de colaborador (correção e-mail)
- **v1.9** — Editor de campanha no portal
- **v1.8** — Adicionar colaborador pelo portal
- **v1.7** — Permissões por módulo
- **v1.6** — Campanhas no portal (leitura)
- **v1.5** — Leitura de perfil robusta
- **v1.4** — Logos por empresa + apagar publicações

---

### Fora do portal (bancos de operação)
- **Faturamento** (app `index.html` / `fatcsorveteiro`): metas, campanhas, vendas, separação. Banco `kopuvuhmqbpvlwksypgm`.
- **Estoquelsc**: inventário cíclico. Mesmo banco do faturamento. Copiado pra `estoque/` no portal.

_Fim do manual. Atualizar este arquivo a cada marco importante._
