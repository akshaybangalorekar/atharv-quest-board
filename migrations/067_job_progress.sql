-- ============================================================================
-- 067_job_progress.sql
-- The reading bar had no total to move against: a job started with 0 pages and
-- only ever reported what was done. It now learns the page count as soon as the
-- file is opened, and the app watches the job from any screen.
-- Run after 066. Safe to re-run.
-- ============================================================================

create or replace function set_job_total(p_id bigint, p_total int)
returns void
language sql security definer set search_path = public as $$
  update parse_jobs set pages_total = greatest(1, coalesce(p_total,1)), updated_at = now()
  where id = p_id and student_id = (select auth.uid());
$$;

grant execute on function set_job_total(bigint, int) to authenticated;

-- one row, whatever the caller: what is running, and how far along
create or replace function parse_progress()
returns json
language sql security definer set search_path = public as $$
  select row_to_json(t) from (
    select id, status, pages_done, pages_total, added, unanswered, strand, note
    from parse_jobs
    where student_id = coalesce(viewing_student(), auth.uid())
    order by created_at desc limit 1
  ) t;
$$;

grant execute on function parse_progress() to authenticated;
