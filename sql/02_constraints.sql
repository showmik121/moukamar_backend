-- =====================================================================
-- ০২ — CHECK constraint
--
-- টেবিল, PRIMARY KEY, FOREIGN KEY আর UNIQUE তৈরি হয় Django migration
-- থেকে। কিন্তু ব্যবসার নিয়মগুলো (আর্দ্রতা ৩০%-এর বেশি নয়, ভরা ফ্রেম
-- মোট ফ্রেমের বেশি নয়) ORM-এ বসানো থাকলে শুধু অ্যাপের ভেতর দিয়ে
-- এলে কাজ করে। ডাটাবেজে CHECK বসালে কেউ সরাসরি SQL দিয়ে ভুল ডাটা
-- ঢোকাতে পারে না — তাই নিয়মগুলো এখানে।
--
-- MySQL 8.0.16+ দরকার (এর আগে CHECK লেখা যেত, কিন্তু মানা হতো না)।
--
-- চালান:  .\db.ps1 -File sql\02_constraints.sql
--         (অথবা python manage.py migrate — dbschema app এটাই চালায়)
-- =====================================================================

-- ---------------------------------------------------------------------
-- ১. মধু সংগ্রহ
-- ---------------------------------------------------------------------
-- frontend-এর hive.html আর্দ্রতা ৩০%-এর বেশি হলে সেভ করতে দেয় না।
-- একই নিয়ম এখন ডাটাবেজেও — অ্যাপ বাইপাস করেও ভাঙা যাবে না।
ALTER TABLE harvests
  ADD CONSTRAINT chk_harvest_moisture
  CHECK (moisture IS NULL OR (moisture > 0 AND moisture <= 30));

-- শূন্য বা ঋণাত্মক পরিমাণ মধু অর্থহীন
ALTER TABLE harvests
  ADD CONSTRAINT chk_harvest_kg_positive
  CHECK (kg > 0);

-- এক বাক্স থেকে একবারে ৫০০ কেজি অসম্ভব — টাইপের ভুল ধরার জন্য
ALTER TABLE harvests
  ADD CONSTRAINT chk_harvest_kg_sane
  CHECK (kg <= 500);

-- ---------------------------------------------------------------------
-- ২. বাক্স
-- ---------------------------------------------------------------------
-- ভরা ফ্রেম কখনো মোট ফ্রেমের বেশি হতে পারে না।
-- লক্ষ করুন: CHECK একই সারির দুটো কলাম মেলাতে পারে, কিন্তু অন্য
-- টেবিলের মান দেখতে পারে না (subquery চলে না) — সেজন্য trigger লাগে।
ALTER TABLE hives
  ADD CONSTRAINT chk_hive_filled_within_frames
  CHECK (filled <= frames);

ALTER TABLE hives
  ADD CONSTRAINT chk_hive_frames_range
  CHECK (frames BETWEEN 1 AND 40);

ALTER TABLE hives
  ADD CONSTRAINT chk_hive_state
  CHECK (state IN ('সবল', 'দুর্বল', 'রানীহীন'));

-- ---------------------------------------------------------------------
-- ৩. রানী
-- ---------------------------------------------------------------------
-- রানী সরানোর তারিখ বসানোর তারিখের আগে হতে পারে না
ALTER TABLE queens
  ADD CONSTRAINT chk_queen_dates
  CHECK (removed_on IS NULL OR removed_on >= installed_on);

-- ---------------------------------------------------------------------
-- ৪. পরিদর্শন
-- ---------------------------------------------------------------------
ALTER TABLE inspections
  ADD CONSTRAINT chk_inspection_frames_sane
  CHECK (frames_filled <= 40);

ALTER TABLE inspections
  ADD CONSTRAINT chk_inspection_state
  CHECK (state IN ('সবল', 'দুর্বল', 'রানীহীন'));

ALTER TABLE inspection_diseases
  ADD CONSTRAINT chk_inspection_disease_severity
  CHECK (severity IN ('low', 'mid', 'high'));

-- ---------------------------------------------------------------------
-- ৫. খামার
-- ---------------------------------------------------------------------
-- Django choices শুধু ফর্ম যাচাই করে, ডাটাবেজে কলামটা সাধারণ varchar।
-- CHECK বসালে ভুল মান আর ঢুকতে পারে না।
ALTER TABLE farms
  ADD CONSTRAINT chk_farm_status
  CHECK (status IN ('সক্রিয়', 'বিশ্রামে', 'বন্ধ'));

ALTER TABLE farms
  ADD CONSTRAINT chk_farm_type
  CHECK (farm_type IN ('স্থায়ী', 'ভ্রাম্যমাণ'));

-- বাংলাদেশের ভেতরের অক্ষাংশ-দ্রাঘিমাংশ (ম্যাপে ভুল জায়গায় পিন আটকায়)
ALTER TABLE farms
  ADD CONSTRAINT chk_farm_point_in_bd
  CHECK ((lat IS NULL AND lng IS NULL)
         OR (lat BETWEEN 20.5 AND 26.7 AND lng BETWEEN 88.0 AND 92.7));

ALTER TABLE districts
  ADD CONSTRAINT chk_district_point_in_bd
  CHECK ((lat IS NULL AND lng IS NULL)
         OR (lat BETWEEN 20.5 AND 26.7 AND lng BETWEEN 88.0 AND 92.7));

-- ---------------------------------------------------------------------
-- ৬. ব্যবহারকারী
-- ---------------------------------------------------------------------
-- frontend-এর যাচাই: /^01[3-9]\d{8}$/ — হুবহু একই নিয়ম ডাটাবেজে।
-- REGEXP_LIKE deterministic, তাই CHECK-এ ব্যবহার করা চলে।
-- phone NULL হতে পারে (অ্যাডমিন শুধু ইমেইল দিয়ে, অফলাইন খামারি নাম দিয়ে)।
ALTER TABLE users
  ADD CONSTRAINT chk_user_phone_format
  CHECK (phone IS NULL OR REGEXP_LIKE(phone, '^01[3-9][0-9]{8}$'));

ALTER TABLE users
  ADD CONSTRAINT chk_user_role
  CHECK (role IN ('farmer', 'cropper', 'admin'));

-- মোবাইল বা ইমেইল — অন্তত একটা থাকতেই হবে
ALTER TABLE users
  ADD CONSTRAINT chk_user_has_contact
  CHECK (phone IS NOT NULL OR email IS NOT NULL);

ALTER TABLE farmer_profiles
  ADD CONSTRAINT chk_farmer_rating_range
  CHECK (rating BETWEEN 0 AND 5);

ALTER TABLE farmer_profiles
  ADD CONSTRAINT chk_farmer_experience_sane
  CHECK (experience_years <= 80);

ALTER TABLE farmer_profiles
  ADD CONSTRAINT chk_farmer_type
  CHECK (farm_type IN ('স্থায়ী', 'ভ্রাম্যমাণ'));

-- ---------------------------------------------------------------------
-- ৭. তথ্যভাণ্ডার
-- ---------------------------------------------------------------------
ALTER TABLE months
  ADD CONSTRAINT chk_month_range
  CHECK (month_no BETWEEN 1 AND 12);

ALTER TABLE diseases
  ADD CONSTRAINT chk_disease_risk
  CHECK (risk IN ('high', 'mid', 'low'));

ALTER TABLE disease_steps
  ADD CONSTRAINT chk_disease_step_kind
  CHECK (kind IN ('sign', 'prevent', 'treat'));

ALTER TABLE disease_steps
  ADD CONSTRAINT chk_disease_step_no
  CHECK (step_no BETWEEN 1 AND 50);

-- ---------------------------------------------------------------------
-- ৮. সতর্কতা ও কমিউনিটি
-- ---------------------------------------------------------------------
ALTER TABLE notifications
  ADD CONSTRAINT chk_notification_kind
  CHECK (kind IN ('spray', 'disease', 'inspection', 'other'));

ALTER TABLE posts
  ADD CONSTRAINT chk_post_category
  CHECK (category IN ('flora', 'resource', 'qa', 'tips'));

ALTER TABLE hive_events
  ADD CONSTRAINT chk_hive_event_kind
  CHECK (kind IN ('inspect', 'harvest', 'queen', 'move', 'disease', 'other'));

ALTER TABLE audit_log
  ADD CONSTRAINT chk_audit_action
  CHECK (action IN ('INSERT', 'UPDATE', 'DELETE'));

-- =====================================================================
-- যা CHECK দিয়ে করা যায় না — পরের ধাপে TRIGGER দিয়ে হবে
-- =====================================================================
-- ১. "ভবিষ্যতের তারিখে মধু সংগ্রহ নয়" — CHECK-এ CURDATE() চলে না,
--    কারণ CHECK শুধু deterministic function নিতে পারে। আজকের তারিখ
--    প্রতিদিন বদলায়, তাই পুরনো সারি হঠাৎ অবৈধ হয়ে যেত।
-- ২. "পরিদর্শনের ভরা ফ্রেম ওই বাক্সের মোট ফ্রেমের বেশি নয়" — অন্য
--    টেবিল দেখতে হয়, CHECK-এ subquery চলে না।
-- ৩. "এক বাক্সে একসাথে দুটো চলতি রানী নয়" — একই টেবিলের অন্য সারি
--    দেখতে হয়, সেটাও CHECK-এর বাইরে।
-- এই তিনটা sql/08_triggers.sql-এ।

-- ---- যাচাই ----
SELECT cc.CONSTRAINT_NAME AS `নাম`,
       tc.TABLE_NAME      AS `টেবিল`,
       cc.CHECK_CLAUSE    AS `শর্ত`
  FROM information_schema.CHECK_CONSTRAINTS cc
  JOIN information_schema.TABLE_CONSTRAINTS tc
       ON tc.CONSTRAINT_NAME = cc.CONSTRAINT_NAME
      AND tc.CONSTRAINT_SCHEMA = cc.CONSTRAINT_SCHEMA
 WHERE cc.CONSTRAINT_SCHEMA = DATABASE()
   AND cc.CONSTRAINT_NAME LIKE 'chk_%'
 ORDER BY tc.TABLE_NAME, cc.CONSTRAINT_NAME;
