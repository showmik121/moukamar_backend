-- =====================================================================
-- ০৪ — FUNCTION ও PROCEDURE
--
-- চালান:  .\db.ps1 -Force -File queries\04_routines.sql
--
-- -Force লাগে, কারণ ৬ নম্বর ধাপে ইচ্ছে করে ভুল ডাটা পাঠানো হয় —
-- procedure সেগুলো SIGNAL দিয়ে আটকায় কিনা সেটাই দেখার জিনিস।
--
-- ফাইলের শেষে সব পরীক্ষার সারি মুছে দেওয়া হয়, তাই বারবার চালানো যায়।
--
-- খেয়াল রাখুন: এখানে ROLLBACK দিয়ে সব ফেরানো যায় না। কারণ
-- sp_move_hive, sp_new_queen ইত্যাদি নিজেরাই START TRANSACTION ...
-- COMMIT চালায়, আর MySQL-এ transaction-এর ভেতরে transaction হয় না —
-- ভেতরের START TRANSACTION বাইরের টাকে COMMIT করে দেয়। তাই পরিষ্কার
-- করতে হাতে DELETE করা হয়েছে (নিচে ১০ নম্বর ধাপ)।
-- =====================================================================

-- পরে পরিষ্কার করার জন্য শুরুর সময় ধরে রাখা
SET @t0 = NOW();


SELECT '===== ১. আমাদের function ও procedure =====' AS ধাপ;

SELECT ROUTINE_TYPE AS `ধরন`, ROUTINE_NAME AS `নাম`,
       IFNULL(DTD_IDENTIFIER, '—') AS `যা ফেরত দেয়`,
       (SELECT COUNT(*) FROM information_schema.PARAMETERS p
         WHERE p.SPECIFIC_SCHEMA = r.ROUTINE_SCHEMA
           AND p.SPECIFIC_NAME = r.ROUTINE_NAME) AS `প্যারামিটার`
  FROM information_schema.ROUTINES r
 WHERE ROUTINE_SCHEMA = DATABASE()
 ORDER BY ROUTINE_TYPE, ROUTINE_NAME;


SELECT '===== ২. FUNCTION — SELECT-এর ভেতরে কলামের মতো =====' AS ধাপ;
-- এটাই function-এর সুবিধা: যেকোনো query-তে বসিয়ে দেওয়া যায়
SELECT h.code                            AS বাক্স,
       h.state                           AS অবস্থা,
       fn_queen_age_years(h.id)          AS `রানীর বয়স`,
       fn_days_since_inspection(h.id)    AS `পরিদর্শনের দিন`,
       fn_kg_bn(fn_hive_honey_total(h.id)) AS `মোট মধু`,
       fn_hive_health_score(h.id)        AS `স্বাস্থ্য নম্বর`
  FROM hives h
 ORDER BY fn_hive_health_score(h.id) DESC;


SELECT '===== ৩. FUNCTION — WHERE ও ORDER BY-তেও চলে =====' AS ধাপ;
SELECT code AS বাক্স, fn_hive_health_score(id) AS নম্বর
  FROM hives
 WHERE fn_hive_health_score(id) < 50
 ORDER BY fn_hive_health_score(id);

-- রানী না থাকলে -১, তাই "রানীহীন" আলাদা করে বের করা যায়
SELECT code AS বাক্স, fn_queen_age_years(id) AS `রানীর বয়স`
  FROM hives
 WHERE fn_queen_age_years(id) = -1;

SELECT '-- বাংলা অঙ্কের function --' AS নোট;
SELECT fn_bn_digits('MK-014') AS `কোড`,
       fn_bn_digits(CAST(CURDATE() AS CHAR)) AS `আজকের তারিখ`,
       fn_kg_bn(1234.5) AS `পরিমাণ`;

SELECT '-- ফুলের ক্যালেন্ডারে কোন মাসে ফুল কম --' AS নোট;
SELECT m.name_bn AS মাস,
       IF(fn_is_dearth_month(m.month_no), 'ফুল কম', 'ফুল আছে') AS অবস্থা
  FROM months m ORDER BY m.month_no;


SELECT '===== ৪. PROCEDURE — OUT প্যারামিটার =====' AS ধাপ;
-- FUNCTION একটাই মান দেয়; procedure কয়েকটা OUT দিতে পারে
CALL sp_season_report(
    (SELECT id FROM users WHERE phone = '01712345678'),
    YEAR(CURDATE()),
    @total, @count, @hives, @best, @best_kg, @moisture);

SELECT fn_kg_bn(@total)  AS `মোট মধু`,
       @count            AS `কতবার সংগ্রহ`,
       @hives            AS `কত বাক্স থেকে`,
       @best             AS `সেরা বাক্স`,
       fn_kg_bn(@best_kg) AS `সেরা বাক্সের মধু`,
       @moisture         AS `গড় আর্দ্রতা`;


SELECT '===== ৫. sp_add_harvest — ঠিক তথ্য =====' AS ধাপ;
CALL sp_add_harvest('MK-005', CURDATE(), 9.25, 18.5, 'সরিষা',
                    (SELECT id FROM users WHERE phone = '01712345678'), @hid);
SELECT @hid AS `নতুন সংগ্রহের আইডি`,
       fn_kg_bn(fn_hive_honey_total((SELECT id FROM hives WHERE code = 'MK-005')))
         AS `MK-005 এর মোট মধু`;


SELECT '===== ৬. sp_add_harvest — ভুল তথ্য, procedure আটকায় =====' AS ধাপ;
-- আর্দ্রতা ৩০%-এর বেশি → SIGNAL SQLSTATE 45000
CALL sp_add_harvest('MK-005', CURDATE(), 5.00, 42.0, 'সরিষা', NULL, @hid);

-- পরিমাণ শূন্য
CALL sp_add_harvest('MK-005', CURDATE(), 0, 18.0, 'সরিষা', NULL, @hid);

-- ভবিষ্যতের তারিখ (CHECK constraint দিয়ে করা যায় না, procedure-এ করা হলো)
CALL sp_add_harvest('MK-005', DATE_ADD(CURDATE(), INTERVAL 5 DAY), 5.00, 18.0, 'সরিষা', NULL, @hid);

-- নেই এমন বাক্স
CALL sp_add_harvest('MK-999', CURDATE(), 5.00, 18.0, 'সরিষা', NULL, @hid);


SELECT '===== ৭. sp_notify_overdue_inspections — CURSOR =====' AS ধাপ;
-- সারি ধরে ধরে কাজ করতে CURSOR লাগে। v_overdue_hives ভিউয়ের প্রতিটা
-- সারির জন্য মালিককে একটা করে সতর্কতা লেখা হয়।
--
-- এই ধাপটা ৮ নম্বরের আগে রাখতে হয়েছে: ৮ নম্বরে MK-003-এর আজকের
-- পরিদর্শন লেখা হয়, তখন আর কোনো বাক্সের পরিদর্শন বাকি থাকে না।
SELECT code AS বাক্স, farm_name AS খামার, days_since_inspection AS `কত দিন`
  FROM v_overdue_hives;

CALL sp_notify_overdue_inspections(NULL, @sent);
SELECT @sent AS `কতটা সতর্কতা পাঠানো হলো`;

SELECT title AS শিরোনাম, body AS বিবরণ
  FROM notifications
 WHERE kind = 'inspection' AND created_at >= @t0
 ORDER BY id;


SELECT '===== ৮. sp_record_inspection — লুপ ও SAVEPOINT =====' AS ধাপ;
-- তিনটে রোগের কোড পাঠানো হচ্ছে, কিন্তু 'ভুলকোড' বলে কিছু নেই।
-- SAVEPOINT-এর কারণে শুধু ওটা বাদ যাবে, পরিদর্শন টিকে থাকবে।
CALL sp_record_inspection('MK-003', CURDATE(), 3, 'দুর্বল', 1, 0,
                          'varroa,ভুলকোড,waxmoth',
                          (SELECT id FROM users WHERE phone = '01712345678'),
                          @insp, @added);

SELECT @insp AS `পরিদর্শনের আইডি`,
       @added AS `কত রোগ যোগ হলো`,
       '৩টা কোড পাঠানো হয়েছিল, ১টা ভুল ছিল' AS নোট;

SELECT d.name AS `পাওয়া রোগ`, idis.severity AS মাত্রা
  FROM inspection_diseases idis
  JOIN diseases d ON d.id = idis.disease_id
 WHERE idis.inspection_id = @insp;

-- পরিদর্শন লেখার পর ভিউ সাথে সাথে বদলে গেছে
SELECT code AS বাক্স, days_since_inspection AS `কত দিন`,
       IF(inspection_overdue, 'হ্যাঁ', 'না') AS `বাকি?`
  FROM v_hive_status WHERE code = 'MK-003';

SELECT '-- ভরা ফ্রেম মোট ফ্রেমের বেশি দিলে আটকায় --' AS নোট;
CALL sp_record_inspection('MK-003', CURDATE(), 99, 'সবল', 1, 1, '',
                          NULL, @insp2, @added2);


SELECT '===== ৯. sp_new_queen — রানীহীন বাক্সে রানী =====' AS ধাপ;
SELECT code AS বাক্স, state AS অবস্থা, queen AS রানী
  FROM v_hive_status WHERE code = 'MK-009';

CALL sp_new_queen('MK-009', 'কৃষি অফিস', 'লাল',
                  (SELECT id FROM users WHERE phone = '01712345678'));

SELECT code AS বাক্স, state AS অবস্থা, queen AS রানী,
       queen_source AS উৎস, queen_color AS রং
  FROM v_hive_status WHERE code = 'MK-009';


SELECT '===== ১০. sp_move_hive — transaction ও SIGNAL =====' AS ধাপ;
-- পরীক্ষার জন্য একটা দ্বিতীয় খামার
INSERT INTO farms (owner_id, name, upazila_id, farm_type, status, created_at)
SELECT u.id, 'পরীক্ষা খামার ২', f.upazila_id, 'স্থায়ী', 'সক্রিয়', NOW()
  FROM users u JOIN farms f ON f.owner_id = u.id
 WHERE u.phone = '01712345678' LIMIT 1;
SET @farm2 = LAST_INSERT_ID();

SELECT code AS বাক্স, farm_name AS `আগের খামার` FROM v_hive_status WHERE code = 'MK-001';

CALL sp_move_hive('MK-001', @farm2, (SELECT id FROM users WHERE phone = '01712345678'));

SELECT code AS বাক্স, farm_name AS `এখনকার খামার` FROM v_hive_status WHERE code = 'MK-001';

SELECT '-- বাক্সের ইতিহাসে ঘটনা লেখা হয়েছে --' AS নোট;
SELECT event_date AS তারিখ, kind AS ধরন, note AS বিবরণ
  FROM hive_events
 WHERE hive_id = (SELECT id FROM hives WHERE code = 'MK-001')
 ORDER BY id DESC LIMIT 3;

SELECT '-- একই খামারে আবার সরাতে গেলে আটকায় --' AS নোট;
CALL sp_move_hive('MK-001', @farm2, NULL);

SELECT '-- নেই এমন খামারে সরাতে গেলে আটকায় --' AS নোট;
CALL sp_move_hive('MK-001', 999999, NULL);

SELECT '-- অন্য খামারির খামারে সরাতে গেলে আটকায় --' AS নোট;
-- কৃষকের নামে একটা খামার বানিয়ে চেষ্টা
INSERT INTO farms (owner_id, name, upazila_id, farm_type, status, created_at)
SELECT u.id, 'অন্যের খামার', (SELECT upazila_id FROM farms LIMIT 1),
       'স্থায়ী', 'সক্রিয়', NOW()
  FROM users u WHERE u.phone = '01812345678' LIMIT 1;
SET @farm3 = LAST_INSERT_ID();
CALL sp_move_hive('MK-001', @farm3, NULL);

-- বাক্সটা আবার আগের খামারে ফেরানো
CALL sp_move_hive('MK-001',
                  (SELECT id FROM farms WHERE name = 'চর ঘাটিনা খামার'),
                  (SELECT id FROM users WHERE phone = '01712345678'));


SELECT '===== ১১. procedure-এর ভেতরের কোড দেখা =====' AS ধাপ;
SHOW CREATE PROCEDURE sp_move_hive;


-- =====================================================================
-- ১২. পরিষ্কার — পরীক্ষার সব সারি মুছে ফেলা
-- =====================================================================
SELECT '===== ১২. পরিষ্কার করা হচ্ছে =====' AS ধাপ;

DELETE FROM notifications WHERE created_at >= @t0;
DELETE FROM hive_events   WHERE created_at >= @t0;
DELETE FROM harvests      WHERE created_at >= @t0;
DELETE FROM inspections   WHERE created_at >= @t0;   -- inspection_diseases CASCADE-এ যাবে
DELETE FROM queens        WHERE installed_on = CURDATE() AND source = 'কৃষি অফিস';

-- MK-009 আবার রানীহীন (sp_new_queen ওটাকে 'দুর্বল' করেছিল)
UPDATE queens SET removed_on = NULL
 WHERE hive_id = (SELECT id FROM hives WHERE code = 'MK-009')
   AND removed_on = CURDATE();
DELETE FROM queens
 WHERE hive_id = (SELECT id FROM hives WHERE code = 'MK-009');
UPDATE hives SET state = 'রানীহীন', filled = 0 WHERE code = 'MK-009';
UPDATE hives SET state = 'দুর্বল', filled = 2 WHERE code = 'MK-003';

DELETE FROM farms WHERE name IN ('পরীক্ষা খামার ২', 'অন্যের খামার');

SELECT '===== শেষ — ডাটাবেজ আগের অবস্থায় =====' AS ধাপ;
SELECT (SELECT COUNT(*) FROM hives)         AS `বাক্স`,
       (SELECT COUNT(*) FROM farms)         AS `খামার`,
       (SELECT COUNT(*) FROM harvests)      AS `মধু সংগ্রহ`,
       (SELECT COUNT(*) FROM inspections)   AS `পরিদর্শন`,
       (SELECT COUNT(*) FROM notifications) AS `সতর্কতা`,
       (SELECT COUNT(*) FROM queens)        AS `রানী`;
