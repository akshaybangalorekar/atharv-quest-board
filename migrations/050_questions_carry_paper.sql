-- ============================================================================
-- 050_questions_carry_paper.sql
-- next_in_chapter must hand the paper and page along with the question, or the
-- app has no way to know which page to show.
-- Run after 049. Safe to re-run.
-- ============================================================================

create or replace function next_in_chapter(p_chapter int, p_count int default 4)
returns json
language sql security definer set search_path = public as $$
  select coalesce(json_agg(row_to_json(t) order by t.idx), '[]'::json)
  from (
    select p.chapter, p.idx, p.prompt, p.difficulty, p.diagram_svg, p.paper_id, p.paper_page
    from problems p
    where p.chapter = p_chapter
      and not exists (select 1 from attempts a
                      where a.student_id = auth.uid()
                        and a.chapter = p.chapter and a.idx = p.idx and a.ok)
    order by p.idx
    limit greatest(1, coalesce(p_count, 4))
  ) t;
$$;
