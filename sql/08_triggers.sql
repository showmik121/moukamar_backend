-- =====================================================================
-- ০৮ — TRIGGER
--
-- TRIGGER হলো টেবিলের সাথে বাঁধা কোড — INSERT/UPDATE/DELETE হলেই
-- নিজে থেকে চলে। কেউ ডাকতে হয় না, এমনকি অ্যাপ বাইপাস করে সরাসরি
-- SQL দিলেও চলে। তাই যে নিয়মগুলো কোনোভাবেই ফাঁকি দেওয়া চলবে না,
-- সেগুলো এখানে।
--
-- এই ফাইলে চার ধরনের trigger:
--   ক. আপনা থেকে কাজ হওয়া — স্প্রে নোটিশ থেকে সবাইকে সতর্কতা,
--      upvote গণনা। এগুলো আগে Python-এ ছিল; এখন ডাটাবেজে।
--   খ. যে যাচাই CHECK constraint দিয়ে করা যায় না — অন্য টেবিল দেখতে
--      হয় বা CURDATE() লাগে।
--   গ. নিরীক্ষা (audit) — কে কোন সারি কখন বদলাল।
--   ঘ. অবস্থা মিলিয়ে রাখা — রানীহীন বাক্সে রানী বসলে অবস্থা বদল।
--
-- গুরুত্বপূর্ণ: ক-এর trigger গুলো বসানোর সাথে সাথে Python-এর
-- FANOUT_IN_PYTHON আর COUNT_IN_PYTHON flag দুটো False করা হয়েছে
-- (apps/alerts/views.py, apps/community/views.py) — নাহলে একই কাজ
-- দুবার হতো।
--
-- চালান:  .\db.ps1 -File sql\08_triggers.sql
-- দেখুন:  .\db.ps1 -File queries\05_triggers.sql
-- =====================================================================

DELIMITER $$

-- =====================================================================
-- ক. আপনা থেকে হওয়া কাজ
-- =====================================================================

-- ---------------------------------------------------------------------
-- ১. স্প্রে নোটিশ → ওই উপজেলার সব খামারিকে সতর্কতা
-- ---------------------------------------------------------------------
-- frontend-এর alerts.html-এ কৃষক form পূরণ করে "খবর পাঠান" চাপলে
-- এলাকার খামারিরা জানতে পারেন — এটাই সেই কাজ।
-- INSERT ... SELECT দিয়ে একবারেই সবার জন্য সারি তৈরি হয়।
DROP TRIGGER IF EXISTS trg_spray_alert_fanout $$

CREATE TRIGGER trg_spray_alert_fanout
AFTER INSERT ON spray_alerts
FOR EACH ROW
BEGIN
    INSERT INTO notifications (recipient_id, kind, title, body,
                               ref_table, ref_id, unread, created_at)
    SELECT u.id,
           'spray',
           CONCAT('কীটনাশক স্প্রে — ', up.name),
           CONCAT(DATE_FORMAT(NEW.spray_date, '%d-%m-%Y'), ' তারিখে ',
                  c.name, ' খেতে স্প্রে হবে (কৃষক: ', cu.name,
                  ')। বাক্স ঢেকে রাখুন।'),
           'spray_alerts',
           NEW.id,
           1,
           NOW()
      FROM users u
      JOIN upazilas up ON up.id = NEW.upazila_id
      JOIN crops c     ON c.id = NEW.crop_id
      JOIN users cu    ON cu.id = NEW.cropper_id
     WHERE u.role = 'farmer'
       AND u.upazila_id = NEW.upazila_id
       AND u.is_active = 1;
END $$


-- ---------------------------------------------------------------------
-- ২ ও ৩. upvote গণনা ঠিক রাখা
-- ---------------------------------------------------------------------
-- posts.upvote_count কলামটা দ্রুত পড়ার জন্য রাখা, আসল হিসাব
-- post_votes টেবিলে। দুটো যাতে কখনো আলাদা না হয়, সেজন্য গণনা
-- হাতে নয় — trigger রাখে।
DROP TRIGGER IF EXISTS trg_post_vote_after_insert $$

CREATE TRIGGER trg_post_vote_after_insert
AFTER INSERT ON post_votes
FOR EACH ROW
BEGIN
    UPDATE posts SET upvote_count = upvote_count + 1 WHERE id = NEW.post_id;
END $$

DROP TRIGGER IF EXISTS trg_post_vote_after_delete $$

CREATE TRIGGER trg_post_vote_after_delete
AFTER DELETE ON post_votes
FOR EACH ROW
BEGIN
    -- GREATEST দিয়ে ঋণাত্মক হওয়া আটকানো
    UPDATE posts
       SET upvote_count = GREATEST(0, CAST(upvote_count AS SIGNED) - 1)
     WHERE id = OLD.post_id;
END $$


-- ---------------------------------------------------------------------
-- ৪. বেশি ঝুঁকির রোগ পাওয়া গেলে মালিককে জানানো
-- ---------------------------------------------------------------------
-- পরিদর্শনে ভ্যারোয়া মাইট বা ফাউলব্রুডের মতো high-risk রোগ পাওয়া
-- গেলে সাথে সাথে সতর্কতা — যেভাবেই এন্ট্রি হোক।
DROP TRIGGER IF EXISTS trg_inspection_disease_notify $$

CREATE TRIGGER trg_inspection_disease_notify
AFTER INSERT ON inspection_diseases
FOR EACH ROW
BEGIN
    DECLARE v_risk    VARCHAR(5);
    DECLARE v_disease VARCHAR(100);
    DECLARE v_owner   BIGINT DEFAULT NULL;
    DECLARE v_code    VARCHAR(20);
    DECLARE v_farm    VARCHAR(120);

    SELECT risk, name INTO v_risk, v_disease
      FROM diseases WHERE id = NEW.disease_id;

    IF v_risk = 'high' THEN
        SELECT f.owner_id, h.code, f.name
          INTO v_owner, v_code, v_farm
          FROM inspections i
          JOIN hives h ON h.id = i.hive_id
          JOIN farms f ON f.id = h.farm_id
         WHERE i.id = NEW.inspection_id;

        IF v_owner IS NOT NULL THEN
            INSERT INTO notifications (recipient_id, kind, title, body,
                                       ref_table, ref_id, unread, created_at)
            VALUES (v_owner, 'disease',
                    CONCAT('বেশি ঝুঁকির রোগ — ', v_disease),
                    CONCAT(v_farm, ' খামারের ', v_code, ' বাক্সে ', v_disease,
                           ' পাওয়া গেছে। দ্রুত ব্যবস্থা নিন।'),
                    'inspection_diseases', NEW.id, 1, NOW());
        END IF;
    END IF;
END $$


-- =====================================================================
-- খ. যে যাচাই CHECK constraint দিয়ে করা যায় না
-- =====================================================================
-- CHECK-এর দুটো সীমা:
--   ১. CURDATE()-এর মতো বদলে যাওয়া function ব্যবহার করতে পারে না
--      (পুরনো সারি একদিন পরে অবৈধ হয়ে যেত)
--   ২. অন্য টেবিল বা একই টেবিলের অন্য সারি দেখতে পারে না (subquery নেই)
-- এই দুই ধরনের নিয়ম trigger দিয়ে করতে হয়।
--
-- লক্ষ করুন: sql/07_procedures.sql-এর procedure গুলোতেও একই যাচাই আছে।
-- ওটা ইচ্ছাকৃত — procedure অ্যাপের পথে আগেই পরিষ্কার বাংলা বার্তা দেয়,
-- আর trigger সেই পথ এড়িয়ে সরাসরি SQL দিলেও শেষ রক্ষাকবচ হিসেবে থাকে।

-- ---------------------------------------------------------------------
-- ৫. ভবিষ্যতের তারিখে মধু সংগ্রহ নয়
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_harvest_before_insert $$

CREATE TRIGGER trg_harvest_before_insert
BEFORE INSERT ON harvests
FOR EACH ROW
BEGIN
    IF NEW.harvest_date > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ভবিষ্যতের তারিখে মধু সংগ্রহ লেখা যায় না';
    END IF;
END $$


-- ---------------------------------------------------------------------
-- ৬. পরিদর্শন — ভবিষ্যতের তারিখ নয়, আর ভরা ফ্রেম বাক্সের বেশি নয়
-- ---------------------------------------------------------------------
-- দ্বিতীয় যাচাইটা অন্য টেবিল (hives) দেখতে হয়, তাই CHECK-এ অসম্ভব।
DROP TRIGGER IF EXISTS trg_inspection_before_insert $$

CREATE TRIGGER trg_inspection_before_insert
BEFORE INSERT ON inspections
FOR EACH ROW
BEGIN
    DECLARE v_frames SMALLINT UNSIGNED DEFAULT NULL;

    IF NEW.inspect_date > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ভবিষ্যতের তারিখে পরিদর্শন লেখা যায় না';
    END IF;

    SELECT frames INTO v_frames FROM hives WHERE id = NEW.hive_id;

    IF v_frames IS NOT NULL AND NEW.frames_filled > v_frames THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ভরা ফ্রেম বাক্সের মোট ফ্রেমের বেশি হতে পারে না';
    END IF;
END $$


-- ---------------------------------------------------------------------
-- ৭. এক বাক্সে একসাথে দুজন চলতি রানী নয়
-- ---------------------------------------------------------------------
-- একই টেবিলের অন্য সারি দেখতে হয়, তাই CHECK-এ অসম্ভব।
-- v_hive_status ভিউ "চলতি রানী" বলতে removed_on IS NULL বোঝে — দুটো
-- থাকলে ভিউ সারি গুণ করে ফেলত, তাই এই পাহারা দরকার।
DROP TRIGGER IF EXISTS trg_queen_before_insert $$

CREATE TRIGGER trg_queen_before_insert
BEFORE INSERT ON queens
FOR EACH ROW
BEGIN
    DECLARE v_active INT DEFAULT 0;

    IF NEW.removed_on IS NULL THEN
        SELECT COUNT(*) INTO v_active
          FROM queens
         WHERE hive_id = NEW.hive_id AND removed_on IS NULL;

        IF v_active > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'এই বাক্সে আগেই একজন চলতি রানী আছে';
        END IF;
    END IF;

    IF NEW.removed_on IS NOT NULL AND NEW.removed_on < NEW.installed_on THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'রানী সরানোর তারিখ বসানোর তারিখের আগে হতে পারে না';
    END IF;
END $$


-- =====================================================================
-- গ. অবস্থা মিলিয়ে রাখা
-- =====================================================================

-- ---------------------------------------------------------------------
-- ৮. রানীহীন বাক্সে রানী বসলে অবস্থা আর "রানীহীন" থাকবে না
-- ---------------------------------------------------------------------
-- sp_new_queen-ও এটা করে। কিন্তু কেউ সরাসরি SQL দিয়ে রানী বসালে
-- বাক্সটা "রানীহীন" লেখা থেকে যেত — তখন ভিউ বলত রানী আছে, অথচ
-- অবস্থা রানীহীন। এই trigger সেই অসঙ্গতি আটকায়।
--
-- একটা সীমা মনে রাখতে হবে: এই trigger `hives` বদলায়, তাই যে
-- statement একে ডাকে সেটা `hives` পড়তে পারবে না। অর্থাৎ
--     INSERT INTO queens (...) SELECT id, ... FROM hives WHERE ...
-- লিখলে MySQL ERROR 1442 দেবে। আইডিটা আগে আলাদা করে নিয়ে
-- VALUES দিয়ে INSERT করতে হবে — ORM আর sp_new_queen দুটোই সেটাই করে।
DROP TRIGGER IF EXISTS trg_queen_after_insert $$

CREATE TRIGGER trg_queen_after_insert
AFTER INSERT ON queens
FOR EACH ROW
BEGIN
    IF NEW.removed_on IS NULL THEN
        UPDATE hives
           SET state = 'দুর্বল'
         WHERE id = NEW.hive_id AND state = 'রানীহীন';
    END IF;
END $$


-- =====================================================================
-- ঘ. নিরীক্ষা — কে কোন সারি কখন বদলাল
-- =====================================================================
-- audit_log-এ Python থেকে কিছু লেখা হয় না, পুরোটাই trigger ভরে।
-- তাই অ্যাপ বাইপাস করে কেউ সরাসরি SQL দিয়ে বদলালেও হিসাব থেকে যায়।
--
-- "কে বদলাল" জানার উপায়: ডাটাবেজ তো অ্যাপের ব্যবহারকারীকে চেনে না।
-- তাই প্রতিটা request-এর শুরুতে Django `SET @app_user_id = <id>` চালায়
-- (apps/trust/middleware.py), আর trigger সেটা পড়ে। সরাসরি SQL দিলে
-- variable-টা ফাঁকা থাকে, তখন actor NULL — সেটাও তথ্য।
--
-- সাবধানতা: @app_user_id-তে পুরনো বা ভুল id থাকলে FOREIGN KEY ভাঙত,
-- তাই subquery দিয়ে আসল id হলেই বসানো হয়, নাহলে NULL।

-- ---------------------------------------------------------------------
-- ৯ ও ১০. বাক্সের বদল ও মোছা
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_hive_after_update $$

CREATE TRIGGER trg_hive_after_update
AFTER UPDATE ON hives
FOR EACH ROW
BEGIN
    -- কিছু আসলেই বদলালে তবেই লেখা — created_at ছোঁয়ার জন্য নয়
    IF NOT (OLD.code <=> NEW.code AND OLD.farm_id <=> NEW.farm_id
            AND OLD.state <=> NEW.state AND OLD.frames <=> NEW.frames
            AND OLD.filled <=> NEW.filled AND OLD.species_id <=> NEW.species_id) THEN
        INSERT INTO audit_log (table_name, row_pk, action, actor_id,
                               old_data, new_data, changed_at)
        VALUES ('hives', OLD.id, 'UPDATE',
                (SELECT id FROM users WHERE id = @app_user_id),
                JSON_OBJECT('code', OLD.code, 'farm_id', OLD.farm_id,
                            'state', OLD.state, 'frames', OLD.frames,
                            'filled', OLD.filled, 'species_id', OLD.species_id),
                JSON_OBJECT('code', NEW.code, 'farm_id', NEW.farm_id,
                            'state', NEW.state, 'frames', NEW.frames,
                            'filled', NEW.filled, 'species_id', NEW.species_id),
                NOW());
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_hive_after_delete $$

CREATE TRIGGER trg_hive_after_delete
AFTER DELETE ON hives
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, row_pk, action, actor_id,
                           old_data, new_data, changed_at)
    VALUES ('hives', OLD.id, 'DELETE',
            (SELECT id FROM users WHERE id = @app_user_id),
            JSON_OBJECT('code', OLD.code, 'farm_id', OLD.farm_id,
                        'state', OLD.state, 'frames', OLD.frames,
                        'filled', OLD.filled),
            NULL, NOW());
END $$


-- ---------------------------------------------------------------------
-- ১১ ও ১২. মধু সংগ্রহের বদল ও মোছা
-- ---------------------------------------------------------------------
-- মধুর হিসাব নিয়েই সবচেয়ে বেশি প্রশ্ন ওঠে, তাই এটার প্রতিটা বদল রাখা।
DROP TRIGGER IF EXISTS trg_harvest_after_update $$

CREATE TRIGGER trg_harvest_after_update
AFTER UPDATE ON harvests
FOR EACH ROW
BEGIN
    IF NOT (OLD.kg <=> NEW.kg AND OLD.moisture <=> NEW.moisture
            AND OLD.harvest_date <=> NEW.harvest_date
            AND OLD.hive_id <=> NEW.hive_id) THEN
        INSERT INTO audit_log (table_name, row_pk, action, actor_id,
                               old_data, new_data, changed_at)
        VALUES ('harvests', OLD.id, 'UPDATE',
                (SELECT id FROM users WHERE id = @app_user_id),
                JSON_OBJECT('hive_id', OLD.hive_id, 'date', OLD.harvest_date,
                            'kg', OLD.kg, 'moisture', OLD.moisture),
                JSON_OBJECT('hive_id', NEW.hive_id, 'date', NEW.harvest_date,
                            'kg', NEW.kg, 'moisture', NEW.moisture),
                NOW());
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_harvest_after_delete $$

CREATE TRIGGER trg_harvest_after_delete
AFTER DELETE ON harvests
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, row_pk, action, actor_id,
                           old_data, new_data, changed_at)
    VALUES ('harvests', OLD.id, 'DELETE',
            (SELECT id FROM users WHERE id = @app_user_id),
            JSON_OBJECT('hive_id', OLD.hive_id, 'date', OLD.harvest_date,
                        'kg', OLD.kg, 'moisture', OLD.moisture),
            NULL, NOW());
END $$

DELIMITER ;

-- ---- যাচাই ----
SELECT TRIGGER_NAME        AS `ট্রিগার`,
       EVENT_OBJECT_TABLE  AS `টেবিল`,
       ACTION_TIMING       AS `কখন`,
       EVENT_MANIPULATION  AS `কোন কাজে`
  FROM information_schema.TRIGGERS
 WHERE TRIGGER_SCHEMA = DATABASE()
 ORDER BY EVENT_OBJECT_TABLE, ACTION_TIMING, EVENT_MANIPULATION;
