-- =====================================================================
-- ০৬ — EVENT, ব্যবহারকারী ও অনুমতি
--
-- চালান:  .\db.ps1 -File queries\06_events_users.sql
--
-- EVENT-এর demo-তে একটা সমস্যা আছে: ওগুলো রাতে বা মাসের ১ তারিখে চলে,
-- এখন চালিয়ে দেখা যায় না। তাই এখানে event-এর ভেতরের query টা হাতে
-- চালিয়ে দেখানো হয় — ফল একই।
-- =====================================================================

SELECT '===== ১. scheduler চালু আছে কি =====' AS ধাপ;
-- এটা বন্ধ থাকলে event লেখা থাকলেও কখনো চলবে না — প্রথমে এটাই দেখা
SELECT @@event_scheduler AS `scheduler`,
       IF(@@event_scheduler = 'ON', 'হ্যাঁ, event চলবে',
          'না — SET GLOBAL event_scheduler = ON দিতে হবে') AS `অবস্থা`;


SELECT '===== ২. আমাদের ৩টা event =====' AS ধাপ;

SELECT EVENT_NAME                                            AS `ইভেন্ট`,
       CONCAT('প্রতি ', INTERVAL_VALUE, ' ', INTERVAL_FIELD)  AS `কত পরপর`,
       STARTS                                                AS `প্রথম চলবে`,
       IFNULL(LAST_EXECUTED, 'এখনো চলেনি')                   AS `শেষ চলেছে`,
       STATUS                                                AS `অবস্থা`,
       EVENT_COMMENT                                          AS `কী করে`
  FROM information_schema.EVENTS
 WHERE EVENT_SCHEMA = DATABASE()
 ORDER BY EVENT_NAME;


SELECT '===== ৩. রাতের event হাতে চালিয়ে দেখা =====' AS ধাপ;

START TRANSACTION;

SELECT code AS বাক্স, days_since_inspection AS `কত দিন দেখা হয়নি`
  FROM v_overdue_hives;

SELECT COUNT(*) AS `আগে সতর্কতা` FROM notifications WHERE kind = 'inspection';

-- ev_nightly_overdue_alerts-এর ভেতরে ঠিক এই query টাই আছে
INSERT INTO notifications (recipient_id, kind, title, body,
                           ref_table, ref_id, unread, created_at)
SELECT v.owner_id, 'inspection',
       CONCAT('পরিদর্শন বাকি — ', v.code),
       CONCAT(v.farm_name, ' খামারের ', v.code, ' বাক্স ',
              IF(v.days_since_inspection >= 999, 'কখনো পরিদর্শন হয়নি',
                 CONCAT(fn_bn_digits(v.days_since_inspection), ' দিন ধরে দেখা হয়নি')),
              '। একবার দেখে নিন।'),
       'hives', v.hive_id, 1, NOW()
  FROM v_overdue_hives v
 WHERE v.owner_id IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM notifications n
                    WHERE n.recipient_id = v.owner_id
                      AND n.kind = 'inspection'
                      AND n.ref_table = 'hives'
                      AND n.ref_id = v.hive_id
                      AND n.created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY));

SELECT COUNT(*) AS `পরে সতর্কতা` FROM notifications WHERE kind = 'inspection';
SELECT title AS শিরোনাম, body AS বিবরণ
  FROM notifications WHERE kind = 'inspection' ORDER BY id DESC LIMIT 2;

SELECT '-- আবার চালালে ডুপ্লিকেট হয় না (NOT EXISTS পাহারা দিচ্ছে) --' AS নোট;
INSERT INTO notifications (recipient_id, kind, title, body,
                           ref_table, ref_id, unread, created_at)
SELECT v.owner_id, 'inspection', CONCAT('পরিদর্শন বাকি — ', v.code), '',
       'hives', v.hive_id, 1, NOW()
  FROM v_overdue_hives v
 WHERE v.owner_id IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM notifications n
                    WHERE n.recipient_id = v.owner_id
                      AND n.kind = 'inspection'
                      AND n.ref_table = 'hives'
                      AND n.ref_id = v.hive_id
                      AND n.created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY));

SELECT ROW_COUNT() AS `দ্বিতীয়বার কত সারি ঢুকল`,
       '০ হওয়াই ঠিক' AS নোট;

ROLLBACK;


SELECT '===== ৪. ফুল কম মৌসুমের event-এর শর্ত =====' AS ধাপ;
-- ev_dearth_season_notice মাসের ১ তারিখে দেখে সামনের মাসে ফুল কম কিনা
SELECT m.month_no                                   AS `মাস নম্বর`,
       m.name_bn                                    AS `মাস`,
       IF(fn_is_dearth_month(m.month_no), 'ফুল কম', 'ফুল আছে') AS `অবস্থা`,
       IF(fn_is_dearth_month(m.month_no), 'খবর যাবে', '—')     AS `event কী করবে`
  FROM months m
 ORDER BY m.month_no;


SELECT '===== ৫. ডাটাবেজের ব্যবহারকারী ও ROLE =====' AS ধাপ;

SELECT User AS `ব্যবহারকারী`, Host AS `কোথা থেকে ঢুকতে পারে`
  FROM mysql.user
 WHERE User LIKE 'mk\_%'
 ORDER BY User;

SELECT '-- কে কোন ROLE পেয়েছে --' AS নোট;
SELECT CONCAT(TO_USER, '@', TO_HOST) AS `ব্যবহারকারী`,
       FROM_USER                     AS `ROLE`
  FROM mysql.role_edges
 WHERE TO_USER LIKE 'mk\_%'
 ORDER BY TO_USER;


SELECT '===== ৬. কে কী করতে পারে =====' AS ধাপ;

SELECT '-- mk_role_app: পুরো ডাটাবেজ পড়া + routine চালানো --' AS নোট;
SHOW GRANTS FOR 'mk_role_app';

SELECT '-- mk_role_readonly: শুধু পড়া --' AS নোট;
SHOW GRANTS FOR 'mk_role_readonly';

SELECT '-- mk_role_owner: সব --' AS নোট;
SHOW GRANTS FOR 'mk_role_owner';


SELECT '===== ৭. audit_log-এ অ্যাপের কী অনুমতি আছে =====' AS ধাপ;
-- লেখার অনুমতি টেবিল ধরে ধরে দেওয়া হয়েছে, audit_log বাদ দিয়ে।
-- তাই এই টেবিলটা তালিকায় থাকবে না।
SELECT TABLE_NAME     AS `টেবিল`,
       PRIVILEGE_TYPE AS `অনুমতি`
  FROM information_schema.TABLE_PRIVILEGES
 WHERE GRANTEE LIKE '%mk_role_app%'
   AND TABLE_NAME IN ('audit_log', 'hives', 'harvests')
 ORDER BY TABLE_NAME, PRIVILEGE_TYPE;

SELECT 'audit_log উপরের তালিকায় নেই — অর্থাৎ অ্যাপ ওটায় লিখতে পারে না' AS নোট;

SELECT '-- তবু trigger লিখতে পারে, কারণ trigger DEFINER-এর অনুমতিতে চলে --' AS নোট;
SELECT TRIGGER_NAME AS `ট্রিগার`, DEFINER AS `কার অনুমতিতে চলে`
  FROM information_schema.TRIGGERS
 WHERE TRIGGER_SCHEMA = DATABASE()
   AND TRIGGER_NAME LIKE '%audit%' OR TRIGGER_NAME LIKE 'trg_hive_after%'
 ORDER BY TRIGGER_NAME;


SELECT '===== ৮. হাতে পরীক্ষা করে দেখতে =====' AS ধাপ;
SELECT 'PowerShell-এ চালান:' AS `কীভাবে`;
SELECT '$env:MYSQL_PWD="mk_report_local_only"; mysql -u mk_report -h localhost -D moukhamar_db -e "UPDATE hives SET filled=1"' AS `শুধু-পড়া ব্যবহারকারী`;
SELECT 'ফল: ERROR 1142 — UPDATE command denied' AS `যা হবে`;
