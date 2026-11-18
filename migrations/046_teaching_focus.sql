-- ============================================================================
-- 046_teaching_focus.sql
-- Which exam the coach should be teaching for, and how the week should be split.
--
-- The rule, plainly: the book is the backbone and always gets a share. As a real
-- exam comes close its share grows, and inside eight weeks it takes the larger
-- half. ELMS and Kilvington are one pot, because they are one paper family.
-- Run after 045. Safe to re-run.
-- ============================================================================

create or replace function teaching_focus()
returns json
language plpgsql security definer set search_path = public as $$
declare
  v uuid := auth.uid();
  v_today date := (now() at time zone 'Australia/Melbourne')::date;
  v_rows json;
  v_primary text;
  v_chapter int;
begin
  if v is null then raise exception 'not signed in' using errcode = '28000'; end if;

  with upcoming as (
    select c.exam,
           c.sits_on - v_today as days_away,
           -- one pot for the Edutest family
           case when c.exam in ('ELMS', 'Edutest numerical reasoning') then 'edutest' else c.exam end as pot,
           c.date_status
    from exam_calendar c
    where c.student_id = v and c.sits_on >= v_today
  ),
  pots as (
    select pot, min(days_away) as days_away, min(exam) as exam
    from upcoming group by pot
  ),
  weighted as (
    select exam, days_away,
           case
             when days_away <= 21 then 55
             when days_away <= 56 then 40
             when days_away <= 120 then 25
             when days_away <= 240 then 12
             else 6
           end as share
    from pots
  ),
  book as (
    -- the book always has a place: it is where the technique comes from
    select 'Olympiad book'::text as exam,
           coalesce((select min(days_away) from weighted), 999) as days_away,
           greatest(40, 100 - coalesce(sum(share), 0)) as share
    from weighted
  ),
  all_rows as (
    select * from book
    union all select * from weighted where share > 0
  ),
  normalised as (
    select exam, days_away,
           round(100.0 * share / sum(share) over ())::int as pct
    from all_rows
  )
  select coalesce(json_agg(json_build_object('exam', exam, 'days_away', days_away, 'pct', pct)
                           order by pct desc), '[]'::json)
    into v_rows
  from normalised;

  select exam into v_primary
  from json_to_recordset(v_rows) as x(exam text, days_away int, pct int)
  where exam <> 'Olympiad book'
  order by pct desc, days_away asc
  limit 1;
  v_primary := coalesce(v_primary, 'Olympiad book');

  -- the next chapter for whichever exam leads
  if v_primary = 'Olympiad book' then
    select min(cp.chapter) into v_chapter from chapter_progress cp
     where cp.student_id = v and coalesce(cp.quiz_best,0) < 80;
    v_chapter := coalesce(v_chapter, (select min(n) from chapters where source = 'book'));
  else
    select min(c.n) into v_chapter
    from chapters c
    where c.n = any (chapters_for_exam(v_primary))
      and not exists (select 1 from attempts a
                      where a.student_id = v and a.chapter = c.n and a.ok is true);
    v_chapter := coalesce(v_chapter, (select min(n) from chapters where source = v_primary));
  end if;

  return json_build_object(
    'today', v_today,
    'week_of', v_today - extract(dow from v_today)::int,
    'split', v_rows,
    'primary_exam', v_primary,
    'primary_chapter', v_chapter,
    'note', case
      when v_primary = 'Olympiad book' then 'No exam is close — keep building technique from the book.'
      else 'Exam work leads this week, with the book kept in for technique.'
    end
  );
end $$;

grant execute on function teaching_focus() to authenticated;
