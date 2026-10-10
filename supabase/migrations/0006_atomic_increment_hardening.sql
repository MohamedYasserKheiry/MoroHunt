-- =====================================================================
-- MoroHunt — Migration 0006 (FIXED): Atomic increment hardening & Badge Enum fix
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

    -- Mapping thresholds & counts
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

    -- Insert individual catch items
    for i in 1..p_count loop
        insert into public.catches (user_id, prey_type, image_url, geom, weight_tier, points_earned)
        values (v_uid, p_prey_type, null, v_geom,
                case when p_prey_type = 'sanglier' then p_weight_tier else null end,
                v_points_per_unit);
    end loop;

    -- Atomic Update & Fetch
    execute format(
        'update public.profiles
         set %I = %I + $1, rank_points = rank_points + $2
         where id = $3
         returning %I, %I - $1, rank_points',
        v_count_column, v_count_column, v_count_column, v_count_column
    ) into v_new_count, v_current_count, v_new_rank_points
      using p_count, v_total_points, v_uid;

    -- FIX 1: Set Badge values to English Keys ('Gold', 'Silver', 'Bronze') so Flutter UI matches correctly
    if v_current_count < v_gold and v_new_count >= v_gold then
        v_badge := 'Gold';
    elsif v_current_count < v_silver and v_new_count >= v_silver then
        v_badge := 'Silver';
    elsif v_current_count < v_bronze and v_new_count >= v_bronze then
        v_badge := 'Bronze';
    end if;

    -- Notification creation
    if v_badge is not null then
        insert into public.notifications (title, body, user_id)
        values ('إنجاز جديد 🏆',
                'مبروك يا بطل! 🥳 لقد حصلت على وسام ' || 
                case v_badge 
                    when 'Gold' then 'الذهبي' 
                    when 'Silver' then 'الفضي' 
                    else 'البرونزي' 
                end || ' لـ ' || v_species_label || ' بعد وصولك إلى ' || v_new_count || ' طريدة!',
                v_uid);
    end if;

    return query select v_total_points, v_new_count, v_badge, v_new_rank_points;
end;
$$;

notify pgrst, 'reload schema';