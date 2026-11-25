-- =====================================================================
-- ১১ — DATABASE USER, ROLE ও GRANT
--
-- এখন পর্যন্ত অ্যাপ `root` দিয়ে ডাটাবেজে ঢোকে। সেটা ডেভেলপমেন্টে
-- চলে, কিন্তু ঠিক নয় — root সব করতে পারে, এমনকি টেবিল মুছে ফেলতেও।
-- অ্যাপের দরকার শুধু সারি পড়া-লেখা।
--
-- MySQL 8-এ ROLE আছে (৫.৭-এ ছিল না)। ROLE হলো অনুমতির একটা বান্ডিল —
-- একবার বানিয়ে যত ইচ্ছা ব্যবহারকারীকে দেওয়া যায়। অনুমতি বদলাতে হলে
-- ROLE-এ একবার বদলালেই সবার জন্য বদলে যায়।
--
-- এখানে তিনটে ROLE:
--   mk_role_app      → অ্যাপের যা দরকার (সারি পড়া-লেখা + routine চালানো)
--   mk_role_readonly → শুধু পড়া (রিপোর্ট, চার্ট, BI টুল)
--   mk_role_owner    → সব (মাইগ্রেশন চালানোর জন্য)
--
-- ⚠ নিচের পাসওয়ার্ডগুলো শুধু লোকাল পরীক্ষার জন্য। আসল সার্ভারে
--   বসানোর আগে অবশ্যই বদলাতে হবে, আর এই ফাইলে আসল পাসওয়ার্ড
--   লিখে রাখা যাবে না।
--
-- চালান:  .\db.ps1 -File sql\11_users_grants.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- ১. ROLE তৈরি
-- ---------------------------------------------------------------------
-- আগে DROP, তারপর CREATE — কেন:
--   GRANT/REVOKE transaction-এর ভেতরে থাকে না, তাই এই ফাইল একবার
--   মাঝপথে থেমে গেলে অর্ধেক অনুমতি বসে যায়, আর পরেরবার চালালে সেই
--   পুরনো অনুমতি রয়ে যায়। ROLE টা মুছে নতুন করে বানালে প্রতিবার
--   একই ফল পাওয়া যায় — ঠিক যা লেখা আছে, তার বেশি কিছু নয়।
DROP ROLE IF EXISTS 'mk_role_app';
DROP ROLE IF EXISTS 'mk_role_readonly';
DROP ROLE IF EXISTS 'mk_role_owner';

CREATE ROLE 'mk_role_app';
CREATE ROLE 'mk_role_readonly';
CREATE ROLE 'mk_role_owner';


-- ---------------------------------------------------------------------
-- ২. mk_role_app — অ্যাপের ভূমিকা
-- ---------------------------------------------------------------------
-- পুরো ডাটাবেজ পড়তে পারবে, আর procedure/function চালাতে পারবে।
-- কিন্তু টেবিল বা ভিউ বানানো-মোছা পারবে না — তাই অ্যাপে SQL
-- injection-এর মতো কিছু ঘটলেও কেউ `DROP TABLE` চালাতে পারবে না।
GRANT SELECT ON moukhamar_db.* TO 'mk_role_app';
GRANT EXECUTE ON moukhamar_db.* TO 'mk_role_app';

-- ---------------------------------------------------------------------
-- audit_log শুধু পড়ার জন্য — একটা সূক্ষ্ম জিনিস
-- ---------------------------------------------------------------------
-- audit_log-এ অ্যাপ নিজে কিছু লেখে না (trigger লেখে), আর নিরীক্ষার
-- হিসাব কেউ বদলাতে বা মুছতে পারলে তার আর কোনো মূল্য থাকে না।
--
-- প্রথমে ভেবেছিলাম পুরো ডাটাবেজে লেখার অনুমতি দিয়ে তারপর
--     REVOKE UPDATE, DELETE ON moukhamar_db.audit_log FROM 'mk_role_app';
-- দিয়ে ওই একটা টেবিল বাদ দেব। কিন্তু MySQL তাতে বলে:
--     ERROR 1147: There is no such grant defined for user ...
-- কারণ database-স্তরের অনুমতি থেকে একটা টেবিল আলাদা করে বাদ দেওয়া
-- যায় না — MySQL global, database আর table স্তরের অনুমতির যোগফল নেয়,
-- বিয়োগ করে না।
--
-- তাই উল্টো পথে যেতে হয়: লেখার অনুমতি টেবিল ধরে ধরে দিতে হয়,
-- audit_log বাদ দিয়ে। ৩০টা টেবিলের জন্য ৩০টা GRANT লেখার বদলে
-- information_schema থেকে নাম নিয়ে dynamic SQL দিয়ে কাজটা করা হলো।

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_grant_app_writes $$

CREATE PROCEDURE sp_grant_app_writes()
BEGIN
    DECLARE v_done  TINYINT DEFAULT 0;
    DECLARE v_table VARCHAR(64);

    DECLARE cur_tables CURSOR FOR
        SELECT TABLE_NAME
          FROM information_schema.TABLES
         WHERE TABLE_SCHEMA = 'moukhamar_db'
           AND TABLE_TYPE = 'BASE TABLE'
           AND TABLE_NAME <> 'audit_log';   -- এটাই বাদ

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    OPEN cur_tables;

    grant_loop: LOOP
        FETCH cur_tables INTO v_table;
        IF v_done = 1 THEN
            LEAVE grant_loop;
        END IF;

        SET @stmt = CONCAT('GRANT INSERT, UPDATE, DELETE ON `moukhamar_db`.`',
                           v_table, '` TO ''mk_role_app''');
        PREPARE s FROM @stmt;
        EXECUTE s;
        DEALLOCATE PREPARE s;
    END LOOP;

    CLOSE cur_tables;
END $$

DELIMITER ;

CALL sp_grant_app_writes();
DROP PROCEDURE sp_grant_app_writes;

-- ---------------------------------------------------------------------
-- তাহলে trigger কীভাবে audit_log-এ লেখে?
-- ---------------------------------------------------------------------
-- অ্যাপের ব্যবহারকারীর audit_log-এ INSERT অনুমতি নেই। তবু বাক্স
-- বদলালে trigger ঠিকই সারি লিখে ফেলে। কারণ TRIGGER চলে তার
-- **DEFINER**-এর অনুমতিতে, যে ডেকেছে তার অনুমতিতে নয় —
-- আমাদের trigger গুলোর DEFINER root@localhost।
--
-- ফল ঠিক যা চাই:
--   • অ্যাপ নিরীক্ষার হিসাব পড়তে পারে, কিন্তু বদলাতে বা মুছতে পারে না
--   • তবু প্রতিটা বদল আপনা থেকে হিসাবে উঠে যায়
-- অর্থাৎ audit_log অ্যাপের জন্য append-only, আর লেখাটা ডাটাবেজ নিজে
-- করে — এটাই নিরীক্ষার হিসাব রাখার সঠিক নকশা।


-- ---------------------------------------------------------------------
-- ৩. mk_role_readonly — শুধু পড়া
-- ---------------------------------------------------------------------
-- রিপোর্ট বানানো বা চার্ট দেখানোর টুলের জন্য। কিছু লিখতে পারবে না।
GRANT SELECT ON moukhamar_db.* TO 'mk_role_readonly';


-- ---------------------------------------------------------------------
-- ৪. mk_role_owner — সব
-- ---------------------------------------------------------------------
-- মাইগ্রেশন চালানোর জন্য টেবিল, ভিউ, procedure, trigger বানানো-মোছার
-- অনুমতি দরকার।
GRANT ALL PRIVILEGES ON moukhamar_db.* TO 'mk_role_owner';


-- ---------------------------------------------------------------------
-- ৫. ব্যবহারকারী তৈরি ও ROLE দেওয়া
-- ---------------------------------------------------------------------
-- 'localhost' দেওয়ায় এই ব্যবহারকারীরা শুধু একই মেশিন থেকে ঢুকতে পারবে।
CREATE USER IF NOT EXISTS 'mk_app'@'localhost'
    IDENTIFIED BY 'mk_app_local_only';
CREATE USER IF NOT EXISTS 'mk_report'@'localhost'
    IDENTIFIED BY 'mk_report_local_only';
CREATE USER IF NOT EXISTS 'mk_owner'@'localhost'
    IDENTIFIED BY 'mk_owner_local_only';

GRANT 'mk_role_app'      TO 'mk_app'@'localhost';
GRANT 'mk_role_readonly' TO 'mk_report'@'localhost';
GRANT 'mk_role_owner'    TO 'mk_owner'@'localhost';

-- ROLE পাওয়া আর ROLE চালু থাকা আলাদা জিনিস। লগ ইন করার সাথে সাথে
-- ROLE টা কাজ করতে শুরু করবে — সেজন্য DEFAULT ROLE বসাতে হয়।
-- নাহলে প্রতিবার `SET ROLE` লিখতে হতো।
SET DEFAULT ROLE ALL TO 'mk_app'@'localhost';
SET DEFAULT ROLE ALL TO 'mk_report'@'localhost';
SET DEFAULT ROLE ALL TO 'mk_owner'@'localhost';

FLUSH PRIVILEGES;


-- ---- যাচাই ----
SELECT '--- কারা আছে ---' AS নোট;
SELECT User AS `ব্যবহারকারী`, Host AS `কোথা থেকে`,
       IF(account_locked = 'Y', 'লক', 'খোলা') AS `অবস্থা`
  FROM mysql.user
 WHERE User LIKE 'mk\_%'
 ORDER BY User;

SELECT '--- কে কোন ROLE পেয়েছে ---' AS নোট;
SELECT CONCAT(TO_USER, '@', TO_HOST)   AS `ব্যবহারকারী`,
       FROM_USER                       AS `ROLE`
  FROM mysql.role_edges
 WHERE TO_USER LIKE 'mk\_%'
 ORDER BY TO_USER;

SELECT '--- mk_role_app কী কী করতে পারে ---' AS নোট;
SHOW GRANTS FOR 'mk_role_app';

SELECT '--- mk_app কী কী করতে পারে (ROLE সহ) ---' AS নোট;
SHOW GRANTS FOR 'mk_app'@'localhost' USING 'mk_role_app';

SELECT '--- mk_report শুধু পড়তে পারে ---' AS নোট;
SHOW GRANTS FOR 'mk_role_readonly';


-- =====================================================================
-- অ্যাপকে mk_app দিয়ে চালাতে চাইলে
-- =====================================================================
-- .env ফাইলে বদলান:
--     DB_USER=mk_app
--     DB_PASSWORD=mk_app_local_only
--
-- তখন অ্যাপ আর টেবিল মুছতে পারবে না। কিন্তু `manage.py migrate`
-- চালাতে owner দরকার — তাই মাইগ্রেশনের সময় DB_USER=mk_owner (বা root)
-- ব্যবহার করতে হবে। আসল সার্ভারে এভাবেই করা হয়: অ্যাপ চলে কম
-- অনুমতির ব্যবহারকারী দিয়ে, আর মাইগ্রেশন চলে আলাদা ব্যবহারকারী দিয়ে।
