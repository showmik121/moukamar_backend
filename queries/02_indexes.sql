-- =====================================================================
-- ০২ — INDEX ও EXPLAIN
--
-- চালান:  .\db.ps1 -File queries\02_indexes.sql
--
-- EXPLAIN পড়ার নিয়ম:
--   type = ALL    → পুরো টেবিল পড়ছে (সবচেয়ে খারাপ)
--   type = ref    → index দিয়ে সারি খুঁজছে (ভালো)
--   type = const  → একটাই সারি, সরাসরি (সেরা)
--   key           → কোন index ব্যবহার হচ্ছে
--   rows          → কত সারি পড়তে হবে বলে MySQL ভাবছে
--   Extra "Using index" → উত্তরের সব কলাম index-এই আছে, টেবিল
--                         পড়তেই হচ্ছে না (covering index)
--   Extra "Using filesort" → ORDER BY-র জন্য আলাদা করে সাজাতে হচ্ছে
-- =====================================================================

SELECT '===== ১. আমাদের টেবিলের index তালিকা =====' AS ধাপ;

SELECT TABLE_NAME                                      AS `টেবিল`,
       INDEX_NAME                                      AS `ইনডেক্স`,
       GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS `কলাম`,
       INDEX_TYPE                                      AS `ধরন`,
       IF(NON_UNIQUE = 0, 'হ্যাঁ', '-')                AS `UNIQUE`
  FROM information_schema.STATISTICS
 WHERE TABLE_SCHEMA = DATABASE()
   AND TABLE_NAME IN ('users', 'farms', 'hives', 'harvests', 'inspections',
                      'notifications', 'symptoms', 'diseases')
 GROUP BY TABLE_NAME, INDEX_NAME, INDEX_TYPE, NON_UNIQUE
 ORDER BY TABLE_NAME, INDEX_NAME;


SELECT '===== ২. FULLTEXT বনাম LIKE =====' AS ধাপ;

-- LIKE '%...%' — শুরুতে % থাকায় index কাজে আসে না, পুরো টেবিল পড়তে হয়
EXPLAIN SELECT code, name FROM symptoms WHERE name LIKE '%ডানা%';

-- MATCH ... AGAINST — ft_symptom_name index ব্যবহার হয় (type = fulltext)
EXPLAIN SELECT code, name FROM symptoms
 WHERE MATCH(name) AGAINST('ডানা' IN NATURAL LANGUAGE MODE);

-- ফল দুটোই এক, কিন্তু পথ আলাদা
SELECT code AS কোড, name AS লক্ষণ FROM symptoms
 WHERE MATCH(name) AGAINST('ডানা' IN NATURAL LANGUAGE MODE);

-- লক্ষণ বা চিকিৎসার লেখায় শব্দ খোঁজা (diseases.html-এর খোঁজার ঘর)
SELECT d.name AS রোগ, ds.kind AS ধরন, ds.text AS লেখা
  FROM disease_steps ds
  JOIN diseases d ON d.id = ds.disease_id
 WHERE MATCH(ds.text) AGAINST('লার্ভা' IN NATURAL LANGUAGE MODE);


SELECT '===== ৩. composite index — এই উপজেলার খামারিরা =====' AS ধাপ;

-- কৃষক স্প্রে নোটিশ দিলে ঠিক এই query চলে
EXPLAIN SELECT id, name FROM users
 WHERE role = 'farmer'
   AND upazila_id = (SELECT id FROM upazilas WHERE name = 'উল্লাপাড়া' LIMIT 1)
   AND is_active = 1;

-- একই query, কিন্তু composite index ব্যবহার করতে না দিলে
EXPLAIN SELECT id, name FROM users IGNORE INDEX (ix_user_role_upazila_active)
 WHERE role = 'farmer'
   AND upazila_id = (SELECT id FROM upazilas WHERE name = 'উল্লাপাড়া' LIMIT 1)
   AND is_active = 1;


SELECT '===== ৪. covering index — বাক্সপ্রতি মোট মধু =====' AS ধাপ;

-- hive_id আর kg দুটোই ix_harvest_hive_kg-এর ভেতরে, তাই Extra-তে
-- "Using index" আসা উচিত — টেবিলের সারি একবারও পড়তে হয় না
EXPLAIN SELECT hive_id, SUM(kg) FROM harvests GROUP BY hive_id;


SELECT '===== ৫. ছোট টেবিলে EXPLAIN বিভ্রান্ত করে =====' AS ধাপ;
-- আমাদের টেবিলে এখন মাত্র কয়েকটা সারি। এত ছোট টেবিলে index দিয়ে
-- খোঁজার চেয়ে পুরোটা পড়াই সস্তা, তাই MySQL ইচ্ছে করেই type = ALL
-- বেছে নেয় — index খারাপ বলে নয়।
-- আসল পার্থক্য দেখতে নিচে ৫০,০০০ সারির একটা টেবিল বানানো হচ্ছে।
SELECT (SELECT COUNT(*) FROM users)    AS `ব্যবহারকারী`,
       (SELECT COUNT(*) FROM harvests) AS `মধু সংগ্রহ`,
       (SELECT COUNT(*) FROM upazilas) AS `উপজেলা`;


SELECT '===== ৬. ৫০,০০০ সারি — index-এর আগে ও পরে =====' AS ধাপ;

DROP TABLE IF EXISTS demo_index_test;

CREATE TABLE demo_index_test (
    id           INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    hive_no      INT          NOT NULL,
    harvest_date DATE         NOT NULL,
    kg           DECIMAL(7,2) NOT NULL
) ENGINE = InnoDB;

-- recursive CTE দিয়ে সারি বানানো — কোনো লুপ বা স্ক্রিপ্ট ছাড়াই
-- (ডিফল্ট সীমা ১০০০, তাই আগে বাড়িয়ে নিতে হয়)
SET SESSION cte_max_recursion_depth = 100000;

INSERT INTO demo_index_test (hive_no, harvest_date, kg)
WITH RECURSIVE seq (n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 50000
)
SELECT (n % 500) + 1,
       DATE_SUB(CURDATE(), INTERVAL (n % 365) DAY),
       ROUND(5 + RAND() * 20, 2)
  FROM seq;

SELECT COUNT(*) AS `তৈরি হওয়া সারি` FROM demo_index_test;

ANALYZE TABLE demo_index_test;

SELECT '--- index ছাড়া ---' AS ধাপ;
EXPLAIN SELECT SUM(kg) FROM demo_index_test WHERE hive_no = 42;
EXPLAIN ANALYZE SELECT SUM(kg) FROM demo_index_test WHERE hive_no = 42;

CREATE INDEX ix_demo_hive_kg ON demo_index_test (hive_no, kg);
ANALYZE TABLE demo_index_test;

SELECT '--- covering index বসানোর পর ---' AS ধাপ;
EXPLAIN SELECT SUM(kg) FROM demo_index_test WHERE hive_no = 42;
EXPLAIN ANALYZE SELECT SUM(kg) FROM demo_index_test WHERE hive_no = 42;

SELECT '--- তারিখের পরিসর, index ছাড়া বনাম সহ ---' AS ধাপ;
EXPLAIN SELECT COUNT(*) FROM demo_index_test
 WHERE harvest_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY);

CREATE INDEX ix_demo_date ON demo_index_test (harvest_date);
ANALYZE TABLE demo_index_test;
EXPLAIN SELECT COUNT(*) FROM demo_index_test
 WHERE harvest_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY);

-- পরীক্ষার টেবিল রেখে দেওয়ার দরকার নেই
DROP TABLE demo_index_test;

SELECT '===== শেষ — demo টেবিল মুছে ফেলা হয়েছে =====' AS ধাপ;
