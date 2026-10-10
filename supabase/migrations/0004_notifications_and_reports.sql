-- =====================================================================
-- MoroHunt — Migration 0004: Notifications + User Reports
-- =====================================================================

-- ---------------------------------------------------------------------
-- NOTIFICATIONS (admin-managed announcements / news / tournament info)
-- Read-only from the client. Insert/update/delete only via the
-- Supabase dashboard or service_role — there is intentionally no
-- client-facing write policy.
-- ---------------------------------------------------------------------
create table if not exists public.notifications (
    id uuid default gen_random_uuid() primary key,
    title text not null,
    body text not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.notifications enable row level security;

create policy "notifications_select_all" on public.notifications
    for select using (true);

-- ---------------------------------------------------------------------
-- USER REPORTS (peer reporting from the Leaderboard)
-- Any authenticated user can file a report about another user.
-- Deliberately NO select/update/delete policy for regular users —
-- reports are only ever readable by admins via the Supabase dashboard
-- or a service_role-backed Edge Function, never by other app users.
-- ---------------------------------------------------------------------
create table if not exists public.user_reports (
    id uuid default gen_random_uuid() primary key,
    reporter_id uuid references public.profiles(id) on delete cascade not null,
    reported_user_id uuid references public.profiles(id) on delete cascade not null,
    tags text[] not null default '{}',
    details text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.user_reports enable row level security;

create policy "user_reports_insert_own" on public.user_reports
    for insert with check (auth.uid() = reporter_id);

-- ---------------------------------------------------------------------
-- OPTIONAL: to actually email yasser.kheiry26@gmail.com whenever a
-- report is inserted, set up a Database Webhook (no SQL needed):
--   Supabase Dashboard → Database → Webhooks → Create a new webhook
--   Table: user_reports · Event: INSERT
--   Target: your deployed `send-report-email` Edge Function URL
-- See supabase/functions/send-report-email/index.ts in this project.
-- ---------------------------------------------------------------------
