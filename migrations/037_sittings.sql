-- ============================================================================
-- 037_sittings.sql
-- How long each question should take him, and how an hour is best spent.
--
-- The per-question budget comes from his own record: the median time he takes
-- on questions of that difficulty, nudged by a small allowance for thinking.
-- A chapter that does not fit one sitting is split; if the tail of it is short,
-- the rest of the hour goes to the next chapter rather than being wasted.
-- Run after 036. Safe to re-run.
-- ============================================================================

create or replace function question_budget(p_chapter int, p_idx int)
returns int
language plpgsql security definer set search_path = public as $$
declare
  v uuid := auth.uid();
  v_diff int;
  v_med numeric;
  v_secs int;
begin
  select coalesce(difficulty,2) into v_diff from problems where chapter = p_chapter and idx = p_idx;

  -- his own median for this difficulty, if he has done enough of them
  select percentile_cont(0.5) within group (order by a.seconds)
    into v_med
  from attempts a
  join problems p on p.chapter = a.chapter and p.idx = a.idx
  where a.student_id = v and a.seconds is not null and a.seconds between 5 and 900
    and coalesce(p.difficulty,2) = v_diff
  having count(*) >= 5;

  v_secs := coalesce(round(v_med * 1.15)::int,
             case v_diff when 1 then 90 when 2 then 150 when 3 then 210 else 300 end);

  -- never less than a minute, never more than six
  return greatest(60, least(360, v_secs));
end $$;

create or replace function sitting_plan(p_minutes int default 60)
returns json
language plpgsql security definer set search_path = public as $$
declare
  v uuid := auth.uid();
  v_today date := (now() at time zone 'Australia/Melbourne')::date;
  v_chapter int;
  v_avg int;
  v_fits int;
  v_left int;
  v_take int;
  v_parts int;
  v_topup_ch int;
  v_topup_n int;
  v_room int;
begin
  if v is null then raise exception 'not signed in' using errcode = '28000'; end if;
  p_minutes := greatest(15, least(120, coalesce(p_minutes, 60)));

  select chapter into v_chapter from plan_days
   where student_id = v and day = v_today and lane = 'Q' and chapter is not null
   order by seq limit 1;
  if v_chapter is null then
    select min(chapter) into v_chapter from chapter_progress
     where student_id = v and coalesce(quiz_best,0) < 80;
  end if;
  v_chapter := coalesce(v_chapter, 1);

  -- how many questions an hour holds for him
  select coalesce(round(avg(question_budget(v_chapter, p.idx)))::int, 150) into v_avg
  from problems p where p.chapter = v_chapter;

  v_fits := greatest(3, (p_minutes * 60) / greatest(v_avg, 60));

  select count(*) into v_left
  from problems p
  where p.chapter = v_chapter
    and not exists (select 1 from attempts a
                    where a.student_id = v and a.chapter = p.chapter and a.idx = p.idx and a.ok is true);

  v_take := least(v_left, v_fits);
  v_parts := case when v_left > v_fits then ceil(v_left::numeric / v_fits)::int else 1 end;

  -- if what is left of this chapter fits in a short tail, fill the hour
  v_room := p_minutes - round(v_take * v_avg / 60.0)::int;
  if v_left <= v_fits and v_room >= 15 then
    select min(cp.chapter) into v_topup_ch
    from chapter_progress cp
    where cp.student_id = v and cp.chapter > v_chapter and coalesce(cp.quiz_best,0) < 80;
    if v_topup_ch is null then
      select min(c.n) into v_topup_ch from chapters c
       where c.source = 'book' and c.n > v_chapter
         and not exists (select 1 from chapter_progress cp where cp.student_id = v and cp.chapter = c.n);
    end if;
    v_topup_n := case when v_topup_ch is null then 0
                      else greatest(0, (v_room * 60) / greatest(v_avg,60)) end;
  else
    v_topup_n := 0;
  end if;

  return json_build_object(
    'minutes', p_minutes,
    'chapter', v_chapter,
    'questions', v_take,
    'part', 1,
    'parts', greatest(v_parts, 1),
    'left_in_chapter', v_left,
    'seconds_each', v_avg,
    'topup_chapter', v_topup_ch,
    'topup_questions', coalesce(v_topup_n, 0)
  );
end $$;
