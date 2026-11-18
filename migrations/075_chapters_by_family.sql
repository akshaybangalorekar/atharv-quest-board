-- ============================================================================
-- 075_chapters_by_family.sql
-- chapters_for_exam took an exam name or a kind, but the weekly focus now names
-- a family ("AAS", "Edutest", "Olympiad"), so it came back empty and the coach
-- had no chapter to teach.
-- Run after 074. Safe to re-run.
-- ============================================================================

create or replace function chapters_for_exam(p_exam text)
returns int[]
language plpgsql security definer set search_path = public as $$
declare
  v_kinds text[];
  v_out int[];
begin
  -- an exam name, a kind, or a family: accept all three
  select array_agg(distinct kind) into v_kinds
  from exam_banks
  where lower(exam) = lower(p_exam) or kind = lower(p_exam) or family = lower(p_exam);

  if v_kinds is null then v_kinds := array[lower(p_exam)]; end if;

  -- Edutest's two banks answer for each other
  if 'edutest' = any(v_kinds) or 'elms' = any(v_kinds) then
    v_kinds := array(select distinct unnest(v_kinds || array['edutest','elms']));
  end if;
  -- and Olympiad is the book plus the contest sets
  if 'olympiad' = any(v_kinds) or 'apsmo' = any(v_kinds) then
    v_kinds := array(select distinct unnest(v_kinds || array['book','apsmo']));
  end if;

  select coalesce(array_agg(distinct c.n order by c.n), '{}'::int[]) into v_out
  from chapters c
  where c.source = any(v_kinds);

  return v_out;
end $$;

grant execute on function chapters_for_exam(text) to authenticated;
