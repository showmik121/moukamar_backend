-- =====================================================================
-- ০৬ — stored FUNCTION
--
-- FUNCTION একটা মান ফেরত দেয় আর SELECT-এর ভেতরে কলামের মতো ব্যবহার
-- করা যায়। PROCEDURE-এর সাথে পার্থক্য:
--   FUNCTION  → RETURNS একটা মান, SELECT-এ বসানো যায়, ডাটা বদলায় না
--   PROCEDURE → CALL দিয়ে চালাতে হয়, কয়েকটা OUT মান দিতে পারে,
--               INSERT/UPDATE/DELETE করতে পারে, transaction চালাতে পারে
--
-- `READS SQL DATA` বা `DETERMINISTIC` লেখা বাধ্যতামূলক, কারণ MySQL-এ
-- binary log চালু থাকলে এগুলো ছাড়া function বানাতে দেয় না (ERROR 1418)।
--   DETERMINISTIC   → একই ইনপুটে সবসময় একই উত্তর (টেবিল পড়ে না)
--   READS SQL DATA  → টেবিল পড়ে, কিন্তু বদলায় না
--
-- চালান:  .\db.ps1 -File sql\06_functions.sql
-- =====================================================================

DELIMITER $$

-- ---------------------------------------------------------------------
-- ১. fn_bn_digits — ইংরেজি অঙ্ককে বাংলা অঙ্কে
-- ---------------------------------------------------------------------
-- অ্যাপে সব সংখ্যা বাংলায় দেখানো হয়। PDF বা রিপোর্ট সরাসরি SQL
-- থেকে বানালে এই function কাজে লাগে।
-- WHILE লুপ + REPLACE + SUBSTRING — টেবিল পড়ে না, তাই DETERMINISTIC।
DROP FUNCTION IF EXISTS fn_bn_digits $$

CREATE FUNCTION fn_bn_digits(p_text VARCHAR(255))
    RETURNS VARCHAR(512) CHARSET utf8mb4
    DETERMINISTIC
    NO SQL
BEGIN
    DECLARE v_out VARCHAR(512) DEFAULT p_text;
    DECLARE i INT DEFAULT 0;

    IF p_text IS NULL THEN
        RETURN NULL;
    END IF;

    WHILE i <= 9 DO
        SET v_out = REPLACE(v_out, CAST(i AS CHAR),
                            SUBSTRING('০১২৩৪৫৬৭৮৯', i + 1, 1));
        SET i = i + 1;
    END WHILE;

    RETURN v_out;
END $$


-- ---------------------------------------------------------------------
-- ২. fn_hive_honey_total — এক বাক্স এ পর্যন্ত কত মধু দিয়েছে
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_hive_honey_total $$

CREATE FUNCTION fn_hive_honey_total(p_hive_id BIGINT)
    RETURNS DECIMAL(10,2)
    READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(10,2);

    SELECT IFNULL(SUM(kg), 0) INTO v_total
      FROM harvests
     WHERE hive_id = p_hive_id;

    RETURN v_total;
END $$


-- ---------------------------------------------------------------------
-- ৩. fn_days_since_inspection — শেষ পরিদর্শনের কত দিন হলো
-- ---------------------------------------------------------------------
-- কখনো পরিদর্শন না হলে NULL নয়, ৯৯৯ ফেরত দেয় — তাহলে
-- "WHERE fn_days_since_inspection(id) > 14" লিখলেই নতুন বাক্সও ধরা পড়ে।
DROP FUNCTION IF EXISTS fn_days_since_inspection $$

CREATE FUNCTION fn_days_since_inspection(p_hive_id BIGINT)
    RETURNS INT
    READS SQL DATA
BEGIN
    DECLARE v_last DATE;

    SELECT MAX(inspect_date) INTO v_last
      FROM inspections
     WHERE hive_id = p_hive_id;

    IF v_last IS NULL THEN
        RETURN 999;
    END IF;

    RETURN DATEDIFF(CURDATE(), v_last);
END $$


-- ---------------------------------------------------------------------
-- ৪. fn_queen_age_years — চলতি রানীর বয়স (বছরে)
-- ---------------------------------------------------------------------
-- রানী না থাকলে -১ — "রানীহীন" আর "নতুন রানী" আলাদা করে বোঝা যায়।
DROP FUNCTION IF EXISTS fn_queen_age_years $$

CREATE FUNCTION fn_queen_age_years(p_hive_id BIGINT)
    RETURNS INT
    READS SQL DATA
BEGIN
    DECLARE v_installed DATE;

    SELECT installed_on INTO v_installed
      FROM queens
     WHERE hive_id = p_hive_id AND removed_on IS NULL
     ORDER BY installed_on DESC
     LIMIT 1;

    IF v_installed IS NULL THEN
        RETURN -1;
    END IF;

    RETURN TIMESTAMPDIFF(YEAR, v_installed, CURDATE());
END $$


-- ---------------------------------------------------------------------
-- ৫. fn_hive_health_score — বাক্সের স্বাস্থ্যের নম্বর (০–১০০)
-- ---------------------------------------------------------------------
-- কয়েকটা জিনিস মিলিয়ে একটা নম্বর:
--   অবস্থা (সবল ৬০ / দুর্বল ৩০ / রানীহীন ১০)
--   + রানী আছে ২০
--   + ভরা ফ্রেমের অনুপাত সর্বোচ্চ ২০
--   − পরিদর্শন বাকি হলে ১৫
-- CASE, IF আর GREATEST/LEAST দিয়ে ০–১০০-এর মধ্যে রাখা হয়।
DROP FUNCTION IF EXISTS fn_hive_health_score $$

CREATE FUNCTION fn_hive_health_score(p_hive_id BIGINT)
    RETURNS INT
    READS SQL DATA
BEGIN
    DECLARE v_state   VARCHAR(15);
    DECLARE v_frames  SMALLINT UNSIGNED;
    DECLARE v_filled  SMALLINT UNSIGNED;
    DECLARE v_score   INT DEFAULT 0;

    SELECT state, frames, filled INTO v_state, v_frames, v_filled
      FROM hives
     WHERE id = p_hive_id;

    IF v_state IS NULL THEN
        RETURN 0;          -- এমন বাক্স নেই
    END IF;

    SET v_score = CASE v_state
                      WHEN 'সবল'     THEN 60
                      WHEN 'দুর্বল'   THEN 30
                      ELSE 10
                  END;

    IF fn_queen_age_years(p_hive_id) >= 0 THEN
        SET v_score = v_score + 20;
    END IF;

    IF v_frames > 0 THEN
        SET v_score = v_score + ROUND(v_filled / v_frames * 20);
    END IF;

    IF fn_days_since_inspection(p_hive_id) > 14 THEN
        SET v_score = v_score - 15;
    END IF;

    RETURN GREATEST(0, LEAST(100, v_score));
END $$


-- ---------------------------------------------------------------------
-- ৬. fn_farm_honey_total — খামারের সব বাক্স মিলিয়ে মধু
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_farm_honey_total $$

CREATE FUNCTION fn_farm_honey_total(p_farm_id BIGINT)
    RETURNS DECIMAL(12,2)
    READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(12,2);

    SELECT IFNULL(SUM(hh.kg), 0) INTO v_total
      FROM harvests hh
      JOIN hives h ON h.id = hh.hive_id
     WHERE h.farm_id = p_farm_id;

    RETURN v_total;
END $$


-- ---------------------------------------------------------------------
-- ৭. fn_is_dearth_month — এই মাসে ফুল কম কিনা
-- ---------------------------------------------------------------------
-- calendar.html-এর "ফুল কম মৌসুম" — flora_blooms junction দেখে বলে।
DROP FUNCTION IF EXISTS fn_is_dearth_month $$

CREATE FUNCTION fn_is_dearth_month(p_month TINYINT)
    RETURNS TINYINT
    READS SQL DATA
BEGIN
    DECLARE v_count INT DEFAULT 0;

    SELECT COUNT(*) INTO v_count
      FROM flora f
      JOIN flora_blooms fb ON fb.flora_id = f.id
     WHERE fb.month_id = p_month
       AND f.is_dearth = 1;

    RETURN IF(v_count > 0, 1, 0);
END $$


-- ---------------------------------------------------------------------
-- ৮. fn_money_bn — টাকার অঙ্ক বাংলায় সাজিয়ে
-- ---------------------------------------------------------------------
-- দুটো function একসাথে ব্যবহারের উদাহরণ (fn_bn_digits ডাকে)।
DROP FUNCTION IF EXISTS fn_kg_bn $$

CREATE FUNCTION fn_kg_bn(p_kg DECIMAL(10,2))
    RETURNS VARCHAR(64) CHARSET utf8mb4
    DETERMINISTIC
    NO SQL
BEGIN
    IF p_kg IS NULL THEN
        RETURN '—';
    END IF;
    RETURN CONCAT(fn_bn_digits(FORMAT(p_kg, 2)), ' কেজি');
END $$

DELIMITER ;

-- ---- যাচাই ----
SELECT ROUTINE_NAME AS `নাম`,
       ROUTINE_TYPE AS `ধরন`,
       DTD_IDENTIFIER AS `যা ফেরত দেয়`,
       IS_DETERMINISTIC AS `deterministic`,
       SQL_DATA_ACCESS AS `ডাটা ব্যবহার`
  FROM information_schema.ROUTINES
 WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_TYPE = 'FUNCTION'
 ORDER BY ROUTINE_NAME;
