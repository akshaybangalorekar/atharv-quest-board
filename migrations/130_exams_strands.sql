-- ============================================================================
-- 130_exams_strands.sql — an explicit model for exams and strands.
--
-- Until now "chapter" carried three different meanings: an exam family, a bank,
-- and a topic. That is why the same exam appeared as both "aas" and "AAS".
-- Now there is one exams table, one strands table, and `chapters` becomes a
-- compatibility view over strands, so nothing else has to change today.
-- ============================================================================

create table if not exists exams (
  id      bigserial primary key,
  key     text not null unique,          -- aas, edutest, amc, icas, olympiad
  name    text not null,
  created_at timestamptz not null default now()
);

insert into exams (key, name) values
  ('aas','AAS'), ('edutest','Edutest'), ('amc','AMC'), ('icas','ICAS'), ('olympiad','Olympiad')
on conflict (key) do nothing;

create table if not exists strands (
  n        int primary key,
  exam_id  bigint references exams(id) on delete set null,
  title    text not null,
  source   text,                          -- the bank it came from
  subject  text not null default 'maths',
  practice int not null default 0,
  pages    int,
  examples int not null default 0,
  tier     int not null default 1
);

-- carry the existing rows across, matching each strand to its exam by name
insert into strands (n, exam_id, title, source, subject, practice, pages, examples, tier)
select c.n,
       (select e.id from exams e
         where lower(e.name) = lower(coalesce(c.source,''))
            or lower(e.name) = lower(split_part(c.title, ' · ', 1))
            or (e.key = 'olympiad' and lower(coalesce(c.source,'')) in ('book','apsmo'))
         limit 1),
       c.title, c.source,
       coalesce(c.subject, 'maths'), coalesce(c.practice, 0), nullif(regexp_replace(coalesce(c.pages::text,''), '[^0-9]', '', 'g'), '')::int,
       coalesce(c.examples, 0), coalesce(c.tier, 1)
from chapters c
on conflict (n) do nothing;

-- anything that found no exam belongs to the book
update strands set exam_id = (select id from exams where key = 'olympiad')
 where exam_id is null and lower(coalesce(source,'')) in ('book','apsmo');

select 'exams' as what, count(*) as n from exams
union all select 'strands', count(*) from strands
union all select 'unmatched', count(*) from strands where exam_id is null;
