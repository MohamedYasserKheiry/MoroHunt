// Supabase Edge Function: delete-account
//
// WHY THIS EXISTS AS A SEPARATE SERVER-SIDE FUNCTION (read before deploying):
// Deleting a row from auth.users requires the `service_role` key — the
// key that bypasses Row Level Security entirely. That key must NEVER be
// embedded in the Flutter app; anyone could extract it from the compiled
// binary and gain full admin access to your entire database. This
// function keeps that secret only on Supabase's servers (as a function
// secret), and only runs the deletion after verifying the caller's own
// valid session JWT — so a user can only ever delete their OWN account.
//
// DEPLOY:
//   supabase functions deploy delete-account
//
// The SUPABASE_SERVICE_ROLE_KEY and SUPABASE_URL secrets are already
// available to every Edge Function automatically — no manual secret
// setup needed for those two.

import { serve } from 'https://deno.land/std@0.203.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
        status: 401,
      });
    }

    // Client scoped to the CALLER's own JWT — used only to verify who
    // they are, never to perform the privileged delete itself.
    const callerClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: userData, error: userError } = await callerClient.auth.getUser();
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: 'Invalid or expired session' }), {
        status: 401,
      });
    }

    const userId = userData.user.id;

    // Privileged client — service_role key, lives ONLY here on the
    // server, never shipped to any client app.
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // Deleting the auth user cascades to public.profiles (and from
    // there to dogs/catches/etc.) via the "on delete cascade" foreign
    // keys already defined in the schema — no manual cleanup needed.
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId);
    if (deleteError) {
      return new Response(JSON.stringify({ error: deleteError.message }), { status: 500 });
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
