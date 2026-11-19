-- ============================================================================
-- 099_whats_new.sql
-- What has arrived for an exam lately — a paper a parent added, or questions the
-- coach wrote — with how long ago it was.
-- Run after 098. Safe to re-run.
-- ============================================================================

create or replace function whats_new(p_family text)
returns json
language sql security definer set search_path = public as $$
  with who as (select coalesce(viewing_student(), auth.uid()) as sid),
  kinds as (
    select array_agg(distinct case when b.kind = 'olympiad' then 'book' else b.kind end) as ks,
           array_agg(distinct b.exam) as exams
    from exam_banks b
    where lower(b.family) = lower(p_family) or lower(b.kind) = lower(p_family)
  ),
  today as (select (now() at time zone 'Australia/Melbourne')::date as d),
  files as (
    select pa.title as what, 'file' as kind, coalesce(pa.questions, 0) as n,
           pa.created_at as at,
           ((select d from today) - (pa.created_at at time zone 'Australia/Melbourne')::date) as days_ago
    from papers pa, who, kinds
    where pa.student_id = who.sid
      and (pa.exam = any(kinds.exams) or pa.exam = any(kinds.ks))
  ),
  written as (
    select t.exam as what, 'coach' as kind, t.made as n, t.at,
           ((select d from today) - (t.at at time zone 'Australia/Melbourne')::date) as days_ago
    from question_topups t, who, kinds
    where t.student_id = who.sid and t.made > 0
      and (t.exam = any(kinds.exams) or t.exam = any(kinds.ks))
  )
  select coalesce(json_agg(row_to_json(x) order by x.at desc), '[]'::json)
  from (select * from files union all select * from written) x;
$$;

grant execute on function whats_new(text) to authenticated;
