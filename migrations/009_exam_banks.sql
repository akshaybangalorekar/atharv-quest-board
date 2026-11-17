-- ============================================================================
-- 009_exam_banks.sql
-- Room for exams that are not the book: AAS, Edutest, ICAS, ELMS.
-- Run after 008. Safe to re-run.
--
-- The convention: the book owns chapters 1-24. Every other exam gets its own
-- block of chapter numbers, one chapter per strand, starting at 101.
-- Marking, the weak queue, the plan and the readiness view all keep working
-- unchanged, because they only ever see (chapter, idx).
-- ============================================================================

alter table chapters add column if not exists source text default 'book';
alter table problems add column if not exists source text default 'book';

create table if not exists exam_banks (
  exam text primary key,
  kind text not null,             -- olympiad | aas | edutest | icas | elms
  chapter_from int not null,
  chapter_to int not null,
  note text,
  created_at timestamptz default now()
);
alter table exam_banks enable row level security;
drop policy if exists "read exam_banks" on exam_banks;
create policy "read exam_banks" on exam_banks for select to authenticated using (true);

insert into exam_banks (exam, kind, chapter_from, chapter_to, note) values
  ('Olympiad book', 'olympiad', 1, 24, 'Terry Chew, Maths Olympiad (Advanced). 24 chapters, 288 questions, 109 examples.')
on conflict (exam) do nothing;

-- ---- adding another exam -----------------------------------------------
-- 1. Pick a block of chapter numbers nobody else uses, e.g. 101-110.
-- 2. Insert one chapters row per strand, with source set:
--
--   insert into chapters (n, title, pages, examples, practice, tier, source) values
--     (101, 'AAS · Numerical reasoning — sequences', null, 0, 0, 1, 'aas'),
--     (102, 'AAS · Numerical reasoning — codes',     null, 0, 0, 1, 'aas');
--
-- 3. Insert the questions. idx counts 1..n inside each chapter:
--
--   insert into problems (chapter, idx, prompt, difficulty, technique_tags, source)
--   values (101, 1, 'Next in the sequence: 3, 7, 15, 31, …', 2, array['Sequences'], 'aas');
--
--   insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode)
--   values (101, 1, '63 — double and add one', 'Double, add 1.', '63', 'auto');
--
-- 4. Link those questions to the exam, so the readiness panel sees them:
--
--   insert into exam_map (exam, chapter, idx)
--   select 'AAS numerical reasoning', chapter, idx from problems where source = 'aas';
--
-- 5. Register the bank:
--
--   insert into exam_banks (exam, kind, chapter_from, chapter_to) values
--     ('AAS numerical reasoning', 'aas', 101, 110);
--
-- Below 30 questions the readiness view reports 'thin' on purpose: a handful of
-- items cannot tell you whether he is ready, and saying otherwise would be a lie.

create or replace view v_bank_summary with (security_invoker = on) as
  select coalesce(c.source,'book') as source,
         count(distinct p.chapter) as chapters,
         count(*) as items,
         count(*) filter (where a.mark_mode = 'manual') as manual_items
  from problems p
  join chapters c on c.n = p.chapter
  left join problem_answers a on a.chapter = p.chapter and a.idx = p.idx
  group by 1
  order by 1;

-- check
-- select * from v_bank_summary;
-- select * from v_exam_readiness;
