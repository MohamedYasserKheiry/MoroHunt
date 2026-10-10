// Supabase Edge Function: send-report-email
//
// WHY THIS EXISTS: the Flutter app can't send email directly without
// embedding a third-party email-provider secret in the client, which is
// just as unsafe as embedding the service_role key. Instead, the app
// only ever writes a row into public.user_reports (safe, RLS-protected).
// This function is triggered server-side by a Supabase Database Webhook
// on INSERT into that table, and does the actual emailing using a
// secret that lives only here.
//
// SETUP REQUIRED (you must do this manually — nothing here works until
// you do):
//   1. Create a free account at https://resend.com (or swap this for
//      whatever email API you prefer — SendGrid, Postmark, etc.)
//   2. Get an API key from your provider, then run:
//        supabase secrets set RESEND_API_KEY=your_key_here
//   3. Deploy this function:
//        supabase functions deploy send-report-email
//   4. In the Supabase Dashboard: Database → Webhooks → Create a new
//      webhook on table `user_reports`, event INSERT, pointing at this
//      function's URL (shown after deploying).
//
// Until steps 1-4 are done, reports are still safely stored in the
// database — you just won't get an email until the webhook is wired up.

import { serve } from 'https://deno.land/std@0.203.0/http/server.ts';

const REPORT_RECIPIENT = 'yasser.kheiry26@gmail.com';

serve(async (req) => {
  try {
    const payload = await req.json();
    // Supabase Database Webhooks send { type, table, record, ... }
    const record = payload.record ?? payload;

    const apiKey = Deno.env.get('RESEND_API_KEY');
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: 'RESEND_API_KEY not configured — see setup comment above' }),
        { status: 500 },
      );
    }

    const emailBody = `
      <h2>MoroHunt — New User Report</h2>
      <p><strong>Reporter ID:</strong> ${record.reporter_id}</p>
      <p><strong>Reported User ID:</strong> ${record.reported_user_id}</p>
      <p><strong>Tags:</strong> ${(record.tags ?? []).join(', ')}</p>
      <p><strong>Details:</strong> ${record.details ?? '(none provided)'}</p>
      <p><strong>Submitted at:</strong> ${record.created_at}</p>
    `;

    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'MoroHunt Reports <reports@yourdomain.com>', // must be a domain verified with your provider
        to: [REPORT_RECIPIENT],
        subject: 'MoroHunt — New User Report Submitted',
        html: emailBody,
      }),
    });

    if (!response.ok) {
      const errText = await response.text();
      return new Response(JSON.stringify({ error: errText }), { status: 500 });
    }

    return new Response(JSON.stringify({ success: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
