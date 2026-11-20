-- 144: a smoke test over every key RPC, so "it all works" is a run, not a claim
create or replace function smoke_test()
returns json language plpgsql security definer set search_path = public as $$
declare items text[] := array[
  'select truth()', 'select coach_context()', 'select sync_view()', 'select ingest_progress()',
  'select training_status()', 'select question_status_counts()', 'select exam_pipeline()',
  'select print_rows(''olympiad'')', 'select question_sources(null)', 'select held_back_reasons()',
  'select credits_state()', 'select model_balance()', 'select usage_limits()', 'select recent_jobs(5)',
  'select papers_to_read()', 'select list_accounts()', 'select journey()', 'select exam_specs()',
  'select topic_readiness(''olympiad'')', 'select readiness_by_school()', 'select whats_new(''olympiad'')',
  'select timetable()', 'select strands_to_fill(3)', 'select authority_material(null)',
  'select exam_has_official(''edutest'')', 'select drain_token()', 'select students_with_queued()',
  'select may_call_model()', 'select spend_between(current_date - 7, current_date)',
  'select board_pending()', 'select due_reviews(5)', 'select family_freshness()', 'select library_line()',
  'select bank_line()', 'select current_coach_brief()', 'select progress_dashboard()',
  'select mock_due()', 'select placement_due()', 'select question_budget(1, 1)',
  'select child_work_status(null)', 'select search_docs(''fraction'', null, 2)',
  'select chapter_pack(1)', 'select exam_questions(''olympiad'')', 'select chapters_for_exam(''olympiad'')',
  'select sitting_plan()', 'select paper_objects(null)', 'select formula_board_view()',
  'select last_checkin()', 'select my_account()', 'select my_student_id()', 'select list_guardians()',
  'select list_training_sources()', 'select list_alert_recipients()', 'select pending_alerts()',
  'select pending_date_changes()', 'select parse_note()', 'select parse_progress()',
  'select recent_material(5)'
];
  it text; ok int := 0; bad text := '';
begin
  foreach it in array items loop
    begin execute it; ok := ok + 1;
    exception when others then bad := bad || it || ' → ' || SQLERRM || E'\n';
    end;
  end loop;
  return json_build_object('ran', ok, 'of', array_length(items, 1), 'failed', bad);
end $$;
grant execute on function smoke_test() to authenticated;
