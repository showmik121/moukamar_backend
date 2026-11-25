-- =====================================================================
-- ০৩ — VIEW
--
-- চালান:  .\db.ps1 -File queries\03_views.sql
--
-- ভিউ কী: একটা সংরক্ষিত SELECT। টেবিলের মতো ব্যবহার করা যায়
-- (WHERE, JOIN, GROUP BY সব চলে), কিন্তু ডাটা আলাদা করে জমা থাকে না —
-- প্রতিবার পড়ার সময় মূল টেবিল থেকে হিসেব হয়। তাই সংখ্যা কখনো
-- পুরনো হয় না।
-- =====================================================================

SELECT '===== ১. আমাদের ভিউগুলো =====' AS ধাপ;

SELECT v.TABLE_NAME AS `ভিউ`,
       (SELECT COUNT(*) FROM information_schema.COLUMNS c
         WHERE c.TABLE_SCHEMA = v.TABLE_SCHEMA
           AND c.TABLE_NAME = v.TABLE_NAME)  AS `কলাম`,
       v.IS_UPDATABLE                        AS `লেখা যায়`
  FROM information_schema.VIEWS v
 WHERE v.TABLE_SCHEMA = DATABASE()
 ORDER BY v.TABLE_NAME;

-- ভিউ ডাটা জমায় না — তাই TABLES-এ এর কোনো আকার নেই
SELECT TABLE_NAME AS `নাম`, TABLE_TYPE AS `ধরন`, TABLE_ROWS AS `জমানো সারি`
  FROM information_schema.TABLES
 WHERE TABLE_SCHEMA = DATABASE()
   AND TABLE_NAME IN ('hives', 'v_hive_status')
 ORDER BY TABLE_TYPE;


SELECT '===== ২. v_hive_status — প্রতিটা বাক্সের চলতি অবস্থা =====' AS ধাপ;
-- hives টেবিলে রানীর কোনো কলাম নেই, শেষ পরিদর্শনের কলামও নেই।
-- সবই অন্য টেবিল থেকে জোড়া লাগিয়ে ভিউ বানিয়ে দিচ্ছে।
SELECT code AS কোড, state AS অবস্থা, queen AS রানী,
       last_inspection AS `শেষ পরিদর্শন`,
       days_since_inspection AS `কত দিন`,
       IF(inspection_overdue, 'হ্যাঁ', 'না') AS `বাকি?`,
       total_honey_kg AS `মোট মধু`
  FROM v_hive_status
 ORDER BY code;

-- ভিউটা নিজে টেবিলের মতো — WHERE, ORDER BY, LIMIT সব চলে
SELECT code AS কোড, days_since_inspection AS `কত দিন`
  FROM v_hive_status
 WHERE inspection_overdue = 1
 ORDER BY days_since_inspection DESC;


SELECT '===== ৩. ভিউয়ের উপর ভিউ =====' AS ধাপ;
-- v_overdue_hives নিজে কোনো হিসাব করে না, v_hive_status থেকে ছেঁকে নেয়
SHOW CREATE VIEW v_overdue_hives;

SELECT code AS কোড, farm_name AS খামার, days_since_inspection AS `কত দিন`
  FROM v_overdue_hives;


SELECT '===== ৪. ভিউয়ের উপর aggregate =====' AS ধাপ;
-- ভিউকে টেবিলের মতো ধরে GROUP BY করা যায়
SELECT state                       AS অবস্থা,
       COUNT(*)                    AS `কত বাক্স`,
       ROUND(AVG(days_since_inspection), 1) AS `গড় দিন`,
       SUM(total_honey_kg)         AS `মোট মধু`
  FROM v_hive_status
 GROUP BY state
 ORDER BY `কত বাক্স` DESC;


SELECT '===== ৫. ভিউ আর টেবিল একসাথে JOIN =====' AS ধাপ;
SELECT v.code      AS বাক্স,
       u.name      AS মালিক,
       up.name     AS উপজেলা,
       v.queen     AS রানী
  FROM v_hive_status v
  JOIN users u     ON u.id = v.owner_id
  JOIN farms f     ON f.id = v.farm_id
  JOIN upazilas up ON up.id = f.upazila_id
 ORDER BY v.code;


SELECT '===== ৬. v_farm_summary — খামার অনুযায়ী =====' AS ধাপ;
SELECT farm_name AS খামার, district AS জেলা, upazila AS উপজেলা,
       hive_count AS `বাক্স`, strong_count AS সবল,
       weak_count AS দুর্বল, queenless_count AS রানীহীন,
       total_honey_kg AS মধু, flora AS ফুল
  FROM v_farm_summary;


SELECT '===== ৭. v_farmer_directory — খামারি তালিকা ও ম্যাপ =====' AS ধাপ;
SELECT name AS নাম, district AS জেলা, upazila AS উপজেলা,
       hive_count AS `বাক্স`, active_hives AS সক্রিয়,
       total_honey_kg AS মধু, experience_years AS অভিজ্ঞতা,
       rating AS রেটিং, flora AS ফুল, lat, lng
  FROM v_farmer_directory;

-- খামারের নিজের coordinate না থাকলে জেলার coordinate বসে (COALESCE)
SELECT '-- জেলার coordinate কাজে লাগছে কি --' AS নোট;
SELECT v.name AS খামারি, v.lat, v.lng,
       d.lat AS `জেলার lat`, d.lng AS `জেলার lng`,
       IF(v.lat = d.lat, 'জেলা থেকে', 'খামার থেকে') AS `কোথা থেকে`
  FROM v_farmer_directory v
  JOIN upazilas u  ON u.name = v.upazila
  JOIN districts d ON d.id = u.district_id AND d.name = v.district;


SELECT '===== ৮. v_monthly_honey — মাসভিত্তিক =====' AS ধাপ;
SELECT yr AS বছর, month_name AS মাস, harvest_count AS `কতবার`,
       total_kg AS `মোট কেজি`, avg_kg AS `গড়`, avg_moisture AS `গড় আর্দ্রতা`
  FROM v_monthly_honey
 ORDER BY yr, mn;


SELECT '===== ৯. v_disease_symptoms — M:N এক সারিতে =====' AS ধাপ;
SELECT disease AS রোগ, risk AS ঝুঁকি, symptom_count AS `লক্ষণ`,
       symptom_codes AS কোড, treat_steps AS `চিকিৎসার ধাপ`
  FROM v_disease_symptoms
 ORDER BY FIELD(risk, 'high', 'mid', 'low'), disease;


SELECT '===== ১০. ভিউ ডাটা জমায় না — সাথে সাথে বদলায় =====' AS ধাপ;
-- এটাই ভিউয়ের আসল কথা। নিচে একটা পরিদর্শন যোগ করা হচ্ছে; ভিউ
-- সাথে সাথে নতুন সংখ্যা দেখাবে, কারণ ও প্রতিবার হিসেব করে।

START TRANSACTION;

SELECT '--- আগে (MK-003 এর পরিদর্শন ১৬ দিন আগে, তাই বাকি) ---' AS নোট;
SELECT code AS কোড, days_since_inspection AS `কত দিন`,
       IF(inspection_overdue, 'হ্যাঁ', 'না') AS `বাকি?`
  FROM v_hive_status WHERE code = 'MK-003';

-- আজকের তারিখে একটা পরিদর্শন যোগ
INSERT INTO inspections (hive_id, inspector_id, inspect_date, frames_filled,
                         state, queen_seen, eggs_seen, notes, created_at)
SELECT id, NULL, CURDATE(), 3, 'দুর্বল', 1, 1, 'ভিউয়ের demo', NOW()
  FROM hives WHERE code = 'MK-003';

SELECT '--- পরে (ভিউ নিজে থেকেই নতুন সংখ্যা দেখাচ্ছে) ---' AS নোট;
SELECT code AS কোড, days_since_inspection AS `কত দিন`,
       IF(inspection_overdue, 'হ্যাঁ', 'না') AS `বাকি?`
  FROM v_hive_status WHERE code = 'MK-003';

-- ড্যাশবোর্ডের "বাকি পরিদর্শন"-ও সাথে সাথে কমে গেল
SELECT owner_name AS মালিক, hives_total AS `বাক্স`,
       overdue_inspections AS `বাকি পরিদর্শন`, honey_total_kg AS মধু
  FROM v_farmer_dashboard;

ROLLBACK;

SELECT '--- ROLLBACK-এর পর আবার আগের মতো ---' AS নোট;
SELECT code AS কোড, days_since_inspection AS `কত দিন`,
       IF(inspection_overdue, 'হ্যাঁ', 'না') AS `বাকি?`
  FROM v_hive_status WHERE code = 'MK-003';


SELECT '===== ১১. ভিউয়ের ভেতরের query দেখা =====' AS ধাপ;
SELECT TABLE_NAME AS ভিউ, VIEW_DEFINITION AS `ভেতরের query`
  FROM information_schema.VIEWS
 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'v_monthly_honey';
