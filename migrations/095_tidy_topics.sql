-- ============================================================================
-- 095_tidy_topics.sql
-- Two kinds of mess were left in the topic list: strands the reader invented
-- from page headers ("Edutest · Test cover page", "…test instructions"), and the
-- same topic twice under slightly different names. Both go.
-- Run after 094. Safe to re-run.
-- ============================================================================

-- 1. headers are not topics
delete from problems where chapter in (
  select n from chapters
  where title ~* 'instructions|cover page|test cover|answer sheet|marks?$'
);
delete from problem_answers where chapter in (
  select n from chapters
  where title ~* 'instructions|cover page|test cover|answer sheet|marks?$'
);
delete from chapters
where title ~* 'instructions|cover page|test cover|answer sheet';

-- 2. one strand per topic: keep the one with the dot separator, drop the twin
create temp table _dupes on commit drop as
with keyed as (
  select c.n, c.source, c.practice, c.title,
         lower(btrim(regexp_replace(
           regexp_replace(c.title, '^(AAS|Edutest|ICAS|AMC|Olympiad)\s*(·)?\s*', ''),
           '[^a-zA-Z0-9]+', ' ', 'g'))) as topic
  from chapters c
  where c.n >= 100
),
ranked as (
  select n, source, topic, title,
         row_number() over (
           partition by source, topic
           order by (practice > 0) desc, (position('·' in title) > 0) desc, n
         ) as rn
  from keyed
)
select n from ranked where rn > 1;

delete from problems where chapter in (select n from _dupes);
delete from problem_answers where chapter in (select n from _dupes);
delete from chapters where n in (select n from _dupes);

-- 3. and anything left holding no questions and no place in a seed is dropped
update chapters set practice = (select count(*) from problems p where p.chapter = chapters.n);
