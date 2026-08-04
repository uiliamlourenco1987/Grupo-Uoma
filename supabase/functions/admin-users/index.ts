// Edge Function: admin-users
// Operações administrativas de login que exigem a chave admin (service_role):
//   - reset_password : define uma nova senha para um usuário
//   - update_email   : corrige o e-mail de um login (auth + tabela usuarios)
//   - delete_user    : apaga o login (auth + tabela usuarios)
//
// Segurança: só quem está logado E tem role 'diretoria' na tabela usuarios pode chamar.
// A service_role NUNCA vai pro navegador — fica só aqui no servidor.
//
// Deploy (uma vez): ver instruções no final deste arquivo.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(obj: unknown, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "método inválido" }, 405);

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // 1) autentica o chamador pelo token que o portal envia
    const jwt = (req.headers.get("Authorization") || "").replace("Bearer ", "");
    if (!jwt) return json({ error: "sem token de acesso" }, 401);
    const asUser = createClient(url, anon, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });
    const { data: who } = await asUser.auth.getUser();
    if (!who?.user) return json({ error: "não autenticado" }, 401);

    // 2) confirma que é diretoria (checagem no servidor, com a service_role)
    const admin = createClient(url, service);
    const { data: perfil } = await admin
      .from("usuarios")
      .select("role")
      .eq("id", who.user.id)
      .single();
    if (!perfil || perfil.role !== "diretoria") {
      return json({ error: "apenas a diretoria pode fazer isso" }, 403);
    }

    // 3) executa a ação pedida
    const { action, user_id, email, senha } = await req.json();

    if (action === "reset_password") {
      if (!user_id || !senha || String(senha).length < 6) {
        return json({ error: "informe user_id e senha (mín. 6)" }, 400);
      }
      const { error } = await admin.auth.admin.updateUserById(user_id, {
        password: String(senha),
      });
      if (error) throw error;
      return json({ ok: true });
    }

    if (action === "update_email") {
      if (!user_id || !email) return json({ error: "informe user_id e email" }, 400);
      const { error } = await admin.auth.admin.updateUserById(user_id, {
        email: String(email),
        email_confirm: true,
      });
      if (error) throw error;
      await admin.from("usuarios").update({ email: String(email) }).eq("id", user_id);
      return json({ ok: true });
    }

    if (action === "delete_user") {
      if (!user_id) return json({ error: "informe user_id" }, 400);
      const { error } = await admin.auth.admin.deleteUser(user_id);
      if (error) throw error;
      await admin.from("usuarios").delete().eq("id", user_id);
      return json({ ok: true });
    }

    return json({ error: "ação desconhecida" }, 400);
  } catch (e) {
    return json({ error: String((e as Error)?.message || e) }, 500);
  }
});

/*
─────────────────────────────────────────────────────────────────────────────
COMO PUBLICAR (uma vez), no painel do Supabase do RH:

Opção A — pelo painel (mais fácil):
  1. Supabase → Edge Functions → "Deploy a new function".
  2. Nome: admin-users
  3. Cole TODO o código acima.
  4. DESLIGUE "Verify JWT" (a checagem de permissão é feita aqui dentro).
  5. Deploy.
  As chaves SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY já
  vêm preenchidas automaticamente — não precisa configurar nada.

Opção B — pela CLI:
  supabase functions deploy admin-users --no-verify-jwt

Depois de publicada, me avise que eu ligo os botões no Controle de Acessos
(🔑 Resetar senha · ✉️ Corrigir e-mail · 🗑 Apagar login) chamando esta função.
─────────────────────────────────────────────────────────────────────────────
*/
