-- =====================================================================
-- ০৫ — TRIGGER
--
-- চালান:  .\db.ps1 -Force -File queries\05_triggers.sql
--
-- -Force লাগে, কারণ ৫ নম্বর ধাপে ইচ্ছে করে ভুল ডাটা ঢোকানো হয় —
-- trigger সেগুলো আটকায় কিনা সেটাই দেখার জিনিস।
--
-- পুরো demo একটা transaction-এর ভেতরে, শেষে ROLLBACK — তাই বারবার
-- চালানো যায় আর ডাটাবেজে কিছু জমে না।
-- =====================================================================

SELECT '===== ১. আমাদের ১২টা trigger =====' AS ধাপ;

SELECT EVENT_OBJECT_TABLE                            AS `টেবিল`,
       TRIGGER_NAME                                  AS `ট্রিগার`,
       CONCAT(ACTION_TIMING, ' ', EVENT_MANIPULATION) AS `কখন চলে`
  FROM information_schema.TRIGGERS
 WHERE TRIGGER_SCHEMA = DATABASE()
 ORDER BY EVENT_OBJECT_TABLE, ACTION_TIMING;


-- audit_log-এর trigger জানতে পারে কে বদলাল — এই variable থেকে।
-- Django প্রতিটা request-এ এটা বসায় (apps/trust/middleware.py)।
SET @app_user_id = (SELECT id FROM users WHERE phone = '01712345678');
SELECT @app_user_id AS `এখন যে ব্যবহারকারী হিসেবে কাজ করছি`;

START TRANSACTION;


SELECT '===== ২. স্প্রে নোটিশ → আপনা থেকে সবাইকে সতর্কতা =====' AS ধাপ;
-- এটাই frontend-এর alerts.html-এর "খবর পাঠান" বোতামের আসল কাজ।
-- শুধু একটা সারি ঢোকানো হচ্ছে — notifications নিজে থেকে তৈরি হবে।

SELECT COUNT(*) AS `আগে সতর্কতা` FROM notifications WHERE kind = 'spray';

INSERT INTO spray_alerts (cropper_id, upazila_id, crop_id, spray_date,
                          spray_time, chemical, notes, created_at)
SELECT (SELECT id FROM users WHERE phone = '01812345678'),
       (SELECT upazila_id FROM users WHERE phone = '01712345678'),
       (SELECT id FROM crops WHERE name = 'সরিষা'),
       DATE_ADD(CURDATE(), INTERVAL 3 DAY),
       'সকাল ৮টা', 'ইমিডাক্লোপ্রিড', 'trigger-এর demo', NOW();

SELECT COUNT(*) AS `পরে সতর্কতা` FROM notifications WHERE kind = 'spray';

SELECT u.name AS `কে পেল`, n.title AS শিরোনাম, n.body AS বিবরণ
  FROM notifications n
  JOIN users u ON u.id = n.recipient_id
 WHERE n.kind = 'spray'
 ORDER BY n.id DESC LIMIT 3;

-- লক্ষ করুন: Python-এ এই কাজের কোনো কোড আর নেই। শুধু SQL দিয়ে
-- নোটিশ ঢোকালেও খামারিরা জানতে পারেন — এটাই trigger-এর লাভ।


SELECT '===== ৩. upvote গণনা trigger রাখে =====' AS ধাপ;

INSERT INTO posts (author_id, category, title, body, resource_type, price,
                   upvote_count, created_at)
SELECT id, 'tips', 'trigger-এর demo পোস্ট', 'এটা পরীক্ষার জন্য', '', '', 0, NOW()
  FROM users WHERE phone = '01712345678';
SET @post = LAST_INSERT_ID();

SELECT upvote_count AS `শুরুতে` FROM posts WHERE id = @post;

-- দুজন upvote দিল
INSERT INTO post_votes (post_id, user_id, created_at)
SELECT @post, id, NOW() FROM users WHERE phone = '01712345678';
INSERT INTO post_votes (post_id, user_id, created_at)
SELECT @post, id, NOW() FROM users WHERE phone = '01812345678';

SELECT upvote_count AS `দুজন দেওয়ার পর` FROM posts WHERE id = @post;

-- একজন ভোট তুলে নিল
DELETE FROM post_votes
 WHERE post_id = @post
   AND user_id = (SELECT id FROM users WHERE phone = '01812345678');

SELECT upvote_count AS `একজন তুলে নেওয়ার পর` FROM posts WHERE id = @post;

-- গণনা আর আসল ভোটের সংখ্যা সবসময় মেলে
SELECT p.upvote_count                                        AS `কলামে লেখা`,
       (SELECT COUNT(*) FROM post_votes v WHERE v.post_id = p.id) AS `আসল ভোট`,
       IF(p.upvote_count = (SELECT COUNT(*) FROM post_votes v WHERE v.post_id = p.id),
          'মিলছে', 'মিলছে না')                               AS `ফল`
  FROM posts p WHERE p.id = @post;


SELECT '===== ৪. বেশি ঝুঁকির রোগ পেলে আপনা থেকে সতর্কতা =====' AS ধাপ;

INSERT INTO inspections (hive_id, inspector_id, inspect_date, frames_filled,
                         state, queen_seen, eggs_seen, notes, created_at)
SELECT id, @app_user_id, CURDATE(), 4, 'দুর্বল', 1, 1, 'trigger demo', NOW()
  FROM hives WHERE code = 'MK-005';
SET @insp = LAST_INSERT_ID();

SELECT COUNT(*) AS `আগে রোগের সতর্কতা` FROM notifications WHERE kind = 'disease';

-- ফাউলব্রুড high-risk — তাই trigger সতর্কতা পাঠাবে
INSERT INTO inspection_diseases (inspection_id, disease_id, severity)
SELECT @insp, id, 'high' FROM diseases WHERE code = 'foulbrood';

-- পিঁপড়া low-risk — কোনো সতর্কতা হবে না
INSERT INTO inspection_diseases (inspection_id, disease_id, severity)
SELECT @insp, id, 'low' FROM diseases WHERE code = 'ant';

SELECT COUNT(*) AS `পরে রোগের সতর্কতা` FROM notifications WHERE kind = 'disease';

SELECT title AS শিরোনাম, body AS বিবরণ
  FROM notifications WHERE kind = 'disease' ORDER BY id DESC LIMIT 2;


SELECT '===== ৫. যে যাচাই CHECK দিয়ে করা যায় না =====' AS ধাপ;

SELECT '-- ভবিষ্যতের তারিখে মধু (CHECK-এ CURDATE() চলে না) --' AS নোট;
INSERT INTO harvests (hive_id, harvest_date, kg, moisture, notes, created_at)
SELECT id, DATE_ADD(CURDATE(), INTERVAL 7 DAY), 5.00, 18.0, '', NOW()
  FROM hives WHERE code = 'MK-001';

SELECT '-- ভরা ফ্রেম বাক্সের মোট ফ্রেমের বেশি (অন্য টেবিল দেখতে হয়) --' AS নোট;
INSERT INTO inspections (hive_id, inspect_date, frames_filled, state,
                         queen_seen, eggs_seen, notes, created_at)
SELECT id, DATE_SUB(CURDATE(), INTERVAL 1 DAY), 99, 'সবল', 1, 1, '', NOW()
  FROM hives WHERE code = 'MK-001';

SELECT '-- এক বাক্সে দুজন চলতি রানী (একই টেবিলের অন্য সারি দেখতে হয়) --' AS নোট;
INSERT INTO queens (hive_id, source, color_mark, installed_on, removed_on, note)
SELECT id, 'পরীক্ষা', 'নীল', CURDATE(), NULL, ''
  FROM hives WHERE code = 'MK-001';   -- MK-001-এ আগেই রানী আছে

SELECT '-- রানী সরানোর তারিখ বসানোর আগে --' AS নোট;
INSERT INTO queens (hive_id, source, color_mark, installed_on, removed_on, note)
SELECT id, 'পরীক্ষা', 'নীল', CURDATE(), DATE_SUB(CURDATE(), INTERVAL 10 DAY), ''
  FROM hives WHERE code = 'MK-003';


SELECT '===== ৬. রানীহীন বাক্সে রানী বসলে অবস্থা বদলায় =====' AS ধাপ;

SELECT code AS বাক্স, state AS অবস্থা FROM hives WHERE code = 'MK-009';

-- আইডিটা আগে আলাদা করে নেওয়া হচ্ছে, তারপর VALUES দিয়ে INSERT।
-- কেন: `INSERT INTO queens ... SELECT ... FROM hives` লিখলে MySQL
-- ERROR 1442 দেয় — "Can't update table 'hives' in trigger because it
-- is already used by statement which invoked this trigger"। একটা
-- trigger সেই টেবিল বদলাতে পারে না যেটা তাকে ডাকা statement-টা
-- পড়ছে। এখানে trg_queen_after_insert hives বদলায়, তাই INSERT-এ
-- hives পড়া চলবে না।
SET @h9 = (SELECT id FROM hives WHERE code = 'MK-009');

INSERT INTO queens (hive_id, source, color_mark, installed_on, removed_on, note)
VALUES (@h9, 'কৃষি অফিস', 'সবুজ', CURDATE(), NULL, '');

SELECT code AS বাক্স, state AS `অবস্থা (trigger বদলে দিল)`
  FROM hives WHERE code = 'MK-009';


SELECT '===== ৭. audit_log — কে কখন কী বদলাল =====' AS ধাপ;

SELECT COUNT(*) AS `আগে audit সারি` FROM audit_log;

-- বাক্সের অবস্থা বদল
UPDATE hives SET state = 'দুর্বল', filled = 4 WHERE code = 'MK-002';

-- মধুর পরিমাণ সংশোধন
UPDATE harvests SET kg = 15.00
 WHERE id = (SELECT x FROM (SELECT MIN(id) AS x FROM harvests) AS t);

-- একটা মধুর এন্ট্রি মুছে ফেলা
DELETE FROM harvests
 WHERE id = (SELECT x FROM (SELECT MAX(id) AS x FROM harvests) AS t);

SELECT a.table_name                         AS `টেবিল`,
       a.row_pk                             AS `সারি`,
       a.action                             AS `কাজ`,
       IFNULL(u.name, 'অ্যাপের বাইরে থেকে') AS `কে`,
       a.old_data                           AS `আগের মান`,
       a.new_data                           AS `নতুন মান`
  FROM audit_log a
  LEFT JOIN users u ON u.id = a.actor_id
 ORDER BY a.id;

SELECT '-- JSON থেকে নির্দিষ্ট ঘর বের করা --' AS নোট;
SELECT table_name                               AS `টেবিল`,
       action                                   AS `কাজ`,
       old_data ->> '$.state'                   AS `আগের অবস্থা`,
       new_data ->> '$.state'                   AS `নতুন অবস্থা`,
       old_data ->> '$.kg'                      AS `আগের কেজি`,
       new_data ->> '$.kg'                      AS `নতুন কেজি`
  FROM audit_log
 ORDER BY id;


SELECT '===== ৮. @app_user_id না থাকলে actor NULL =====' AS ধাপ;
-- কেউ অ্যাপ বাইপাস করে সরাসরি SQL চালালে variable ফাঁকা থাকে।
-- তখনও হিসাব থাকে, শুধু "কে" জানা যায় না — সেটাও একটা তথ্য।
SET @app_user_id = NULL;

UPDATE hives SET filled = 6 WHERE code = 'MK-002';

SELECT a.row_pk AS `সারি`, a.action AS `কাজ`,
       IFNULL(u.name, '(জানা যায়নি — অ্যাপের বাইরে থেকে)') AS `কে`
  FROM audit_log a
  LEFT JOIN users u ON u.id = a.actor_id
 ORDER BY a.id DESC LIMIT 1;


SELECT '===== ৯. trigger-এর কোড দেখা =====' AS ধাপ;
SHOW CREATE TRIGGER trg_spray_alert_fanout;


-- =====================================================================
-- ১০. সব ফেরানো
-- =====================================================================
ROLLBACK;

SELECT '===== ১০. ROLLBACK — সব আগের মতো =====' AS ধাপ;
-- খেয়াল করুন: trigger-এর লেখা audit_log সারিগুলোও ফিরে গেছে।
-- trigger একই transaction-এর ভেতরে চলে, তাই মূল কাজ বাতিল হলে
-- তার হিসাবও বাতিল — ভুল হিসাব পড়ে থাকে না।
SELECT (SELECT COUNT(*) FROM audit_log)     AS `audit সারি`,
       (SELECT COUNT(*) FROM notifications) AS `সতর্কতা`,
       (SELECT COUNT(*) FROM posts)         AS `পোস্ট`,
       (SELECT COUNT(*) FROM harvests)      AS `মধু সংগ্রহ`,
       (SELECT COUNT(*) FROM queens)        AS `রানী`,
       (SELECT state FROM hives WHERE code = 'MK-009') AS `MK-009 অবস্থা`;
