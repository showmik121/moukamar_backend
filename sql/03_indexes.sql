-- =====================================================================
-- ০৩ — INDEX
--
-- Django migration প্রতিটা FOREIGN KEY আর UNIQUE-এর জন্য index বানিয়ে
-- দেয়, আর model-এ লেখা Meta.indexes-গুলোও। এই ফাইলে শুধু সেগুলো আছে
-- যেগুলো ORM থেকে বলা যায় না বা যেগুলো নির্দিষ্ট query-র জন্য দরকার:
--   • FULLTEXT index (ORM-এ নেই)
--   • covering index (query-র সব কলাম index-এর ভেতরেই, টেবিল পড়তে হয় না)
--   • composite index যেগুলো আলাদা আলাদা index-এর চেয়ে ভালো
--
-- চালান:  .\db.ps1 -File sql\03_indexes.sql
-- EXPLAIN দিয়ে আগে-পরের তুলনা:  .\db.ps1 -File queries\02_indexes.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- ১. FULLTEXT — রোগ ও লক্ষণ খোঁজা (diseases.html)
-- ---------------------------------------------------------------------
-- LIKE '%ডানা%' দিয়ে খুঁজলে index কাজে আসে না (শুরুতে % থাকলে MySQL
-- পুরো টেবিল পড়ে)। FULLTEXT index শব্দ ধরে খোঁজে, তাই
-- MATCH ... AGAINST দিয়ে index ব্যবহার হয়।
CREATE FULLTEXT INDEX ft_symptom_name ON symptoms (name);

CREATE FULLTEXT INDEX ft_disease_search ON diseases (name, kind);

CREATE FULLTEXT INDEX ft_disease_step_text ON disease_steps (text);

-- ---------------------------------------------------------------------
-- ২. composite — "এই উপজেলার খামারিরা"
-- ---------------------------------------------------------------------
-- কৃষক স্প্রে নোটিশ দিলে এই query চলে:
--   WHERE role = 'farmer' AND upazila_id = ? AND is_active = 1
-- Django আলাদা করে role আর upazila_id-তে index বানিয়েছে। MySQL তখন
-- একটাই বেছে নেয়, বাকিটা সারি পড়ে মেলায়। composite index তিনটে শর্ত
-- একসাথে মেলাতে পারে।
-- (ix_user_role রয়ে গেল — ওটা এখন এই index-এর prefix, তাই বাড়তি।
--  Django ওটা নিজে বানিয়েছে, তাই হাতে মুছলে ORM-এর হিসাব আলাদা হয়ে
--  যাবে — সেজন্য রেখে দেওয়া হলো।)
CREATE INDEX ix_user_role_upazila_active ON users (role, upazila_id, is_active);

-- ---------------------------------------------------------------------
-- ৩. covering index — বাক্সপ্রতি মোট মধু
-- ---------------------------------------------------------------------
-- SELECT hive_id, SUM(kg) FROM harvests GROUP BY hive_id
-- এই query-র দরকারি কলাম দুটোই index-এ থাকলে MySQL টেবিলের সারি
-- একবারও পড়ে না — EXPLAIN-এ Extra কলামে "Using index" দেখা যায়।
CREATE INDEX ix_harvest_hive_kg ON harvests (hive_id, harvest_date, kg);

-- ---------------------------------------------------------------------
-- ৪. অপঠিত সতর্কতা, নতুনটা আগে
-- ---------------------------------------------------------------------
-- WHERE recipient_id = ? AND unread = 1 ORDER BY created_at DESC
-- created_at index-এ থাকলে ORDER BY-র জন্য আলাদা sort লাগে না।
CREATE INDEX ix_notif_unread_recent ON notifications (recipient_id, unread, created_at);

-- ---------------------------------------------------------------------
-- ৫. খামারির সক্রিয় খামার
-- ---------------------------------------------------------------------
CREATE INDEX ix_farm_owner_status ON farms (owner_id, status);

-- ---------------------------------------------------------------------
-- যেগুলো আলাদা করে বানানোর দরকার নেই
-- ---------------------------------------------------------------------
-- • inspections (hive_id, inspect_date) — uq_one_inspection_per_day
--   UNIQUE constraint-টাই index হিসেবে কাজ করে, তাই আলাদা index বাড়তি।
-- • প্রতিটা FOREIGN KEY-র কলামে MySQL নিজে index বানায় (InnoDB-র
--   শর্ত), তাই farm_id, hive_id, owner_id ইত্যাদিতে আগেই index আছে।
-- • districts.name আর hives.code UNIQUE, তাই ওগুলোতেও index আছে।

-- ---- যাচাই ----
SELECT TABLE_NAME                                       AS `টেবিল`,
       INDEX_NAME                                       AS `ইনডেক্স`,
       GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX)  AS `কলাম`,
       INDEX_TYPE                                       AS `ধরন`
  FROM information_schema.STATISTICS
 WHERE TABLE_SCHEMA = DATABASE()
   AND (INDEX_NAME LIKE 'ft_%' OR INDEX_NAME LIKE 'ix_%')
 GROUP BY TABLE_NAME, INDEX_NAME, INDEX_TYPE
 ORDER BY TABLE_NAME, INDEX_NAME;
