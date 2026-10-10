-- =====================================================================
-- MoroHunt — Migration 0003: Fix catches DELETE policy
--
-- If catch deletion throws:
--   "لم يتم حذف أي سجل من قاعدة البيانات... (RLS policy) catches_delete_own"
-- it means this policy was never actually created on the live project
-- (or was created and later dropped/altered). This script is
-- idempotent — safe to run even if the policy already exists in some
-- form, since it drops it first before recreating it correctly.
--
-- Run this in the Supabase SQL Editor.
-- =====================================================================

drop policy if exists "catches_delete_own" on public.catches;

create policy "catches_delete_own"
    on public.catches
    for delete
    to authenticated
    using (auth.uid() = user_id);

-- Sanity check: confirms RLS is actually enabled on the table (delete
-- policies have no effect at all if RLS itself is off, which would
-- instead behave as "anyone can delete anything" rather than the
-- reported failure — but this is a free, cheap thing to double-check).
alter table public.catches enable row level security;
