-- ============================================================================
-- 004_cron.sql
-- Scheduling (D9). Run AFTER 002 and 003.
--
-- One job, once a day just after midnight Melbourne:
--   1. writes a `missed` session for every planned lane nobody did;
--   2. zeroes a streak that has a whole skipped day in it;
--   3. moves an overdue milestone to `behind`.
--
-- Everything else that looks "scheduled" is a view and needs no job:
-- due reviews (v_due_reviews), weak techniques (v_weak_techniques), exam
-- readiness (v_exam_readiness), the chapter map (v_chapter_map).
-- ============================================================================

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_cron;

create or replace function tick_daily()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- 1. planned lanes with nothing logged become missed sessions
  insert into sessions (student_id, day, lane, minutes, status)
  select p.student_id, p.day, p.lane, 0, 'missed'
  from plan_days p
  join profiles pr on pr.student_id = p.student_id
  where p.day < (now() at time zone coalesce(pr.timezone,'Australia/Melbourne'))::date
    and p.lane <> 'R'
    and not exists (
      select 1 from sessions s
      where s.student_id = p.student_id and s.day = p.day and s.lane = p.lane
    );

  -- 2. a whole skipped day breaks the streak
  update profiles
     set streak_days = 0
   where last_session_date is not null
     and last_session_date < (now() at time zone coalesce(timezone,'Australia/Melbourne'))::date - 1
     and coalesce(streak_days,0) <> 0;

  -- 3. overdue milestones are behind, not pending
  update milestones
     set status = 'behind'
   where hit_at is null
     and due_date is not null
     and due_date < (now() at time zone 'Australia/Melbourne')::date
     and coalesce(status,'pending') not in ('hit','behind');
end $$;

-- 14:00 UTC is just after midnight in Melbourne all year (AEDT and AEST).
do $$
begin
  perform cron.unschedule('quest-tick-daily');
exception when others then null;
end $$;

select cron.schedule('quest-tick-daily', '0 14 * * *', $$select public.tick_daily()$$);

-- Check it:  select * from cron.job;
