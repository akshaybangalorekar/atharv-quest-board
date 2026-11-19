-- ============================================================================
-- 118_date_watch.sql
-- Exam dates are checked against the providers' own pages, and any change is
-- logged so the app can put a banner in front of the parent.
-- Run after 117. Safe to re-run.
-- ============================================================================

create table if not exists date_sources (
  exam  text primary key,
  url   text not null,
  note  text
);

insert into date_sources (exam, url, note) values
  ('AAS numerical reasoning',      'https://www.academicassessment.com.au/', 'AAS — schools set their own dates'),
  ('Edutest numerical reasoning',  'https://www.edutest.com.au/',            'Edutest — test dates by school'),
  ('ELMS',                          'https://www.edutest.com.au/',            'McKinnon sits Edutest mathematics'),
  ('APSMO Division J',             'https://apsmo.edu.au/',                  'APSMO — contest rounds'),
  ('AMC Upper Primary',            'https://www.amt.edu.au/amc',             'AMT — AMC dates'),
  ('ICAS Maths',                   'https://www.icasassessments.com/',       'ICAS — sitting windows')
on conflict (exam) do nothing;

create table if not exists date_checks (
  id          bigserial primary key,
  student_id  uuid not null,
  checked_at  timestamptz not null default now(),
  changes     jsonb not null default '[]'::json,
  seen        boolean not null default false
);

create index if not exists date_checks_student on date_checks (student_id, checked_at desc);

-- has it been long enough to look again?
create or replace function date_check_due(p_hours int default 12)
returns boolean
language sql security definer set search_path = public as $$
  select coalesce(
    (select max(checked_at) from date_checks
      where student_id = coalesce(viewing_student(), auth.uid())) < now() - make_interval(hours => p_hours),
    true);
$$;

-- what the banner should say, if anything
create or replace function pending_date_changes()
returns json
language sql security definer set search_path = public as $$
  select coalesce((select json_agg(row_to_json(c) order by c.checked_at desc) from (
    select id, checked_at, changes
    from date_checks
    where student_id = coalesce(viewing_student(), auth.uid())
      and seen = false and changes <> '[]'::jsonb
    order by checked_at desc limit 3) c), '[]'::json);
$$;

create or replace function dismiss_date_changes()
returns void
language sql security definer set search_path = public as $$
  update date_checks set seen = true
   where student_id = coalesce(viewing_student(), auth.uid()) and seen = false;
$$;

grant execute on function date_check_due(int) to authenticated;
grant execute on function pending_date_changes() to authenticated;
grant execute on function dismiss_date_changes() to authenticated;
