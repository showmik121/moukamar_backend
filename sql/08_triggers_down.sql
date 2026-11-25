-- =====================================================================
-- ০৮ (উল্টো) — TRIGGER সরানো
--
-- মনে রাখবেন: এগুলো সরালে স্প্রে নোটিশ থেকে খামারিদের সতর্কতা আর
-- posts.upvote_count-এর গণনা বন্ধ হয়ে যাবে — কাজগুলো এখন শুধু এই
-- trigger গুলোই করে, Python-এ আর কোনো কোড নেই (ইচ্ছাকৃত, যাতে একই
-- নিয়ম দুই জায়গায় না থাকে)।
-- =====================================================================

DROP TRIGGER IF EXISTS trg_spray_alert_fanout;
DROP TRIGGER IF EXISTS trg_post_vote_after_insert;
DROP TRIGGER IF EXISTS trg_post_vote_after_delete;
DROP TRIGGER IF EXISTS trg_inspection_disease_notify;
DROP TRIGGER IF EXISTS trg_harvest_before_insert;
DROP TRIGGER IF EXISTS trg_inspection_before_insert;
DROP TRIGGER IF EXISTS trg_queen_before_insert;
DROP TRIGGER IF EXISTS trg_queen_after_insert;
DROP TRIGGER IF EXISTS trg_hive_after_update;
DROP TRIGGER IF EXISTS trg_hive_after_delete;
DROP TRIGGER IF EXISTS trg_harvest_after_update;
DROP TRIGGER IF EXISTS trg_harvest_after_delete;
