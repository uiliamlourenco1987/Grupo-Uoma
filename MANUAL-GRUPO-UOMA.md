# 📘 Manual de Bolso — Portal Grupo Uoma
### Estado: **v5.9** · 26/07/2026 · a fonte da verdade pra continuar daqui

> **Rotina de release (IMPORTANTE):** a cada versão nova, bump JUNTOS: `ver.json` (`{"v":"X.Y"}`), a constante `BUILD` no `<head>` de `home.html` **e** `entrar.html`, e `VERSIONS[0]`/`verTag`. É o que faz o portal se atualizar sozinho (auto-update lê `ver.json` e recarrega se `BUILD` estiver diferente). Sub-apps embutidos recarregam via `?v=BUILD` no `src` do iframe. Ao recopiar `faturamento/index.html`, o `?v` já força o refresh.

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
- **v5.9** — **Acessos unificado numa classificação só: o Cargo.** Removido o select de "Papel" (role) da tela; agora escolhe-se só o **Cargo** (`permissoes.perfil`), e o `role` é **derivado** (`deriveRole`: diretoria se cargo diretoria; edicao se algum módulo 'editar'; senão visualizacao). Cada cargo tem **padrões** (`CARGO_DEF`) que **pré-marcam** os toggles ao escolher/trocar o cargo (`applyCargoDefaults` no onchange); a grade "O que essa pessoa vê" fica **sempre aberta** (details open) e clicável. `wireNovo` cria já com os padrões do cargo. Migração segura: diretor existente sem cargo cai em Cargo=Diretoria (não rebaixa). Toggles detalhados = os mesmos `.pmod`/`.fack`/`.fapm` de antes
- **v5.8** — Painel **Supervisão** (`renderSupervisorHome`): metas de **todos os vendedores da equipe** dele (filtrada por `permissoes.fat_app.equipe` = EXTERNO/INTERNO; se vazio, mostra todos com aviso) — cada vendedor com % + "ver completo" (abre app na tela metas, que já respeita a equipe do supervisor). KPIs: faturamento da equipe + **carteira de clientes** (soma `carteira`) e **atendidos** (soma `positivados`) com %. Campanhas **ativas/encerradas** por data. Botão Separações. + pessoal (aval+folha+avaliar). **A refinar:** "separações do setor" hoje abre a Separação geral; filtrar pelos pedidos dos vendedores da equipe é um próximo passo
- **v5.7** — "Fazer minha avaliação" abre **direto** na avaliação com o **nome pré-selecionado** (só pede o PIN). Feito **do lado do portal** (`openAvaliarColab`/`driveAvalColab`): como o iframe é same-origin, o portal clica em "Sou Colaborador", itera as empresas pra achar o nome (normalizado por `_avNorm`), seleciona empresa+nome, esconde os cards de escolha e foca o campo do PIN — **sem editar o app do RH** (o app é um blob babel escapado e frágil; o deep-link `?modo=colab` dele inclusive tem um regex `\\w` bugado, por isso a automação via DOM). Se o nome não bater, cai no formulário normal
- **v5.6** — Painel **Faturamento** (`renderFaturamentoHome`): KPIs do mês (faturamento % + inadimplência do grupo) + ferramentas (📥 importar→`openFatScreen("metas")`, 🎯 metas→openMetas, 🧾 faturamento→openFat, 📦 separações→openSep) + pessoal (aval+folha+avaliar). Dispatcher agora usa mapa `PERS`. Apps de Avaliação/Folha **rebrandeados** de "Grupo Araguari" → **"Grupo Uoma"** (selo GA→GU) no repo `rhcsorveteiro` e nas cópias `avaliacao/`+`folha/`
- **v5.5** — Perfil **RH** (`renderRHHome`): página pessoal (avaliação + holerite) **+ acesso ao sistema inteiro** — botões "💰 Folha" e "🛡️ Avaliações" (openFolha/openAvaliacao) + "fazer minha avaliação". `renderMenu` libera os módulos Folha/RH quando `permissoes.perfil==="rh"`. 'RH' adicionado ao seletor de perfis do Acessos
- **v5.4** — **Diretoria/admin: sistemas completos de Folha e Avaliação (RH)** embutidos no portal em tela cheia. Módulos de menu **Folha**→`openFolha()` e **RH**→`openAvaliacao()` (antes "em breve"); overlays `#folhaOvl`/`#avOvl` + `.appfull`. Apps copiados do RH: `folha/index.html` e `avaliacao/index.html` (recopiar quando o RH mudar). Cards **Folha** e **Avaliações (RH)** no "Comece por aqui" (gated diretoria/perm). Os apps usam o login próprio do RH (email/senha) dentro do iframe — se a sessão do Supabase for compartilhada (mesmo projeto), entra direto
- **v5.3** — Diagnóstico do nome nos cards vazios de avaliação/holerite
- **v5.2** — Botão **"Fazer minha avaliação dos colegas"** (`avaliarBtnHTML`/`openAvaliacao`) em **todos os perfis** (personal panels + cartões "Comece por aqui"). Abre o app de avaliação do RH **embutido em tela cheia** (`avaliacao/index.html`, cópia de `rhcsorveteiro/avaliacao.html`) via overlay `#avOvl`/`#avColetor`/`#avFrame` + `.appfull`; usa o acesso de **colaborador** que o app do RH já tem (PIN próprio). Recopiar `avaliacao/index.html` quando o app de avaliação do RH mudar
- **v5.1** — Perfis **Colaborador** e **Produção** (página pessoal enxuta: `renderColaboradorHome` = avaliação + holerite). **Holerite** ligado ao RH via RPC `minha_folha` (SECURITY DEFINER, `to_jsonb` da própria linha; rodar `sql/minha_folha.sql`). Helpers compartilhados `fetchAval`/`avalCardHTML`/`fetchFolha`/`folhaCardHTML`. Holerite também aparece no painel do **Vendedor**. **Pendência do dono:** rodar `sql/minha_folha.sql` (e `sql/minha_avaliacao.sql`) no Supabase do RH. **A fazer (pedido do dono):** botão "fazer minha avaliação" (avaliar colegas) em todos os painéis
- **v5.0** — **Painéis iniciais por perfil (fase 1: VENDEDOR).** Perfil do painel guardado em `usuarios.permissoes.perfil` (jsonb, sem schema novo), escolhido na tela de Acessos (`.aperfil`). `renderMyPanels` delega pra `renderVendedorHome()` quando `permissoes.perfil==="vendedor"`. A página do vendedor mostra: **avaliação/notas reais do RH** (via RPC `minha_avaliacao` — SECURITY DEFINER; rodar `sql/minha_avaliacao.sql` no projeto RH `gpgycgkqkzedoyilrsmw` pra liberar; com RLS, ninguém vê a nota do outro) + **ranking de vendas** (do FAT), **KPIs abertos** de Faturamento e Inadimplência, **meta** resumida e **campanha ativa** com a posição (via `campRank`/`campValor`). "Ver completo" abre o app em tela cheia na tela `vend` (novo `screenMinhaMeta()` no app → `myMetaHTML(nome)`, roteado por `_portalApplyAuth` quando `screen==="vend"`; o `openFatApp` já manda o `nome`). Próximos perfis (faturamento/financeiro/supervisão/diretoria) e o módulo **Compradores** (Compras) ficam pra fases seguintes. **Pendência do dono:** rodar `sql/minha_avaliacao.sql` no Supabase do RH
- **v4.9** — Resumo de Separação do portal (aba **Andamento**): esconde por padrão os pedidos **finalizados com mais de 3 dias** (helpers `daysAgoKey`/`sentWhenOf` + var `SHOWALLSENT` no módulo `SEP`); **pendentes/em conferência/parciais sempre aparecem** (só finalizado velho some). Botão **"ver todos"**. O corte não se aplica quando há filtro De/Até ativo (aí respeita as datas). KPIs continuam somando o total
- **v4.8** — Separação (app): a aba **Enviadas** e a coluna **📤 Enviado** do quadro mostram por padrão só os **últimos 3 dias** (`daysAgoKey(2)` + `state.sentShowAll`; helper `sentWhenOf` mapeia nº→data de envio, inclusive lote), com botão **"ver todos"**. Nada é apagado — o histórico completo continua no **Arquivo do portal** (só diretoria). Ciclo de vida da separação: conferir → **Devolver ao faturamento** (envio, exige todos os itens marcados + PIN) → pedido trava como *Enviada ✓* e sai da fila; fica *finalizado* quando todas as áreas com item enviaram
- **v4.7** — Apps operacionais (Faturamento/Separação/Estoque) abrem em **tela cheia dentro do portal** (`.appfull` no `#fatColetor`/`#sepColetor`/`#estColetor`: `position:fixed;inset:0` + barra "← Voltar ao portal"; login único intacto — handshake postMessage inalterado). Resumos `#metOvl`/`#fatOvl`/`#sepOvl` viram **página cheia** (sheet 100vw × 100dvh). Cards da Home ganham número-chave (metas %, faturamento % do mês, separações enviadas hoje) via `renderMyPanels`. App: conferência **ordenada por marca** (`byMarcaDesc`/`marcaKey` em `consolida` e `screenConf`; sem marca vai ao fim)
- **v4.6** — PIN obrigatório no envio da separação (sem PIN cadastrado, bloqueia)
- **v4.5** — Separação: abas Arquivo/Histórico + Auditoria (linha do tempo + divergências, só diretoria) + PIN de confirmação no envio (permissoes.sep_pin, passado no login único)
- **v4.4** — Separação: corrige envio em lote duplicado + "enviado" que voltava pra pronto; nº de importação único. (Pendente: confirmar constraints únicas no banco — conferencias(numero,codigo,scope) e enviadas(id).)
- **v4.3** — Corrige o 🚫 (desativar) sumindo quando o nome do colaborador é muito grande (flex `min-width:0` + wrap)
- **v4.2** — Portal se atualiza sozinho (auto-update via `ver.json` + `BUILD`; login e iframes já com `?v`) — acabou o `?v` na mão
- **v4.1** — Acessos: desativar/reativar colaborador direto na lista de validação (`colaboradores.ativo`; toggle "mostrar inativos") — sem refazer cadastro
- **v4.0** — Acesso unificado: permissões POR ÁREA do Faturamento no próprio portal (`permissoes.fat_app`) + login único (abre o app embutido sem PIN, via handshake postMessage mesma-origem)
- **v3.9** — Portal vira porta única (meio-termo): "Comece por aqui" na home + Faturamento/Separação abrem a ferramenta completa embutida (iframe, padrão Estoque)
- **v3.8** — Faturamento tela cheia (abas Vendas · Metas editáveis · Financeiro · Separações · Arquivo) + Separação lista completa com romaneio; tudo imprimível
- **v3.7** — Portal: card "Alimentação de hoje" (diretoria) espelha a Central de Importação
- **v3.6** — Home vira dashboard: Seus painéis por permissão + minhas metas (dados do próprio vendedor)
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

### Acesso unificado + login único (v4.0)
Um cadastro só (o do portal) controla o acesso a tudo, inclusive o que a pessoa vê **dentro** do app de faturamento.
- **Permissões por área** (portal Acessos → `_fatSecHTML`): cada usuário tem a seção "Faturamento — o que a pessoa vê", salva em `usuarios.permissoes.fat_app` = `{metas:'nao'|'ver'|'fat'|'rh'|'dir', sepAcomp, sepDep, sepLoja, painel, vend, equipe}`. Sem mudança de schema (é jsonb).
- **Mapeamento**: `buildFatPerm()` traduz `fat_app` → o `perm` que o app entende (`{sep,loja,admin,painel,vend,metas,metasRole,equipe}`). Diretoria = tudo. Fallback: só o módulo `faturamento` ligado → `metas:'ver'` (ou `'fat'` se editar).
- **Login único (handshake, mesma origem)**: `openFatApp()` no portal responde ao ping `uoma-fat-ready` do iframe com `uoma-portal-auth {nome, perm, screen}`. O app (`_portalApplyAuth`, boot embed-aware) pula o PIN, aplica o `perm` e roteia (área ou deep-link admin/metas). Só aceita `e.origin===location.origin`. Acesso direto ao app (fora do portal) mantém o PIN.
- **Fonte da verdade dos acessos do app**: agora é o portal (`fat_app`). A "Central de Acesso" interna do app (`METAS.acessos`) continua existindo pra uso direto, mas o portal é o caminho normal.
- **Importante**: é controle de **tela** (mostra/esconde áreas) — mesmo nível do app hoje. PII sensível (salário/CPF) está no banco do RH, não aqui.

### Modelo do portal: porta única / hub (v3.9 — decisão do usuário)
O portal é o **centro que orienta e mostra resumos**; pra **operar** o pesado, ele **abre a ferramenta completa embutida** (iframe), sem sair. Padrão herdado do Estoque (`#estOvl`/`#estColetor`/`#estFrame`, `renderEstoquePainel`).
- **"Comece por aqui"** (`renderMyPanels`, home): cards de ação por `ME.role`/`ME.permissoes`, com "o que é" em cada. Card de metas mostra a meta do próprio vendedor ao vivo.
- **Faturamento** (`openFat`→`renderFatFull`): resumo enxuto (vendas + inadimplência) + botão **"🔧 Abrir Faturamento completo"** → `fatOpenTool()` embute `faturamento/index.html` (metas de peso, bônus, regras do RH, planejamento). Fonte única = o app; o portal **não** duplica mais isso.
- **Separação** (`SEP`): lista de pedidos + status + botão **"🔧 Abrir Separação completa"** → `sepOpenTool()` embute a mesma ferramenta (conferência/envio ficam no app).
- **Cópia embutida:** `faturamento/index.html` é um **snapshot** do app `fatcsorveteiro` (recopiar quando o app mudar). Iframe relativo, mesma origem; fechar/voltar resetam `src` pra `about:blank`.
- **Fase 2 (pendente):** abrir **já logado** (pular o PIN e cair direto na tela) exige mexer no app do faturamento — deep-link (estender `wantCampanhas`, linha ~792) + identidade via querystring/postMessage/seed de `localStorage['sepdig_v1']` (hoje o boot força login, linha ~2507).

### Faturamento & Separação dentro do portal (v3.8 — parcialmente ajustado na v3.9)
Lêem o mesmo banco do faturamento (`kopuvuhmqbpvlwksypgm`) via `ensureFAT`/`FSB_URL`/`FSB_KEY` — sem cruzar bancos.
- **Faturamento** (`fatOvl`/`renderFatFull`, tela cheia com abas): **Vendas** (KPIs + equipe ext/int meta×realizado), **Metas cadastradas** (grade objFat/objMix/positObj — editável p/ diretoria ou `permissoes.faturamento==="editar"`, grava via `pushFAT` que re-busca e faz **merge do blob inteiro**; só-leitura pros demais), **Financeiro** (inadimplência por equipe via `teamInadAggFat`, recomputa de `m.vend`), **Separações** (resumo via `SEP.summary`), **Arquivo** (navega todos os meses de `FAT.meses`). Cada aba tem 🖨️ Imprimir (`printSheet`).
- **Separação** (`sepOvl`/módulo IIFE `SEP`): lê `pedidos`/`itens`/`conferencias`/`enviadas`/`logs`, reconstrói via `hydrate` e os helpers de status portados **verbatim** do app (`confOf/countsA/outcome/admState/isSent/workItems`), mostra lista com filtro de data + status (dep/loja conferidos, enviado, cortes), abre **romaneio** por pedido (substituir/ajustar/cortar/OK + entrega + histórico) + 🖨️ imprimir. **Conferência (marcar item) continua no coletor** — aqui é ver + imprimir.
- `openFat`/`openSep` foram **sobrescritos** no fim do script para abrir as telas cheias (os resumos antigos `renderFat`/`renderSep` ficaram órfãos).

### Fora do portal (bancos de operação)
- **Faturamento** (app `index.html` / `fatcsorveteiro`): metas, campanhas, vendas, separação. Banco `kopuvuhmqbpvlwksypgm`.
  - **📥 Central de Importação Diária** (botão na tela de Metas, só faturamento/diretoria): solta **todos os relatórios do Ecocentauro de uma vez** → auto-detecta cada um por marcadores de conteúdo → revisa/override → importa reusando os `import*/parse*` existentes → grava checklist do dia em `METAS.importLog[YYYY-MM-DD]` (chave, hora, nº registros). Auto-detect confirmado (5/5): LISTA DE SEPARAÇÃO→separacao · VEN430LA→prodvend(mix) · VENDAS PESO→marcapeso · BASE PARA INADIMPLÊNCIA→inadvend · REC424LA→financeiro (também: REC408LA→recebidos, (Eco)→metaseco, cadastro de produtos→catalogo). Os `import*` agora re-renderizam via `reRender()` (tela atual), pra o lote não sair da Central. **Pendente:** suporte a CSV (faltam amostras CSV — hoje todos os relatórios saem em HTML).
- **Estoquelsc**: inventário cíclico. Mesmo banco do faturamento. Copiado pra `estoque/` no portal.

_Fim do manual. Atualizar este arquivo a cada marco importante._
