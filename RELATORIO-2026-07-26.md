# Relatório — Portal Grupo Uoma
### 26/07/2026 · versão atual: **v2.2**

Portal único do colaborador (login único, um só app), evoluindo para o ERP do Grupo Uoma
(Loja do Sorveteiro · Padoquinha · Merenda Certa).

---

## 1. O que foi entregue hoje

| Versão | Entrega |
|--------|---------|
| **v1.4** | Logos por empresa (Loja/Padoquinha sem fundo, Merenda laranja) + apagar publicações do mural |
| **v1.5** | Leitura de perfil robusta (corrige perfil aparecendo como "visualização" por engano) |
| **v1.6** | **Campanhas dentro do portal** (leitura dos dados reais do faturamento, sem login duplo) |
| **v1.7** | **Permissões por módulo** por colaborador: Sem acesso / Ver / Ver e editar |
| **v1.8** | **Adicionar colaborador** pelo portal (cria o login) |
| **v1.9** | **Editor de campanha** no portal: criar, editar e excluir (grava no banco do faturamento) |
| **v2.0** | Correção do cadastro (coluna e-mail) + recuperação de login órfão |
| **v2.1** | Colaborador **começa zerado** — só aparece o que a diretoria liberar |
| **v2.2** | **Painel de versões** (diretoria) + **canal de comunicação com a diretoria** |
| — | **contato.html** — página pública para o **cliente** falar com a diretoria (sem login) |

### Funcionalidades ativas no portal
- **Login único** (Supabase Auth do RH) → nome e perfil corretos.
- **Mural / comunicados:** publicar (diretoria/edição), comentar (todos), apagar publicações.
- **Home:** boas-vindas, apresentação grupo/empresa, avaliação individual, ranking, logos por empresa.
- **Acessos (diretoria):** cadastrar colaborador, definir perfil, empresas e **permissão por módulo**.
- **Campanhas:** ver + **criar / editar / excluir** (para diretoria e quem tiver "Ver e editar").
- **Canal com a diretoria:** colaborador manda mensagem; cliente manda pela página pública; diretoria lê tudo numa caixa e marca como lida.
- **Painel de versões** (rodapé, só diretoria) — histórico do que muda a cada versão.

---

## 2. Como está montado (arquitetura)

- **Dois bancos (Supabase):**
  - **RH** (`gpgycgkqkzedoyilrsmw`) — login, usuários/perfis, folha, mural, **mensagens**. É a *base do grupo* (pessoas/acesso).
  - **Faturamento** (`kopuvuhmqbpvlwksypgm`) — metas, **campanhas**, vendas. Base de *operação*.
- **Login único:** o portal loga uma vez (RH) e **lê dos dois bancos** — cada módulo lê de onde o dado mora. Sem login duplo.
- **Permissões como DADO (não código):** cada colaborador tem perfil + empresas + permissões por módulo, editável no painel de Acessos. Diretoria = admin total.
- **Anti-cache + versão visível** em toda página, para saber na hora se atualizou.

---

## 3. Pendências suas (rodar no Supabase do RH)

**Canal de comunicação — criar a tabela `mensagens`** (senão o "Fale com a diretoria" e o contato do cliente não gravam):

```sql
create table if not exists mensagens (
  id bigint generated always as identity primary key,
  autor_id uuid,
  autor_nome text,
  tipo text default 'colaborador',
  contato text,
  texto text not null,
  lida boolean default false,
  created_at timestamptz default now()
);
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

Já feito por você: coluna `empresas`, `permissoes`, `is_diretoria()`, políticas de leitura/edição/insert de `usuarios`, e **"Confirm email" desligado**.

---

## 4. O que falta / próximos passos

1. **Estoque no portal** — trazer o app `Estoquelsc` (repo informado). Falta você me passar o **banco (Supabase) que ele usa** (URL + chave publishable) e a(s) tabela(s). Aí conecto e desenho igual, como fiz com a campanha.
2. **Sub-permissões por módulo** — o nível fino ("no Faturamento, ver só as vendas"). Vai sendo ligado dentro de cada módulo conforme forem trazidos pro portal.
3. **Encarte PDF da campanha** no portal (hoje é só no app de faturamento).
4. **Segurança da Folha** — antes de dar login a todos, restringir a folha por perfil (hoje qualquer autenticado lê salários).
5. **Aviso do Supabase** — a *view* `aval_media_empresa` está com `SECURITY DEFINER` (aviso "CRITICAL"). Ajustar depois (rápido).
6. **Testar o canal** de ponta a ponta (colaborador e cliente) depois de criar a tabela `mensagens`.

---

## 5. Links

- **Portal (colaboradores):** `home.html` (via `entrar.html`)
- **Contato público (clientes):** `contato.html`
- **Repositório:** github.com/uiliamlourenco1987/Grupo-Uoma
