-- ============================================================================
-- 047_focus_fix.sql
-- Two corrections to the teaching focus:
--   * chapters_for_exam took an exam name but compared it to a kind, so it
--     returned nothing and the chapter came back empty.
--   * the weekly split listed every exam in the diary; a week can hold three.
-- Run after 046. Safe to re-run.
-- ============================================================================

create or replace function chapters_for_exam(p_exam text)
returns int[]
language plpgsql security definer set search_path = public as $$
declare
  v_kind text;
  v_out int[];
begin
  -- accept either the exam's name or its kind
  select kind into v_kind from exam_banks where exam = p_exam;
  v_kind := coalesce(v_kind, p_exam);

  select coalesce(array_agg(distinct c.n order by c.n), '{}'::int[]) into v_out
  from chapters c
  where c.source = v_kind
     or c.source in (select also_uses from exam_shares where exam = p_exam or exam = v_kind)
     or c.source in (select exam from exam_shares where also_uses = p_exam or also_uses = v_kind);
  return v_out;
end $$;

grant execute on function chapters_for_exam(text) to authenticated;

create or replace function teaching_focus()
returns json
language plpgsql security definer set search_path = public as $$
declare
  v uuid := auth.uid();
  v_today date := (now() at time zone 'Australia/Melbourne')::date;
  v_rows json;
  v_primary text;
  v_kind text;
  v_chapter int;
begin
  if v is null then raise exception 'not signed in' using errcode = '28000'; end if;

  with upcoming as (
    select c.exam,
           c.sits_on - v_today as days_away,
           case when c.exam in ('ELMS', 'Edutest numerical reasoning') then 'Edutest numerical reasoning' else c.exam end as pot
    from exam_calendar c
    where c.student_id = v and c.sits_on >= v_today
  ),
  pots as (select pot as exam, min(days_away) as days_away from upcoming group by pot),
  -- the three nearest, which is as many as a week can hold alongside the book
  nearest as (select * from pots order by days_away limit 3),
  weighted as (
    select exam, days_away,
           case when days_away <= 21 then 55
                when days_away <= 56 then 40
                when days_away <= 120 then 25
                when days_away <= 240 then 12
                else 6 end as share
    from nearest
  ),
  all_rows as (
    select * from weighted
    union all
    select 'Olympiad book'::text, coalesce((select min(days_away) from weighted), 999),
           greatest(40, 100 - coalesce(sum(share), 0))::int
    from weighted
  ),
  normalised as (
    select exam, days_away, round(100.0 * share / sum(share) over ())::int as pct from all_rows
  )
  select coalesce(json_agg(json_build_object('exam', exam, 'days_away', days_away, 'pct', pct) order by pct desc), '[]'::json)
    into v_rows from normalised;

  select exam into v_primary
  from json_to_recordset(v_rows) as x(exam text, days_away int, pct int)
  where exam <> 'Olympiad book' order by pct desc, days_away asc limit 1;
  v_primary := coalesce(v_primary, 'Olympiad book');

  select kind into v_kind from exam_banks where exam = v_primary;
  v_kind := coalesce(v_kind, case when v_primary = 'Olympiad book' then 'olympiad' else v_primary end);

  if v_kind = 'olympiad' then
    select min(cp.chapter) into v_chapter from chapter_progress cp
     where cp.student_id = v and coalesce(cp.quiz_best,0) < 80;
    v_chapter := coalesce(v_chapter, (select min(n) from chapters where source = 'book'));
  else
    select min(c.n) into v_chapter
    from chapters c
    where c.n = any (chapters_for_exam(v_primary))
      and not exists (select 1 from attempts a
                      where a.student_id = v and a.chapter = c.n and a.ok is true);
    v_chapter := coalesce(v_chapter, (select min(n) from chapters where n = any (chapters_for_exam(v_primary))));
  end if;

  return json_build_object(
    'today', v_today,
    'split', v_rows,
    'primary_exam', v_primary,
    'primary_kind', v_kind,
    'primary_chapter', v_chapter,
    'note', case when v_kind = 'olympiad'
      then 'No exam is close — keep building technique from the book.'
      else 'Exam work leads this week, with the book kept in for technique.' end
  );
end $$;

grant execute on function teaching_focus() to authenticated;
