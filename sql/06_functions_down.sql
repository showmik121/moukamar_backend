-- =====================================================================
-- ০৬ (উল্টো) — FUNCTION সরানো
-- fn_hive_health_score অন্য দুটো function ডাকে, তাই আগে ওটা।
-- =====================================================================

DROP FUNCTION IF EXISTS fn_hive_health_score;
DROP FUNCTION IF EXISTS fn_kg_bn;
DROP FUNCTION IF EXISTS fn_queen_age_years;
DROP FUNCTION IF EXISTS fn_days_since_inspection;
DROP FUNCTION IF EXISTS fn_hive_honey_total;
DROP FUNCTION IF EXISTS fn_farm_honey_total;
DROP FUNCTION IF EXISTS fn_is_dearth_month;
DROP FUNCTION IF EXISTS fn_bn_digits;
