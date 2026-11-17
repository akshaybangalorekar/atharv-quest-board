-- ============================================================================
-- 033_placement.sql
-- A short placement check: twelve questions across the book, in rising
-- difficulty, so the coach knows where he actually stands before it plans much.
-- Run after 032. Safe to re-run.
-- ============================================================================

create or replace function start_placement(p_count int default 12)
returns json
language plpgsql security definer set search_path = public as $$
declare
  v_student uuid := auth.uid();
  v_exam uuid;
  v_items json;
begin
  if v_student is null then raise exception 'not signed in' using errcode = '28000'; end if;

  -- two questions from each of six chapters spread across the book,
  -- the harder one of each pair, so it finds the ceiling quickly
  with picks as (
    select p.chapter, p.idx,
           row_number() over (partition by p.chapter order by p.difficulty desc, random()) as rn
    from problems p
    where p.source = 'book'
      and p.chapter in (1, 3, 5, 8, 13, 17)
      and p.difficulty >= 2
  )
  select json_agg(json_build_object('chapter', chapter, 'idx', idx) order by chapter, idx)
    into v_items
  from picks where rn <= 2;

  insert into exam_mocks (student_id, kind, scope, total, pass_bar, started_at)
  values (v_student, 'placement', 'the book, six strands', coalesce(json_array_length(v_items),0), 60, now())
  returning id into v_exam;

  insert into exam_items (exam_id, chapter, idx)
  select v_exam, (i->>'chapter')::int, (i->>'idx')::int
  from json_array_elements(v_items) i;

  return json_build_object(
    'exam_id', v_exam, 'minutes', 20,
    'items', coalesce((
      select json_agg(json_build_object('chapter', p.chapter, 'idx', p.idx, 'prompt', p.prompt,
                                        'diagram_svg', p.diagram_svg) order by p.chapter, p.idx)
      from exam_items e join problems p on p.chapter = e.chapter and p.idx = e.idx
      where e.exam_id = v_exam), '[]'::json)
  );
end $$;
