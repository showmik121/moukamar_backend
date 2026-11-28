-- =====================================================================
-- ০৭ — stored PROCEDURE
--
-- যে কাজগুলোতে কয়েকটা টেবিল একসাথে বদলাতে হয়, সেগুলো procedure-এ
-- রাখা হয়েছে। লাভ: পুরো কাজটা হয় সম্পূর্ণ হবে, নয় কিছুই হবে না
-- (transaction) — আর নিয়মটা ডাটাবেজেই থাকে, তাই অ্যাপ ছাড়া সরাসরি
-- SQL দিয়ে করলেও একই যাচাই হয়।
--
-- এখানে যা যা দেখানো হয়েছে:
--   • IN ও OUT প্যারামিটার
--   • START TRANSACTION / COMMIT / ROLLBACK
--   • DECLARE EXIT HANDLER FOR SQLEXCEPTION — ভুল হলে ROLLBACK
--   • SIGNAL SQLSTATE '45000' — নিজের ব্যবসার ভুলের বার্তা
--   • CURSOR + CONTINUE HANDLER FOR NOT FOUND — সারি ধরে ধরে কাজ
--   • WHILE লুপ দিয়ে কমা-দেওয়া তালিকা ভাঙা
--   • SAVEPOINT — আংশিক ROLLBACK
--
-- চালান:  .\db.ps1 -File sql\07_procedures.sql
-- দেখুন:  .\db.ps1 -File queries\04_routines.sql
-- =====================================================================

DELIMITER $$

-- ---------------------------------------------------------------------
-- ১. sp_move_hive — বাক্স অন্য খামারে সরানো
-- ---------------------------------------------------------------------
-- hive.html-এর "অন্য খামারে সরান" বোতামটা এই procedure ডাকে।
-- দুটো কাজ একসাথে: বাক্সের খামার বদল + ইতিহাসে ঘটনা লেখা।
-- মাঝপথে ভুল হলে EXIT HANDLER পুরোটা ROLLBACK করে দেয়।
DROP PROCEDURE IF EXISTS sp_move_hive $$

CREATE PROCEDURE sp_move_hive(
    IN p_code           VARCHAR(20),
    IN p_target_farm_id BIGINT,
    IN p_actor_id       BIGINT
)
BEGIN
    DECLARE v_hive_id      BIGINT DEFAULT NULL;
    DECLARE v_old_farm_id  BIGINT DEFAULT NULL;
    DECLARE v_old_owner    BIGINT DEFAULT NULL;
    DECLARE v_new_owner    BIGINT DEFAULT NULL;
    DECLARE v_old_name     VARCHAR(120);
    DECLARE v_new_name     VARCHAR(120);

    -- যেকোনো SQL ভুলে পুরো কাজটা বাতিল, আর ভুলটা উপরে পাঠিয়ে দেওয়া
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT h.id, h.farm_id, f.owner_id, f.name
      INTO v_hive_id, v_old_farm_id, v_old_owner, v_old_name
      FROM hives h
      JOIN farms f ON f.id = h.farm_id
     WHERE h.code = p_code;

    IF v_hive_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'এই কোডের বাক্স নেই';
    END IF;

    SELECT owner_id, name INTO v_new_owner, v_new_name
      FROM farms WHERE id = p_target_farm_id;

    IF v_new_owner IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'যে খামারে সরাতে চাইছেন সেটা নেই';
    END IF;

    -- নিজের বাক্স অন্যের খামারে সরানো যাবে না
    IF v_old_owner <> v_new_owner THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'অন্য খামারির খামারে বাক্স সরানো যায় না';
    END IF;

    IF v_old_farm_id = p_target_farm_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'বাক্সটা আগেই এই খামারে আছে';
    END IF;

    UPDATE hives SET farm_id = p_target_farm_id WHERE id = v_hive_id;

    INSERT INTO hive_events (hive_id, actor_id, event_date, kind, note, created_at)
    VALUES (v_hive_id, p_actor_id, CURDATE(), 'move',
            CONCAT(v_old_name, ' থেকে ', v_new_name, ' খামারে সরানো হলো'), NOW());

    COMMIT;

    SELECT p_code                AS `বাক্স`,
           v_old_name            AS `আগের খামার`,
           v_new_name            AS `নতুন খামার`,
           'সরানো হয়েছে'        AS `ফল`;
END $$


-- ---------------------------------------------------------------------
-- ২. sp_new_queen — নতুন রানী বসানো
-- ---------------------------------------------------------------------
-- আগের রানীকে "সরানো" চিহ্ন দিয়ে নতুন রানী বসায়। দুটো একসাথে না
-- হলে বাক্সে দুটো চলতি রানী থেকে যেত — তাই transaction।
DROP PROCEDURE IF EXISTS sp_new_queen $$

CREATE PROCEDURE sp_new_queen(
    IN p_code     VARCHAR(20),
    IN p_source   VARCHAR(80),
    IN p_color    VARCHAR(20),
    IN p_actor_id BIGINT
)
BEGIN
    DECLARE v_hive_id BIGINT DEFAULT NULL;
    DECLARE v_state   VARCHAR(15);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT id, state INTO v_hive_id, v_state FROM hives WHERE code = p_code;

    IF v_hive_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'এই কোডের বাক্স নেই';
    END IF;

    -- আগের চলতি রানী বন্ধ
    UPDATE queens
       SET removed_on = CURDATE()
     WHERE hive_id = v_hive_id AND removed_on IS NULL;

    -- নতুন রানী
    INSERT INTO queens (hive_id, source, color_mark, installed_on, removed_on, note)
    VALUES (v_hive_id, IFNULL(p_source, ''), IFNULL(p_color, ''), CURDATE(), NULL, '');

    INSERT INTO hive_events (hive_id, actor_id, event_date, kind, note, created_at)
    VALUES (v_hive_id, p_actor_id, CURDATE(), 'queen',
            CONCAT('নতুন রানী বসানো হলো', IF(p_source IS NULL OR p_source = '',
                                              '', CONCAT(' (', p_source, ')'))), NOW());

    -- রানীহীন বাক্সে রানী বসলে আর "রানীহীন" থাকে না
    IF v_state = 'রানীহীন' THEN
        UPDATE hives SET state = 'দুর্বল' WHERE id = v_hive_id;
    END IF;

    COMMIT;

    SELECT p_code AS `বাক্স`, fn_queen_age_years(v_hive_id) AS `রানীর বয়স`,
           'রানী বসানো হয়েছে' AS `ফল`;
END $$


-- ---------------------------------------------------------------------
-- ৩. sp_record_inspection — পরিদর্শন লেখা, রোগসহ
-- ---------------------------------------------------------------------
-- রোগের কোডগুলো কমা দিয়ে একটা string-এ আসে ('varroa,waxmoth')।
-- WHILE লুপ দিয়ে ভেঙে inspection_diseases junction-এ বসানো হয়।
--
-- SAVEPOINT-এর ব্যবহার: কোনো রোগের কোড ভুল থাকলে পুরো পরিদর্শন
-- বাতিল করা ঠিক হবে না — শুধু ওই রোগটা বাদ যাবে।
DROP PROCEDURE IF EXISTS sp_record_inspection $$

CREATE PROCEDURE sp_record_inspection(
    IN p_code          VARCHAR(20),
    IN p_date          DATE,
    IN p_frames_filled TINYINT,
    IN p_state         VARCHAR(15),
    IN p_queen_seen    TINYINT,
    IN p_eggs_seen     TINYINT,
    IN p_disease_codes VARCHAR(255),
    IN p_inspector_id  BIGINT,
    OUT p_inspection_id BIGINT,
    OUT p_diseases_added INT
)
BEGIN
    DECLARE v_hive_id    BIGINT DEFAULT NULL;
    DECLARE v_frames     SMALLINT UNSIGNED;
    DECLARE v_rest       VARCHAR(255);
    DECLARE v_one        VARCHAR(40);
    DECLARE v_disease_id BIGINT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_diseases_added = 0;

    START TRANSACTION;

    SELECT id, frames INTO v_hive_id, v_frames FROM hives WHERE code = p_code;

    IF v_hive_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'এই কোডের বাক্স নেই';
    END IF;

    -- CHECK constraint অন্য টেবিল দেখতে পারে না, তাই এই যাচাইটা এখানে
    IF p_frames_filled > v_frames THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ভরা ফ্রেম বাক্সের মোট ফ্রেমের বেশি হতে পারে না';
    END IF;

    IF p_date > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ভবিষ্যতের তারিখে পরিদর্শন লেখা যায় না';
    END IF;

    INSERT INTO inspections (hive_id, inspector_id, inspect_date, frames_filled,
                             state, queen_seen, eggs_seen, notes, created_at)
    VALUES (v_hive_id, p_inspector_id, p_date, p_frames_filled,
            p_state, p_queen_seen, p_eggs_seen, '', NOW());

    SET p_inspection_id = LAST_INSERT_ID();

    -- রোগের কোড ভাঙা: 'varroa,waxmoth' → একটা একটা
    SET v_rest = IFNULL(p_disease_codes, '');

    WHILE CHAR_LENGTH(v_rest) > 0 DO
        SET v_one = TRIM(SUBSTRING_INDEX(v_rest, ',', 1));

        IF LOCATE(',', v_rest) > 0 THEN
            SET v_rest = SUBSTRING(v_rest, LOCATE(',', v_rest) + 1);
        ELSE
            SET v_rest = '';
        END IF;

        IF CHAR_LENGTH(v_one) > 0 THEN
            SET v_disease_id = NULL;
            SELECT id INTO v_disease_id FROM diseases WHERE code = v_one;

            -- অচেনা কোড হলে পুরো পরিদর্শন বাতিল না করে শুধু ওটা বাদ
            SAVEPOINT before_disease;
            IF v_disease_id IS NULL THEN
                ROLLBACK TO SAVEPOINT before_disease;
            ELSE
                INSERT IGNORE INTO inspection_diseases (inspection_id, disease_id, severity)
                VALUES (p_inspection_id, v_disease_id, 'mid');
                SET p_diseases_added = p_diseases_added + 1;
            END IF;
        END IF;
    END WHILE;

    -- বাক্সের চলতি অবস্থা হালনাগাদ — শুধু এটাই সবচেয়ে নতুন পরিদর্শন হলে।
    -- পুরনো তারিখের পরিদর্শন পরে লিখলে বাক্সের এখনকার অবস্থা মুছে যেত।
    IF NOT EXISTS (SELECT 1 FROM inspections
                    WHERE hive_id = v_hive_id AND inspect_date > p_date) THEN
        UPDATE hives
           SET filled = p_frames_filled, state = p_state
         WHERE id = v_hive_id;
    END IF;

    INSERT INTO hive_events (hive_id, actor_id, event_date, kind, note, created_at)
    VALUES (v_hive_id, p_inspector_id, p_date, 'inspect',
            CONCAT('পরিদর্শন — ', p_state, ', ভরা ফ্রেম ',
                   fn_bn_digits(p_frames_filled)), NOW());

    COMMIT;
END $$


-- ---------------------------------------------------------------------
-- ৪. sp_notify_overdue_inspections — CURSOR দিয়ে সতর্কতা পাঠানো
-- ---------------------------------------------------------------------
-- যেসব বাক্সের পরিদর্শন বাকি, প্রতিটার জন্য মালিককে একটা করে
-- notification। সারি ধরে ধরে কাজ করতে হয়, তাই CURSOR।
--
-- CONTINUE HANDLER FOR NOT FOUND — cursor-এর সারি শেষ হলে MySQL
-- "NOT FOUND" বলে; সেটাই লুপ থামার সংকেত।
DROP PROCEDURE IF EXISTS sp_notify_overdue_inspections $$

CREATE PROCEDURE sp_notify_overdue_inspections(
    IN  p_owner_id BIGINT,
    OUT p_sent     INT
)
BEGIN
    DECLARE v_done   TINYINT DEFAULT 0;
    DECLARE v_hive   BIGINT;
    DECLARE v_code   VARCHAR(20);
    DECLARE v_days   INT;
    DECLARE v_farm   VARCHAR(120);
    DECLARE v_owner  BIGINT;

    DECLARE cur_overdue CURSOR FOR
        SELECT hive_id, code, days_since_inspection, farm_name, owner_id
          FROM v_overdue_hives
         WHERE p_owner_id IS NULL OR owner_id = p_owner_id;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    SET p_sent = 0;

    OPEN cur_overdue;

    read_loop: LOOP
        FETCH cur_overdue INTO v_hive, v_code, v_days, v_farm, v_owner;

        IF v_done = 1 THEN
            LEAVE read_loop;
        END IF;

        INSERT INTO notifications (recipient_id, kind, title, body,
                                   ref_table, ref_id, unread, created_at)
        VALUES (v_owner, 'inspection',
                CONCAT('পরিদর্শন বাকি — ', v_code),
                CONCAT(v_farm, ' খামারের ', v_code, ' বাক্স ',
                       -- কখনো পরিদর্শন না হওয়া বাক্সে দিন NULL — আগে তখন পুরো
                       -- body NULL হয়ে INSERT ভেঙে যেত
                       IF(v_days IS NULL OR v_days >= 999, 'কখনো পরিদর্শন হয়নি',
                          CONCAT(fn_bn_digits(v_days), ' দিন ধরে দেখা হয়নি')),
                       '। একবার দেখে নিন।'),
                -- ref_id বসানো হয় যাতে sql/09_events.sql-এর রাতের event
                -- বুঝতে পারে এই বাক্সের জন্য সদ্য সতর্কতা দেওয়া হয়েছে
                'hives', v_hive, 1, NOW());

        SET p_sent = p_sent + 1;
    END LOOP;

    CLOSE cur_overdue;
END $$


-- ---------------------------------------------------------------------
-- ৫. sp_season_report — OUT প্যারামিটার দিয়ে মৌসুমের হিসাব
-- ---------------------------------------------------------------------
-- একটা CALL-এ কয়েকটা সংখ্যা ফেরত দেয় — FUNCTION একটাই মান দিতে
-- পারে, procedure কয়েকটা OUT দিতে পারে। এটাই মূল পার্থক্য।
DROP PROCEDURE IF EXISTS sp_season_report $$

CREATE PROCEDURE sp_season_report(
    IN  p_owner_id      BIGINT,
    IN  p_year          INT,
    OUT p_total_kg      DECIMAL(12,2),
    OUT p_harvest_count INT,
    OUT p_hive_count    INT,
    OUT p_best_hive     VARCHAR(20),
    OUT p_best_kg       DECIMAL(10,2),
    OUT p_avg_moisture  DECIMAL(5,1)
)
BEGIN
    SELECT IFNULL(SUM(hh.kg), 0), COUNT(*), COUNT(DISTINCT hh.hive_id),
           ROUND(AVG(hh.moisture), 1)
      INTO p_total_kg, p_harvest_count, p_hive_count, p_avg_moisture
      FROM harvests hh
      JOIN hives h ON h.id = hh.hive_id
      JOIN farms f ON f.id = h.farm_id
     WHERE f.owner_id = p_owner_id
       AND YEAR(hh.harvest_date) = p_year;

    -- সবচেয়ে বেশি মধু দেওয়া বাক্স
    SET p_best_hive = NULL;
    SET p_best_kg = 0;

    SELECT h.code, SUM(hh.kg)
      INTO p_best_hive, p_best_kg
      FROM harvests hh
      JOIN hives h ON h.id = hh.hive_id
      JOIN farms f ON f.id = h.farm_id
     WHERE f.owner_id = p_owner_id
       AND YEAR(hh.harvest_date) = p_year
     GROUP BY h.id, h.code
     ORDER BY SUM(hh.kg) DESC
     LIMIT 1;
END $$


-- ---------------------------------------------------------------------
-- ৬. sp_add_harvest — মধু সংগ্রহ লেখা
-- ---------------------------------------------------------------------
-- আর্দ্রতার সীমা CHECK constraint-এও আছে। এখানে আগে থেকে পরিষ্কার
-- বাংলা বার্তা দেওয়া হয়, যাতে ব্যবহারকারী বুঝতে পারেন কী ভুল হলো।
DROP PROCEDURE IF EXISTS sp_add_harvest $$

CREATE PROCEDURE sp_add_harvest(
    IN  p_code         VARCHAR(20),
    IN  p_date         DATE,
    IN  p_kg           DECIMAL(7,2),
    IN  p_moisture     DECIMAL(5,1),
    IN  p_flora_name   VARCHAR(80),
    IN  p_harvester_id BIGINT,
    OUT p_harvest_id   BIGINT
)
BEGIN
    DECLARE v_hive_id  BIGINT DEFAULT NULL;
    DECLARE v_flora_id BIGINT DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT id INTO v_hive_id FROM hives WHERE code = p_code;

    IF v_hive_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'এই কোডের বাক্স নেই';
    END IF;

    IF p_moisture IS NOT NULL AND p_moisture > 30 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'আর্দ্রতা ৩০%-এর বেশি হলে মধু সংরক্ষণ করা যায় না';
    END IF;

    IF p_kg <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'মধুর পরিমাণ শূন্যের বেশি হতে হবে';
    END IF;

    IF p_date > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ভবিষ্যতের তারিখে মধু সংগ্রহ লেখা যায় না';
    END IF;

    IF p_flora_name IS NOT NULL AND p_flora_name <> '' THEN
        SELECT id INTO v_flora_id FROM flora WHERE name = p_flora_name;
    END IF;

    INSERT INTO harvests (hive_id, harvester_id, flora_id, harvest_date,
                          kg, moisture, notes, created_at)
    VALUES (v_hive_id, p_harvester_id, v_flora_id, p_date,
            p_kg, p_moisture, '', NOW());

    SET p_harvest_id = LAST_INSERT_ID();

    INSERT INTO hive_events (hive_id, actor_id, event_date, kind, note, created_at)
    VALUES (v_hive_id, p_harvester_id, p_date, 'harvest',
            CONCAT('মধু সংগ্রহ ', fn_kg_bn(p_kg)), NOW());

    COMMIT;
END $$

DELIMITER ;

-- ---- যাচাই ----
SELECT ROUTINE_NAME AS `নাম`,
       ROUTINE_TYPE AS `ধরন`,
       (SELECT COUNT(*) FROM information_schema.PARAMETERS p
         WHERE p.SPECIFIC_SCHEMA = r.ROUTINE_SCHEMA
           AND p.SPECIFIC_NAME = r.ROUTINE_NAME)          AS `প্যারামিটার`,
       (SELECT GROUP_CONCAT(CONCAT(p.PARAMETER_MODE, ' ', p.PARAMETER_NAME)
                            ORDER BY p.ORDINAL_POSITION SEPARATOR ', ')
          FROM information_schema.PARAMETERS p
         WHERE p.SPECIFIC_SCHEMA = r.ROUTINE_SCHEMA
           AND p.SPECIFIC_NAME = r.ROUTINE_NAME
           AND p.PARAMETER_MODE = 'OUT')                  AS `OUT যা দেয়`
  FROM information_schema.ROUTINES r
 WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_TYPE = 'PROCEDURE'
 ORDER BY ROUTINE_NAME;
