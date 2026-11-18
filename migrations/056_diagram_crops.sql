-- ============================================================================
-- 056_diagram_crops.sql
-- A diagram belongs to its question, not to a page. The reader now says where
-- on the page the figure sits, the app cuts that piece out and keeps it, and
-- the question shows the real figure — in colour, exactly as printed.
-- Run after 055. Safe to re-run.
-- ============================================================================

alter table problems add column if not exists diagram_url text;    -- the cut-out figure
alter table problems add column if not exists diagram_box jsonb;    -- where it was on the page
alter table problems add column if not exists diagram_kind text;    -- "simple" or "complex"

create or replace function next_in_chapter(p_chapter int, p_count int default 4)
returns json
language sql security definer set search_path = public as $$
  select coalesce(json_agg(row_to_json(t) order by t.idx), '[]'::json)
  from (
    select p.chapter, p.idx, p.prompt, p.difficulty, p.diagram_svg,
           p.paper_id, p.paper_page, p.options, p.diagram_url, p.diagram_kind
    from problems p
    where p.chapter = p_chapter
      and not exists (select 1 from attempts a
                      where a.student_id = auth.uid()
                        and a.chapter = p.chapter and a.idx = p.idx and a.ok)
    order by p.idx
    limit greatest(1, coalesce(p_count, 4))
  ) t;
$$;
