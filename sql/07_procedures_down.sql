-- =====================================================================
-- ০৭ (উল্টো) — PROCEDURE সরানো
-- sp_set_fk_action এখানে নেই — ওটা sql/04-এর, ওখানেই মুছবে।
-- =====================================================================

DROP PROCEDURE IF EXISTS sp_move_hive;
DROP PROCEDURE IF EXISTS sp_new_queen;
DROP PROCEDURE IF EXISTS sp_record_inspection;
DROP PROCEDURE IF EXISTS sp_notify_overdue_inspections;
DROP PROCEDURE IF EXISTS sp_season_report;
DROP PROCEDURE IF EXISTS sp_add_harvest;
