-- ============================================================================
-- 044_elms_is_edutest.sql
-- ELMS at McKinnon is sat through Edutest, so it is the same paper family as
-- Kilvington: numerical reasoning and mathematics. Preparing for one prepares
-- for the other, and the practice should come out of the same pot.
--
-- A small table says which exams share a question bank. Nothing is duplicated;
-- the ELMS card simply draws from its own chapters and the Edutest ones.
-- Run after 043. Safe to re-run.
-- ============================================================================

create table if not exists exam_shares (
  exam text not null,          -- the exam being prepared for
  also_uses text not null,     -- a kind whose chapters it should draw from
  primary key (exam, also_uses)
);

insert into exam_shares (exam, also_uses) values
  ('ELMS', 'edutest'),
  ('Edutest numerical reasoning', 'elms')
on conflict do nothing;

-- every chapter an exam can be practised from, its own and its neighbours'
create or replace function chapters_for_exam(p_exam text)
returns int[]
language sql security definer set search_path = public as $$
  select coalesce(array_agg(distinct c.n order by c.n), '{}'::int[])
  from chapters c
  where c.source = p_exam
     or c.source in (select also_uses from exam_shares where exam = p_exam)
     or c.source in (select exam from exam_shares where also_uses = p_exam);
$$;

grant execute on function chapters_for_exam(text) to authenticated;
