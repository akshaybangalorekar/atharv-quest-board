-- ============================================================================
-- 021_draw.sql
-- Somewhere for a drawn figure, on examples as well as questions.
-- Run after 020. Safe to re-run.
-- ============================================================================

alter table examples add column if not exists diagram_svg text;

create or replace function chapter_pack(p_chapter int)
returns json
language sql security definer set search_path = public as $$
  select json_build_object(
    'chapter', p_chapter,
    'title', (select title from chapters where n = p_chapter),
    'source', (select coalesce(source,'book') from chapters where n = p_chapter),
    'ideas', coalesce((select ideas from chapter_notes where chapter = p_chapter), '[]'::jsonb),
    'summary', (select summary from chapter_notes where chapter = p_chapter),
    'examples', coalesce((select json_agg(json_build_object('n',n,'prompt',prompt,'solution',solution,'svg',diagram_svg) order by n)
                          from examples where chapter = p_chapter), '[]'::json),
    'questions', coalesce((select json_agg(json_build_object('idx',idx,'prompt',prompt,'difficulty',difficulty,'svg',diagram_svg) order by idx)
                           from (select * from problems where chapter = p_chapter order by idx limit 8) q), '[]'::json)
  );
$$;
