-- 139_finish_strands.sql
--   strands is the table; chapters is a view over it with write-through triggers
--   problems.chapter references strands(n)
--   sessions and model spend live on the server
alter table strands add column if not exists pages_text text;
update strands s set pages_text = c.pages from chapters c where c.n = s.n and s.pages_text is null;

drop view if exists chapters_view;
alter table chapters rename to chapters_old;

create view chapters as
  select s.n, s.title, coalesce(s.pages_text, s.pages::text) as pages,
         s.examples, s.practice, s.tier, s.source, s.subject, s.exam_id, e.key as exam_key
  from strands s left join exams e on e.id = s.exam_id;

alter table problems drop constraint if exists problems_chapter_fkey;
alter table problems add constraint problems_chapter_fkey
  foreign key (chapter) references strands(n) on delete cascade;

create table if not exists quest_sessions (
  student_id uuid primary key, chapter int, si int not null default 0, script jsonb,
  started_at timestamptz, updated_at timestamptz not null default now(),
  paused boolean not null default false);

create table if not exists llm_usage (
  id bigserial primary key,
  day date not null default (now() at time zone 'Australia/Melbourne')::date,
  fn text not null, calls int not null default 0,
  chars_in bigint not null default 0, chars_out bigint not null default 0,
  updated_at timestamptz not null default now(), unique (day, fn));
