-- =====================================================================
-- MoroHunt — Migration 0005: Quick Catch Logging + Achievement Badges
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. catches: photos become optional (quick-log has no photo step),
--    plus weight tier (boar only) and the points earned per row.
-- ---------------------------------------------------------------------
alter table public.catches alter column image_url drop not null;
alter table public.catches add column if not exists weight_tier text
    check (weight_tier in ('normal', 'heavy', 'monster'));
alter table public.catches add column if not exists points_earned int not null default 0;

-- ---------------------------------------------------------------------
-- 2. notifications: add user_id so achievement notifications can be
--    scoped to just the earning user, while NULL user_id keeps meaning
--    "global announcement, visible to everyone" (unchanged behavior).
-- ---------------------------------------------------------------------
alter table public.notifications add column if not exists user_id uuid
    references public.profiles(id) on delete cascade;

drop policy if exists "notifications_select_all" on public.notifications;
create policy "notifications_select_all" on public.notifications
    for select using (user_id is null or user_id = auth.uid());

-- Regular users may only ever insert a notification addressed to
-- THEMSELVES (used by log_quick_catch below for achievement alerts).
-- Global announcements (user_id null) still require the dashboard or
-- service_role — this policy does not allow inserting those.
create policy "notifications_insert_own" on public.notifications
    for insert with check (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- 3. log_quick_catch — the whole "no-photo" quick logging flow in one
--    atomic function: inserts one catches row per animal (so map-pin
--    grouping-by-location still works exactly like the photo flow),
--    computes weight-aware boar scoring, updates the species counter +
--    total rank_points on profiles, detects the highest badge tier
--    newly crossed by this submission, and — if one was crossed —
--    inserts a personal congratulatory notification.
--
--    Runs as SECURITY INVOKER (the default — no `security definer`
--    here), so every insert/update inside still goes through normal
--    RLS as the calling user; nothing here bypasses row-level security.
-- ---------------------------------------------------------------------
create or replace function public.log_quick_catch(
    p_prey_type text,
    p_count int,
    p_weight_tier text default null,
    p_lat double precision default null,
    p_lng double precision default null
)
returns table (
    total_points_earned int,
    new_species_count int,
    badge_unlocked text,
    new_rank_points int
)
language plpgsql
as $$
declare
    v_uid uuid := auth.uid();
    v_points_per_unit int;
    v_total_points int;
    v_count_column text;
    v_current_count int;
    v_new_count int;
    v_badge text := null;
    v_bronze int;
    v_silver int;
    v_gold int;
    v_species_label text;
    v_geom geometry;
    i int;
begin
    if v_uid is null then
        raise exception 'not authenticated';
    end if;

    if p_count is null or p_count <= 0 then
        raise exception 'invalid count';
    end if;

    if p_prey_type = 'sanglier' then
        v_points_per_unit := case p_weight_tier
            when 'heavy' then 120
            when 'monster' then 150
            else 100
        end;
        v_count_column := 'sanglier_count';
        v_bronze := 10; v_silver := 20; v_gold := 30;
        v_species_label := 'الخنزير البري';
    elsif p_prey_type = 'perdrix' then
        v_points_per_unit := 20;
        v_count_column := 'perdrix_count';
        v_bronze := 30; v_silver := 60; v_gold := 100;
        v_species_label := 'الحجل البري';
    elsif p_prey_type = 'lievre' then
        v_points_per_unit := 25;
        v_count_column := 'lievre_count';
        v_bronze := 20; v_silver := 40; v_gold := 60;
        v_species_label := 'الأرنب البري';
    elsif p_prey_type = 'caille' then
        v_points_per_unit := 5;
        v_count_column := 'caille_count';
        v_bronze := 50; v_silver := 100; v_gold := 200;
        v_species_label := 'السمان';
    else
        raise exception 'unsupported prey_type for quick logging: %', p_prey_type;
    end if;

    v_total_points := v_points_per_unit * p_count;

    if p_lat is not null and p_lng is not null then
        v_geom := st_setsrid(st_makepoint(p_lng, p_lat), 4326);
    end if;

    for i in 1..p_count loop
        insert into public.catches (user_id, prey_type, image_url, geom, weight_tier, points_earned)
        values (
            v_uid,
            p_prey_type,
            null,
            v_geom,
            case when p_prey_type = 'sanglier' then p_weight_tier else null end,
            v_points_per_unit
        );
    end loop;

    execute format('select %I from public.profiles where id = $1', v_count_column)
        into v_current_count using v_uid;
    v_current_count := coalesce(v_current_count, 0);
    v_new_count := v_current_count + p_count;

    execute format(
        'update public.profiles set %I = %I + $1, rank_points = rank_points + $2 where id = $3',
        v_count_column, v_count_column
    ) using p_count, v_total_points, v_uid;

    -- Highest newly-crossed tier in this single submission (a big
    -- batch that jumps straight past bronze and silver into gold only
    -- notifies for gold, not all three).
    if v_current_count < v_gold and v_new_count >= v_gold then
        v_badge := 'ذهبي';
    elsif v_current_count < v_silver and v_new_count >= v_silver then
        v_badge := 'فضي';
    elsif v_current_count < v_bronze and v_new_count >= v_bronze then
        v_badge := 'برونزي';
    end if;

    if v_badge is not null then
        insert into public.notifications (title, body, user_id)
        values (
            'إنجاز جديد 🏆',
            'مبروك يا بطل! 🥳 لقد حصلت على وسام ' || v_badge || ' لـ ' || v_species_label ||
            ' بعد وصولك إلى ' || v_new_count || ' طريدة!',
            v_uid
        );
    end if;

    return query select
        v_total_points,
        v_new_count,
        v_badge,
        (select rank_points from public.profiles where id = v_uid);
end;
$$;

-- Force PostgREST to pick up this new function immediately rather than
-- waiting for its periodic automatic schema refresh.
notify pgrst, 'reload schema';
