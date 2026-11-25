-- =====================================================================
-- ০১ — CHECK constraint, FOREIGN KEY ও UNIQUE কাজ করছে কিনা দেখানো
--
-- চালান:  .\db.ps1 -Force -File queries\01_constraints.sql
--
-- -Force লাগে, কারণ এই ফাইলের অর্ধেক statement **ভুল করে** লেখা —
-- ডাটাবেজ সেগুলো আটকায় কিনা সেটাই দেখার জিনিস। -Force ছাড়া প্রথম
-- ভুলেই mysql থেমে যাবে।
--
-- প্রতিটা ব্লকে: আগে ভুল চেষ্টা (ERROR আসা উচিত), তারপর সঠিকটা।
-- কিছুই স্থায়ীভাবে ঢোকে না — শেষে ROLLBACK।
-- =====================================================================

START TRANSACTION;

SELECT '===== ১. আর্দ্রতা ৩০%-এর বেশি মধু =====' AS ধাপ;
-- hive.html এটা আটকায়। কিন্তু অ্যাপ বাইপাস করে সরাসরি SQL দিলে?
-- chk_harvest_moisture আটকাবে → ERROR 3819
INSERT INTO harvests (hive_id, harvest_date, kg, moisture, notes, created_at)
VALUES ((SELECT id FROM hives WHERE code = 'MK-001'), CURDATE(), 10.00, 42.0, 'ভুল আর্দ্রতা', NOW());

-- ৩০%-এর নিচে হলে ঢুকবে
INSERT INTO harvests (hive_id, harvest_date, kg, moisture, notes, created_at)
VALUES ((SELECT id FROM hives WHERE code = 'MK-001'), CURDATE(), 10.00, 18.5, 'ঠিক আর্দ্রতা', NOW());
SELECT ROW_COUNT() AS `ঢুকেছে`;


SELECT '===== ২. শূন্য বা ঋণাত্মক পরিমাণ মধু =====' AS ধাপ;
-- chk_harvest_kg_positive
-- (notes কলামটা NOT NULL আর default নেই, তাই STRICT mode-এ সব INSERT-এ
--  দিতে হয় — নাহলে CHECK-এর আগেই অন্য ভুল দেখাবে)
INSERT INTO harvests (hive_id, harvest_date, kg, moisture, notes, created_at)
VALUES ((SELECT id FROM hives WHERE code = 'MK-001'), CURDATE(), 0, 18.0, '', NOW());

INSERT INTO harvests (hive_id, harvest_date, kg, moisture, notes, created_at)
VALUES ((SELECT id FROM hives WHERE code = 'MK-001'), CURDATE(), -5.00, 18.0, '', NOW());


SELECT '===== ৩. ভরা ফ্রেম মোট ফ্রেমের বেশি =====' AS ধাপ;
-- chk_hive_filled_within_frames — একই সারির দুই কলাম মেলানো
UPDATE hives SET filled = 15 WHERE code = 'MK-001';   -- frames = 10, তাই ভুল

UPDATE hives SET filled = 8 WHERE code = 'MK-001';    -- চলবে
SELECT code, frames, filled FROM hives WHERE code = 'MK-001';


SELECT '===== ৪. মোবাইল নম্বরের format =====' AS ধাপ;
-- chk_user_phone_format — frontend-এর /^01[3-9]\d{8}$/ নিয়মটাই
INSERT INTO users (phone, name, role, password, is_active, is_staff, is_superuser, created_at)
VALUES ('0171234', 'ছোট নম্বর', 'farmer', 'x', 1, 0, 0, NOW());

INSERT INTO users (phone, name, role, password, is_active, is_staff, is_superuser, created_at)
VALUES ('01212345678', 'ভুল অপারেটর', 'farmer', 'x', 1, 0, 0, NOW());   -- 012 চলবে না

INSERT INTO users (phone, name, role, password, is_active, is_staff, is_superuser, created_at)
VALUES ('01512345678', 'সঠিক নম্বর', 'farmer', 'x', 1, 0, 0, NOW());
SELECT ROW_COUNT() AS `ঢুকেছে`;


SELECT '===== ৫. মোবাইল আর ইমেইল দুটোই ফাঁকা =====' AS ধাপ;
-- chk_user_has_contact — অন্তত একটা লাগবে
INSERT INTO users (phone, email, name, role, password, is_active, is_staff, is_superuser, created_at)
VALUES (NULL, NULL, 'যোগাযোগ নেই', 'farmer', 'x', 1, 0, 0, NOW());


SELECT '===== ৬. ভুল ভূমিকা ও অবস্থা =====' AS ধাপ;
-- Django-র choices শুধু ফর্ম যাচাই করে; CHECK ডাটাবেজেই আটকায়
INSERT INTO users (phone, name, role, password, is_active, is_staff, is_superuser, created_at)
VALUES ('01612345678', 'ভুল রোল', 'manager', 'x', 1, 0, 0, NOW());

UPDATE hives SET state = 'ভালো' WHERE code = 'MK-002';   -- সবল/দুর্বল/রানীহীন ছাড়া চলবে না


SELECT '===== ৭. খামারির রেটিং ০–৫-এর বাইরে =====' AS ধাপ;
UPDATE farmer_profiles SET rating = 9.5
 WHERE user_id = (SELECT id FROM users WHERE phone = '01712345678');


SELECT '===== ৮. রানী সরানোর তারিখ বসানোর আগে =====' AS ধাপ;
-- chk_queen_dates
UPDATE queens SET removed_on = DATE_SUB(installed_on, INTERVAL 10 DAY)
 WHERE hive_id = (SELECT id FROM hives WHERE code = 'MK-001');


SELECT '===== ৯. বাংলাদেশের বাইরের অবস্থান =====' AS ধাপ;
-- chk_farm_point_in_bd — ম্যাপে ভুল জায়গায় পিন আটকায়
-- (MySQL যে টেবিল বদলাচ্ছে সেটাকেই subquery-তে সরাসরি পড়তে দেয় না —
--  ERROR 1093। derived table-এ মুড়ে দিলে চলে।)
UPDATE farms SET lat = 48.8566, lng = 2.3522
 WHERE id = (SELECT x FROM (SELECT MIN(id) AS x FROM farms) AS t);


SELECT '===== ১০. FOREIGN KEY — নেই এমন খামারে বাক্স =====' AS ধাপ;
INSERT INTO hives (code, farm_id, species_id, frames, filled, state, created_at)
VALUES ('MK-999', 999999, 1, 10, 0, 'সবল', NOW());


SELECT '===== ১১. UNIQUE — একই কোডে দুটো বাক্স =====' AS ধাপ;
INSERT INTO hives (code, farm_id, species_id, frames, filled, state, created_at)
VALUES ('MK-001', (SELECT MIN(id) FROM farms), 1, 10, 0, 'সবল', NOW());


SELECT '===== ১২. UNIQUE — এক দিনে এক বাক্সে দুই পরিদর্শন =====' AS ধাপ;
-- uq_one_inspection_per_day (hive_id, inspect_date)
INSERT INTO inspections (hive_id, inspect_date, frames_filled, state, queen_seen, eggs_seen, notes, created_at)
SELECT hive_id, inspect_date, frames_filled, state, queen_seen, eggs_seen, 'একই দিনে আবার', NOW()
  FROM inspections LIMIT 1;


SELECT '===== ১৩. UNIQUE — এক জেলায় একই নামের দুই উপজেলা =====' AS ধাপ;
-- uq_upazila_per_district — তবে অন্য জেলায় 'সদর' থাকতে পারে, সেটাই নিয়ম
INSERT INTO upazilas (district_id, name)
VALUES ((SELECT id FROM districts WHERE name = 'সিরাজগঞ্জ'), 'উল্লাপাড়া');

SELECT COUNT(*) AS `কতগুলো জেলায় "সদর" আছে` FROM upazilas WHERE name = 'সদর';


SELECT '===== ১৪. FOREIGN KEY — ব্যবহার হওয়া উপজেলা মোছা =====' AS ধাপ;
-- farms.upazila_id-তে on_delete=PROTECT (RESTRICT) — তাই আটকাবে
DELETE FROM upazilas WHERE id = (SELECT upazila_id FROM farms LIMIT 1);


SELECT '===== ১৫. CASCADE — খামার মুছলে বাক্সও যায় =====' AS ধাপ;
-- hives.farm_id-তে on_delete=CASCADE, তাই খামার মুছলে তার বাক্স,
-- বাক্সের রানী, পরিদর্শন আর মধু সংগ্রহ — সব একসাথে মুছে যায়
SELECT COUNT(*) AS `আগে বাক্স` FROM hives;
DELETE FROM farms WHERE id = (SELECT x FROM (SELECT MIN(id) AS x FROM farms) AS t);
SELECT COUNT(*) AS `পরে বাক্স` FROM hives;


-- =====================================================================
-- কিছুই রাখা হলো না
-- =====================================================================
ROLLBACK;

SELECT '===== ROLLBACK হয়েছে — ডাটাবেজ আগের মতোই =====' AS ধাপ;
SELECT (SELECT COUNT(*) FROM hives)    AS `বাক্স`,
       (SELECT COUNT(*) FROM users)    AS `ব্যবহারকারী`,
       (SELECT COUNT(*) FROM harvests) AS `মধু সংগ্রহ`,
       (SELECT COUNT(*) FROM farms)    AS `খামার`;
