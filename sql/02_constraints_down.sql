-- =====================================================================
-- ০২ (উল্টো) — CHECK constraint সরানো
-- migration পেছনে নিলে (migrate dbschema zero) এটা চলে।
-- =====================================================================

ALTER TABLE harvests DROP CHECK chk_harvest_moisture;
ALTER TABLE harvests DROP CHECK chk_harvest_kg_positive;
ALTER TABLE harvests DROP CHECK chk_harvest_kg_sane;

ALTER TABLE hives DROP CHECK chk_hive_filled_within_frames;
ALTER TABLE hives DROP CHECK chk_hive_frames_range;
ALTER TABLE hives DROP CHECK chk_hive_state;

ALTER TABLE queens DROP CHECK chk_queen_dates;

ALTER TABLE inspections DROP CHECK chk_inspection_frames_sane;
ALTER TABLE inspections DROP CHECK chk_inspection_state;
ALTER TABLE inspection_diseases DROP CHECK chk_inspection_disease_severity;

ALTER TABLE farms DROP CHECK chk_farm_status;
ALTER TABLE farms DROP CHECK chk_farm_type;
ALTER TABLE farms DROP CHECK chk_farm_point_in_bd;
ALTER TABLE districts DROP CHECK chk_district_point_in_bd;

ALTER TABLE users DROP CHECK chk_user_phone_format;
ALTER TABLE users DROP CHECK chk_user_role;
ALTER TABLE users DROP CHECK chk_user_has_contact;
ALTER TABLE farmer_profiles DROP CHECK chk_farmer_rating_range;
ALTER TABLE farmer_profiles DROP CHECK chk_farmer_experience_sane;
ALTER TABLE farmer_profiles DROP CHECK chk_farmer_type;

ALTER TABLE months DROP CHECK chk_month_range;
ALTER TABLE diseases DROP CHECK chk_disease_risk;
ALTER TABLE disease_steps DROP CHECK chk_disease_step_kind;
ALTER TABLE disease_steps DROP CHECK chk_disease_step_no;

ALTER TABLE notifications DROP CHECK chk_notification_kind;
ALTER TABLE posts DROP CHECK chk_post_category;
ALTER TABLE hive_events DROP CHECK chk_hive_event_kind;
ALTER TABLE audit_log DROP CHECK chk_audit_action;
