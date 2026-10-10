-- =====================================================================
-- MoroHunt — Migration 0002: Expanded profile fields
-- Adds gender, city, and birthdate to profiles, and wires them to
-- auto-populate from sign-up metadata via the existing
-- handle_new_user() trigger.
--
-- IMPORTANT: migration 0001 has already been run against the live
-- project, so this file must be run separately (SQL Editor) — editing
-- 0001_init.sql alone will NOT retroactively apply to an existing
-- database.
-- =====================================================================

alter table public.profiles
    add column if not exists gender text check (gender in ('male', 'female')),
    add column if not exists city text,
    add column if not exists birthdate date;

-- Re-create the sign-up trigger function to also populate the new
-- fields from auth.users.raw_user_meta_data (the `data:` map passed to
-- supabase.auth.signUp on the client). Switched from "on conflict do
-- nothing" to "do update" so re-running sign-up-adjacent flows (or a
-- retried insert) keeps profile fields in sync rather than silently
-- skipping.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
    insert into public.profiles (id, username, gender, city, birthdate)
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
        nullif(new.raw_user_meta_data->>'gender', ''),
        nullif(new.raw_user_meta_data->>'city', ''),
        nullif(new.raw_user_meta_data->>'birthdate', '')::date
    )
    on conflict (id) do update set
        username = excluded.username,
        gender = coalesce(excluded.gender, public.profiles.gender),
        city = coalesce(excluded.city, public.profiles.city),
        birthdate = coalesce(excluded.birthdate, public.profiles.birthdate);
    return new;
end;
$$;

-- Idempotent: (re)create the trigger in case it wasn't already applied
-- from an earlier ad-hoc setup step.
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();
