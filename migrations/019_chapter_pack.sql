-- ============================================================================
-- 019_chapter_pack.sql
-- One call that gives the coach everything about a chapter it has been asked to
-- teach — including chapters that are not in the book (AAS, Edutest, ICAS), so
-- uploaded questions get taught from and not just counted.
-- Run after 018. Safe to re-run.
-- ============================================================================

create or replace function chapter_pack(p_chapter int)
returns json
language sql security definer set search_path = public as $$
  select json_build_object(
    'chapter', p_chapter,
    'title', (select title from chapters where n = p_chapter),
    'source', (select coalesce(source,'book') from chapters where n = p_chapter),
    'ideas', coalesce((select ideas from chapter_notes where chapter = p_chapter), '[]'::jsonb),
    'summary', (select summary from chapter_notes where chapter = p_chapter),
    'examples', coalesce((select json_agg(json_build_object('n',n,'prompt',prompt,'solution',solution) order by n)
                          from examples where chapter = p_chapter), '[]'::json),
    'questions', coalesce((select json_agg(json_build_object('idx',idx,'prompt',prompt,'difficulty',difficulty) order by idx)
                           from (select * from problems where chapter = p_chapter order by idx limit 8) q), '[]'::json)
  );
$$;

grant execute on function chapter_pack(int) to authenticated;
