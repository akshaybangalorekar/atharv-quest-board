-- ============================================================================
-- 119_exam_watch.sql
-- Watch everything about these exams — dates, format, sections, timings,
-- topic lists, and news — and keep a log the app can show and email out.
-- Run after 118. Safe to re-run.
-- ============================================================================

create table if not exists alerts (
  id          bigserial primary key,
  student_id  uuid not null,
  kind        text not null,               -- date | format | timing | topics | news
  exam        text,
  summary     text not null,
  detail      text,
  source      text,
  found_at    timestamptz not null default now(),
  seen        boolean not null default false,
  emailed_at  timestamptz
);

create index if not exists alerts_student on alerts (student_id, found_at desc);

create table if not exists alert_recipients (
  email      text primary key,
  added_at   timestamptz not null default now()
);

insert into alert_recipients (email) values
  ('pooja.bangalorekar@gmail.com')
on conflict (email) do nothing;

create or replace function pending_alerts()
returns json
language sql security definer set search_path = public as $$
  select coalesce((select json_agg(row_to_json(a) order by a.found_at desc) from (
    select id, kind, exam, summary, detail, source, found_at
    from alerts
    where student_id = coalesce(viewing_student(), auth.uid()) and seen = false
    order by found_at desc limit 10) a), '[]'::json);
$$;

create or replace function dismiss_alerts()
returns void
language sql security definer set search_path = public as $$
  update alerts set seen = true
   where student_id = coalesce(viewing_student(), auth.uid()) and seen = false;
$$;

create or replace function list_alert_recipients()
returns json
language plpgsql security definer set search_path = public as $$
begin
  if not is_parent() then raise exception 'only a parent can see this' using errcode = '42501'; end if;
  return coalesce((select json_agg(json_build_object('email', email, 'added_at', added_at) order by added_at)
                   from alert_recipients), '[]'::json);
end $$;

create or replace function add_alert_recipient(p_email text)
returns json
language plpgsql security definer set search_path = public as $$
begin
  if not is_parent() then raise exception 'only a parent can do this' using errcode = '42501'; end if;
  if p_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'that does not look like an email address' using errcode = '22023';
  end if;
  insert into alert_recipients (email) values (lower(btrim(p_email))) on conflict (email) do nothing;
  return list_alert_recipients();
end $$;

create or replace function remove_alert_recipient(p_email text)
returns json
language plpgsql security definer set search_path = public as $$
begin
  if not is_parent() then raise exception 'only a parent can do this' using errcode = '42501'; end if;
  delete from alert_recipients where email = lower(btrim(p_email));
  return list_alert_recipients();
end $$;

grant execute on function pending_alerts() to authenticated;
grant execute on function dismiss_alerts() to authenticated;
grant execute on function list_alert_recipients() to authenticated;
grant execute on function add_alert_recipient(text) to authenticated;
grant execute on function remove_alert_recipient(text) to authenticated;
