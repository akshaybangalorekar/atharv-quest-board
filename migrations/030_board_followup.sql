-- ============================================================================
-- 030_board_followup.sql
-- What he still has to write on the physical board, so she can ask next time.
-- Run after 029. Safe to re-run.
-- ============================================================================

create or replace function board_pending()
returns json
language sql security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object('chapter', chapter, 'technique', technique, 'since', since)
                           order by chapter), '[]'::json)
  from (
    select c.n as chapter, trim(both '"' from idea::text) as technique,
           (select min(a.created_at)::date from attempts a
             where a.student_id = auth.uid() and a.chapter = c.n) as since
    from chapters c
    join chapter_notes n on n.chapter = c.n
    cross join lateral jsonb_array_elements(n.ideas) idea
    where c.n between 1 and 24
      and exists (select 1 from attempts a where a.student_id = auth.uid() and a.chapter = c.n)
      and not exists (select 1 from formula_board f
                      where f.student_id = auth.uid() and f.chapter = c.n
                        and f.technique = trim(both '"' from idea::text))
  ) t;
$$;
