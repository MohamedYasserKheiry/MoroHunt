-- =====================================================================
-- MoroHunt — Migration 0007: Fix double-counted species increment
--
-- ROOT CAUSE: log_quick_catch inserts p_count rows into `catches`.
-- Each insert fires the pre-existing `catches_after_insert` trigger
-- (migration 0001, trg_increment_prey_counter), which already adds 1
-- per row to the relevant species column — p_count total, correctly,
-- on its own. The function then ALSO ran its own explicit
-- `set sanglier_count = sanglier_count + p_count`, adding p_count a
-- second time on top of what the trigger already applied. Two
-- independent code paths were incrementing the same counter for the
-- same batch of inserts.
--
-- FIX: the trigger remains the single source of truth for species
-- counts (it correctly handles both the original photo-based logging
-- flow AND this quick-log flow identically). The function no longer
-- touches perdrix_count/lievre_count/sanglier_count/caille_count at
-- all — it only explicitly updates rank_points (which has no
-- competing trigger), then reads back the final species count
-- (already correct, thanks to the trigger) to detect badge crossings.
-- =====================================================================

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
    v_new_rank_points int;
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

    if p_lat is null or p_lng is null then
        raise exception 'تعذر تحديد موقعك. الرجاء التأكد من تفعيل خدمة الموقع (GPS) والمحاولة مرة أخرى.';
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
    v_geom := st_setsrid(st_makepoint(p_lng, p_lat), 4326);

    -- Inserting these p_count rows fires trg_increment_prey_counter
    -- once per row — that trigger ALONE now fully and correctly owns
    -- incrementing the species column by exactly p_count. Nothing
    -- below this loop touches perdrix_count/lievre_count/
    -- sanglier_count/caille_count again.
    for i in 1..p_count loop
        insert into public.catches (user_id, prey_type, image_url, geom, weight_tier, points_earned)
        values (v_uid, p_prey_type, null, v_geom,
                case when p_prey_type = 'sanglier' then p_weight_tier else null end,
                v_points_per_unit);
    end loop;

    -- Only rank_points is updated explicitly here — it has no
    -- competing trigger, so this is a single, uncontested increment.
    update public.profiles
    set rank_points = rank_points + v_total_points
    where id = v_uid
    returning rank_points into v_new_rank_points;

    -- Read the species count back (already correct — the trigger did
    -- the only increment) to detect any badge crossing in this batch.
    execute format('select %I from public.profiles where id = $1', v_count_column)
        into v_new_count using v_uid;
    v_current_count := v_new_count - p_count;

    if v_current_count < v_gold and v_new_count >= v_gold then
        v_badge := 'ذهبي';
    elsif v_current_count < v_silver and v_new_count >= v_silver then
        v_badge := 'فضي';
    elsif v_current_count < v_bronze and v_new_count >= v_bronze then
        v_badge := 'برونزي';
    end if;

    if v_badge is not null then
        insert into public.notifications (title, body, user_id)
        values ('إنجاز جديد 🏆',
                'مبروك يا بطل! 🥳 لقد حصلت على وسام ' || v_badge || ' لـ ' || v_species_label ||
                ' بعد وصولك إلى ' || v_new_count || ' طريدة!',
                v_uid);
    end if;

    return query select v_total_points, v_new_count, v_badge, v_new_rank_points;
end;
$$;

notify pgrst, 'reload schema';
