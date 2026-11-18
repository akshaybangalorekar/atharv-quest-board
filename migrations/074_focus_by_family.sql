-- ============================================================================
-- 074_focus_by_family.sql
-- The weekly split listed "book" and "APSMO Division J" as if they were two
-- different things. They are one: Olympiad. The split is reported by family now,
-- with the percentages added together.
-- Run after 073. Safe to re-run.
-- ============================================================================

create or replace function teaching_focus()
returns json
language plpgsql security definer set search_path = public as $$
declare
  v uuid := coalesce(viewing_student(), auth.uid());
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
           case when c.exam in ('ELMS', 'Edutest numerical reasoning') then 'Edutest'
                when c.exam in ('APSMO Division J', 'Olympiad book') then 'Olympiad'
                when c.exam = 'AAS numerical reasoning' then 'AAS'
                when c.exam = 'AMC Upper Primary' then 'AMC'
                when c.exam = 'ICAS Maths' then 'ICAS'
                else c.exam end as family
    from exam_calendar c
    where c.student_id = v and c.sits_on >= v_today
  ),
  fams as (select family, min(days_away) as days_away from upcoming group by family),
  nearest as (select * from fams order by days_away limit 3),
  weighted as (
    select family, days_away,
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
    select 'Olympiad'::text, coalesce((select min(days_away) from weighted), 999),
           greatest(40, 100 - coalesce(sum(share), 0))::int
    from weighted
  ),
  folded as (
    select family, min(days_away) as days_away, sum(share) as share
    from all_rows group by family
  ),
  normalised as (
    select family, days_away, round(100.0 * share / sum(share) over ())::int as pct from folded
  )
  select coalesce(json_agg(json_build_object('exam', family, 'days_away', days_away, 'pct', pct) order by pct desc), '[]'::json)
    into v_rows from normalised;

  select exam into v_primary
  from json_to_recordset(v_rows) as x(exam text, days_away int, pct int)
  where exam <> 'Olympiad' order by pct desc, days_away asc limit 1;
  v_primary := coalesce(v_primary, 'Olympiad');

  v_kind := case v_primary when 'Olympiad' then 'olympiad' when 'Edutest' then 'edutest'
                          when 'AAS' then 'aas' when 'AMC' then 'amc' when 'ICAS' then 'icas'
                          else v_primary end;

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
      then 'No exam is close — keep building technique from Olympiad.'
      else 'Exam work leads this week, with Olympiad kept in for technique.' end
  );
end $$;

grant execute on function teaching_focus() to authenticated;
