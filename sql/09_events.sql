-- =====================================================================
-- ০৯ — EVENT (ডাটাবেজের নিজের scheduled কাজ)
--
-- EVENT হলো সময় ধরে নিজে থেকে চলা SQL — Linux-এর cron বা Windows-এর
-- Task Scheduler-এর মতো, কিন্তু ডাটাবেজের ভেতরেই। অ্যাপ বন্ধ থাকলেও
-- চলে, আলাদা কোনো সার্ভিস লাগে না।
--
-- কাজ করার শর্ত: event_scheduler চালু থাকতে হবে। sql/01-এ
-- `SET GLOBAL event_scheduler = ON` দিয়ে চালু করা আছে। MySQL সার্ভিস
-- রিস্টার্ট হলে আবার বন্ধ হয়ে যেতে পারে — তখন my.ini-তে
-- `event_scheduler=ON` লিখে রাখলে স্থায়ী হয়।
--
-- চালান:  .\db.ps1 -File sql\09_events.sql
-- দেখুন:  .\db.ps1 -File queries\06_events_users.sql
-- =====================================================================

DELIMITER $$

-- ---------------------------------------------------------------------
-- ১. ev_nightly_overdue_alerts — রাতে বাকি পরিদর্শনের সতর্কতা
-- ---------------------------------------------------------------------
-- প্রতি রাত ৯টায় চলে। যেসব বাক্স ১৪ দিনের বেশি দেখা হয়নি, মালিককে
-- জানায়।
--
-- NOT EXISTS দিয়ে পাহারা: একই বাক্সের জন্য গত ৭ দিনে সতর্কতা দেওয়া
-- হয়ে থাকলে আবার দেওয়া হয় না। নাহলে রোজ রাতে একই বার্তা জমে
-- নোটিফিকেশন সেন্টার ভরে যেত।
DROP EVENT IF EXISTS ev_nightly_overdue_alerts $$

CREATE EVENT ev_nightly_overdue_alerts
ON SCHEDULE EVERY 1 DAY
    STARTS TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '21:00:00')
ON COMPLETION PRESERVE
ENABLE
COMMENT 'বাকি পরিদর্শনের সতর্কতা, প্রতি রাত ৯টা'
DO
BEGIN
    INSERT INTO notifications (recipient_id, kind, title, body,
                               ref_table, ref_id, unread, created_at)
    SELECT v.owner_id,
           'inspection',
           CONCAT('পরিদর্শন বাকি — ', v.code),
           CONCAT(v.farm_name, ' খামারের ', v.code, ' বাক্স ',
                  IF(v.days_since_inspection >= 999,
                     'কখনো পরিদর্শন হয়নি',
                     CONCAT(fn_bn_digits(v.days_since_inspection),
                            ' দিন ধরে দেখা হয়নি')),
                  '। একবার দেখে নিন।'),
           'hives',
           v.hive_id,
           1,
           NOW()
      FROM v_overdue_hives v
     WHERE v.owner_id IS NOT NULL
       AND NOT EXISTS (
               SELECT 1
                 FROM notifications n
                WHERE n.recipient_id = v.owner_id
                  AND n.kind = 'inspection'
                  AND n.ref_table = 'hives'
                  AND n.ref_id = v.hive_id
                  AND n.created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY));
END $$


-- ---------------------------------------------------------------------
-- ২. ev_cleanup_old_notifications — পুরনো পড়া সতর্কতা মোছা
-- ---------------------------------------------------------------------
-- পড়া হয়ে গেছে আর ৬০ দিনের বেশি পুরনো — এমন সতর্কতা রাখার দরকার নেই।
-- অপঠিত সতর্কতা কখনো মোছা হয় না, যত পুরনোই হোক।
DROP EVENT IF EXISTS ev_cleanup_old_notifications $$

CREATE EVENT ev_cleanup_old_notifications
ON SCHEDULE EVERY 1 WEEK
    STARTS TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '03:00:00')
ON COMPLETION PRESERVE
ENABLE
COMMENT 'পড়া ও ৬০ দিনের পুরনো সতর্কতা মোছা, সপ্তাহে একবার'
DO
BEGIN
    DELETE FROM notifications
     WHERE unread = 0
       AND created_at < DATE_SUB(NOW(), INTERVAL 60 DAY);
END $$


-- ---------------------------------------------------------------------
-- ৩. ev_dearth_season_notice — ফুল কম মৌসুমের আগাম খবর
-- ---------------------------------------------------------------------
-- মাসের ১ তারিখে দেখে, সামনের মাসে ফুল কম কিনা (fn_is_dearth_month)।
-- হলে সব খামারিকে জানায় — তখন মৌমাছিকে চিনির শিরা দিতে হয়, তাই
-- আগে থেকে জানা দরকার।
--
-- লক্ষ করুন: event-এর ভেতরে আমাদের নিজের লেখা FUNCTION ডাকা হচ্ছে।
DROP EVENT IF EXISTS ev_dearth_season_notice $$

CREATE EVENT ev_dearth_season_notice
ON SCHEDULE EVERY 1 MONTH
    STARTS TIMESTAMP(DATE_FORMAT(CURDATE() + INTERVAL 1 MONTH, '%Y-%m-01'), '08:00:00')
ON COMPLETION PRESERVE
ENABLE
COMMENT 'সামনের মাসে ফুল কম হলে খামারিদের আগাম খবর'
DO
BEGIN
    DECLARE v_next TINYINT;
    DECLARE v_name VARCHAR(20);

    SET v_next = MONTH(CURDATE() + INTERVAL 1 MONTH);

    IF fn_is_dearth_month(v_next) = 1 THEN
        SELECT name_bn INTO v_name FROM months WHERE month_no = v_next;

        INSERT INTO notifications (recipient_id, kind, title, body,
                                   ref_table, ref_id, unread, created_at)
        SELECT u.id,
               'other',
               CONCAT(v_name, ' মাসে ফুল কম থাকবে'),
               CONCAT('সামনের মাস (', v_name, ') ফুল কম থাকার মৌসুম। ',
                      'কলোনি দুর্বল হওয়া আটকাতে চিনির শিরা দেওয়ার ব্যবস্থা রাখুন।'),
               'months',
               v_next,
               1,
               NOW()
          FROM users u
         WHERE u.role = 'farmer' AND u.is_active = 1;
    END IF;
END $$

DELIMITER ;

-- ---- যাচাই ----
SELECT @@event_scheduler AS `scheduler চালু আছে`;

SELECT EVENT_NAME                                   AS `ইভেন্ট`,
       CONCAT('প্রতি ', INTERVAL_VALUE, ' ', INTERVAL_FIELD) AS `কত পরপর`,
       STARTS                                       AS `প্রথম চলবে`,
       STATUS                                       AS `অবস্থা`,
       EVENT_COMMENT                                AS `কী করে`
  FROM information_schema.EVENTS
 WHERE EVENT_SCHEMA = DATABASE()
 ORDER BY EVENT_NAME;
