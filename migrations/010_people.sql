-- ============================================================================
-- 010_people.sql
-- Links the three accounts once they exist. Run AFTER 008 and 009.
--
-- 1. Create the accounts first: Supabase -> Authentication -> Users ->
--    "Add user" -> "Create new user". Email + password, and tick
--    "Auto Confirm User" so no confirmation email is needed.
--    Do it three times: Atharv, Pooja, Akshay.
-- 2. Replace the three addresses below with the real ones.
-- 3. Run this, then re-run 008_plan_seed.sql to lay the plan on his calendar.
-- Safe to re-run.
-- ============================================================================

insert into profiles (student_id, name, start_date, target_date, timezone,
                      days_per_week, session_min, weekly_minutes)
select id, 'Atharv', date '2026-11-17', date '2027-08-03', 'Australia/Melbourne',
       6, 30, 210
from auth.users
where email = 'REPLACE_WITH_ATHARV_EMAIL'
on conflict (student_id) do update
  set name = excluded.name,
      target_date = excluded.target_date,
      timezone = excluded.timezone,
      days_per_week = excluded.days_per_week,
      session_min = excluded.session_min,
      weekly_minutes = excluded.weekly_minutes;

insert into guardians (parent_id, student_id)
select p.id, s.id
from auth.users p
join auth.users s on s.email = 'REPLACE_WITH_ATHARV_EMAIL'
where p.email in ('REPLACE_WITH_POOJA_EMAIL', 'REPLACE_WITH_AKSHAY_EMAIL')
on conflict do nothing;

-- check: expect one profile, two guardians
-- select name, xp, streak_days, timezone from profiles;
-- select count(*) from guardians;
