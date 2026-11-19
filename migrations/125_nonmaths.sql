-- ============================================================================
-- 125_nonmaths.sql — the sections that are not maths get their own strands,
-- so questions can be written for them and practised like any other topic.
-- ============================================================================

alter table chapters add column if not exists subject text not null default 'maths';

insert into training_sources (name, url, kind, family, note) values
  ('ACER — scholarship tests',        'https://www.acer.org/aus/scholarship',        'official', 'edutest', 'reasoning and reading, official samples'),
  ('BBC Bitesize — English',          'https://www.bbc.co.uk/bitesize/subjects/zv48q6f', 'popular', 'general', 'reading and writing skills, free'),
  ('ReadTheory — reading comprehension', 'https://readtheory.org/',                  'popular', 'general', 'free graded reading passages'),
  ('AssessmentDay — verbal reasoning', 'https://www.assessmentday.co.uk/verbal-reasoning-test.htm', 'popular', 'general', 'free verbal reasoning samples'),
  ('Twinkl — reasoning practice',     'https://www.twinkl.com.au/',                  'popular', 'general', 'verbal and non-verbal reasoning worksheets')
on conflict do nothing;

-- one strand per non-maths section topic, per exam family that has that section
do $$
declare r record; v_n int; v_next int;
begin
  for r in
    select f.family, sec->>'part' as part, t as topic
    from (values ('aas'),('edutest'),('icas'),('amc')) f(family)
    join lateral (
      select * from exam_specs() e where lower(e->>'family') = f.family
    ) e on true
    , lateral json_array_elements(e->'sections') sec
    , lateral json_array_elements_text(coalesce(sec->'topics','[]'::json)) t
    where lower(sec->>'part') not like '%mathemat%'
      and lower(sec->>'part') not like '%whole paper%'
      and lower(sec->>'part') not like '%each contest%'
      and lower(sec->>'part') not like '%general reasoning%'
  loop
    -- general reasoning keeps one strand per reasoning type below
    if not exists (
      select 1 from chapters
      where source = r.family and subject <> 'maths'
        and title = r.part || ' · ' || r.topic
    ) then
      select coalesce(max(n), 0) + 1 into v_next from chapters;
      insert into chapters (n, title, source, subject, practice)
      values (v_next, r.part || ' · ' || r.topic, r.family,
              case when lower(r.part) like '%written%' then 'writing'
                   when lower(r.part) like '%reading%' then 'reading'
                   else 'reasoning' end, 0);
    end if;
  end loop;

  -- general reasoning splits into its four kinds
  for r in select unnest(array['Verbal reasoning','Mathematical reasoning','Figural reasoning','Spatial reasoning']) as topic
  loop
    if not exists (select 1 from chapters where source = 'aas' and subject <> 'maths'
                    and title = 'General reasoning · ' || r.topic) then
      select coalesce(max(n), 0) + 1 into v_next from chapters;
      insert into chapters (n, title, source, subject, practice)
      values (v_next, 'General reasoning · ' || r.topic, 'aas', 'reasoning', 0);
    end if;
  end loop;
end $$;

select subject, count(*) from chapters group by 1;
