-- ============================================================================
-- 061_parent_readiness_family.sql
-- The parent's readiness figure came from exam_readiness_for(), which still
-- counted one row per bank — so Edutest and McKinnon appeared as two exams and
-- the book and Division J as two more. It now reports one row per family.
-- Run after 060. Safe to re-run.
-- ============================================================================

create or replace function exam_readiness_for(p_student uuid default null)
returns json
language plpgsql security definer set search_path = public as $$
declare
  v_student uuid := coalesce(p_student, viewing_student());
  v_out json;
begin
  select coalesce(json_agg(json_build_object(
           'exam', exam, 'schools', schools, 'items', items, 'practised', practised,
           'pct_practised', pct_practised, 'verdict', verdict, 'message', message,
           'mastered', 0) order by exam), '[]'::json)
    into v_out
  from v_exam_readiness;
  return v_out;
end $$;
