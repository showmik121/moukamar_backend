-- =====================================================================
-- ০৪ — FOREIGN KEY-র ON DELETE নিয়ম
--
-- কেন এই ফাইলটা দরকার:
--   Django-র model-এ `on_delete=models.CASCADE` লেখা থাকলেও সেটা
--   ডাটাবেজে বসে না — Django নিজে Python-এ আগে সন্তান সারিগুলো মুছে
--   তারপর মা-সারি মোছে। ফলে ডাটাবেজে প্রতিটা FOREIGN KEY আসলে
--   RESTRICT (ডিফল্ট)। অ্যাপের ভেতর দিয়ে গেলে ঠিকই চলে, কিন্তু কেউ
--   সরাসরি SQL দিয়ে খামার মুছতে গেলে আটকে যায়, আর
--   "ON DELETE CASCADE" schema-তে কোথাও দেখা যায় না।
--
--   এই ফাইল প্রতিটা FK-র ON DELETE নিয়ম স্পষ্ট করে বসায়, যাতে
--   ডাটাবেজ নিজেই সম্পূর্ণ হয় — অ্যাপ ছাড়াও ঠিক আচরণ করে।
--
-- সমস্যা: Django-র তৈরি FK-র নামে একটা hash থাকে
--   (hives_farm_id_b91a1af7_fk_farms_id) — মেশিনে মেশিনে আলাদা হয়।
--   তাই নাম হাতে লেখা যায় না; information_schema থেকে খুঁজে নিতে হয়।
--   সেই কাজটা নিচের procedure করে (dynamic SQL + PREPARE দিয়ে)।
--
-- চালান:  .\db.ps1 -File sql\04_fk_actions.sql
-- =====================================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_set_fk_action $$

-- একটা কলামের FOREIGN KEY খুঁজে বের করে, সরিয়ে, নতুন ON DELETE নিয়ম
-- দিয়ে আবার বসায়। নাম জানার দরকার নেই — নিজে খুঁজে নেয়।
CREATE PROCEDURE sp_set_fk_action(
    IN p_table      VARCHAR(64),
    IN p_column     VARCHAR(64),
    IN p_ref_table  VARCHAR(64),
    IN p_ref_column VARCHAR(64),
    IN p_on_delete  VARCHAR(20)
)
BEGIN
    DECLARE v_name VARCHAR(64) DEFAULT NULL;

    -- আগের FK-র নাম খোঁজা
    SET v_name = NULL;
    SELECT CONSTRAINT_NAME INTO v_name
      FROM information_schema.KEY_COLUMN_USAGE
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = p_table
       AND COLUMN_NAME = p_column
       AND REFERENCED_TABLE_NAME IS NOT NULL
     LIMIT 1;

    -- থাকলে সরানো
    IF v_name IS NOT NULL THEN
        SET @stmt = CONCAT('ALTER TABLE `', p_table, '` DROP FOREIGN KEY `', v_name, '`');
        PREPARE s FROM @stmt;
        EXECUTE s;
        DEALLOCATE PREPARE s;
    END IF;

    -- স্পষ্ট নামে, স্পষ্ট নিয়মে আবার বসানো
    SET @stmt = CONCAT(
        'ALTER TABLE `', p_table, '` ADD CONSTRAINT `fk_', p_table, '_', p_column,
        '` FOREIGN KEY (`', p_column, '`) REFERENCES `', p_ref_table, '` (`', p_ref_column,
        '`) ON DELETE ', p_on_delete
    );
    PREPARE s FROM @stmt;
    EXECUTE s;
    DEALLOCATE PREPARE s;
END $$

DELIMITER ;

-- ---------------------------------------------------------------------
-- ক. CASCADE — মা-সারি গেলে সন্তানের থাকার অর্থ নেই
-- ---------------------------------------------------------------------
-- জেলা মুছলে তার উপজেলা, খামারি মুছলে তার খামার, খামার মুছলে বাক্স,
-- বাক্স মুছলে রানী-পরিদর্শন-মধু — সব একসাথে।
CALL sp_set_fk_action('upazilas', 'district_id', 'districts', 'id', 'CASCADE');

CALL sp_set_fk_action('farmer_profiles', 'user_id', 'users', 'id', 'CASCADE');
CALL sp_set_fk_action('cropper_profiles', 'user_id', 'users', 'id', 'CASCADE');
CALL sp_set_fk_action('farms', 'owner_id', 'users', 'id', 'CASCADE');

CALL sp_set_fk_action('farm_flora', 'farm_id', 'farms', 'id', 'CASCADE');
CALL sp_set_fk_action('farm_flora', 'flora_id', 'flora', 'id', 'CASCADE');

CALL sp_set_fk_action('hives', 'farm_id', 'farms', 'id', 'CASCADE');
CALL sp_set_fk_action('queens', 'hive_id', 'hives', 'id', 'CASCADE');
CALL sp_set_fk_action('hive_events', 'hive_id', 'hives', 'id', 'CASCADE');
CALL sp_set_fk_action('inspections', 'hive_id', 'hives', 'id', 'CASCADE');
CALL sp_set_fk_action('harvests', 'hive_id', 'hives', 'id', 'CASCADE');

CALL sp_set_fk_action('inspection_diseases', 'inspection_id', 'inspections', 'id', 'CASCADE');
CALL sp_set_fk_action('inspection_diseases', 'disease_id', 'diseases', 'id', 'CASCADE');

CALL sp_set_fk_action('disease_symptoms', 'disease_id', 'diseases', 'id', 'CASCADE');
CALL sp_set_fk_action('disease_symptoms', 'symptom_id', 'symptoms', 'id', 'CASCADE');
CALL sp_set_fk_action('disease_steps', 'disease_id', 'diseases', 'id', 'CASCADE');

CALL sp_set_fk_action('flora_blooms', 'flora_id', 'flora', 'id', 'CASCADE');
CALL sp_set_fk_action('flora_blooms', 'month_id', 'months', 'month_no', 'CASCADE');

CALL sp_set_fk_action('notifications', 'recipient_id', 'users', 'id', 'CASCADE');
CALL sp_set_fk_action('spray_alerts', 'cropper_id', 'users', 'id', 'CASCADE');

CALL sp_set_fk_action('posts', 'author_id', 'users', 'id', 'CASCADE');
CALL sp_set_fk_action('post_tags', 'post_id', 'posts', 'id', 'CASCADE');
CALL sp_set_fk_action('post_tags', 'tag_id', 'tags', 'id', 'CASCADE');
CALL sp_set_fk_action('post_votes', 'post_id', 'posts', 'id', 'CASCADE');
CALL sp_set_fk_action('post_votes', 'user_id', 'users', 'id', 'CASCADE');
CALL sp_set_fk_action('comments', 'post_id', 'posts', 'id', 'CASCADE');
CALL sp_set_fk_action('comments', 'author_id', 'users', 'id', 'CASCADE');

-- ---------------------------------------------------------------------
-- খ. SET NULL — হিসাবটা থাকবে, শুধু "কে করেছিল" ভুলে যাবে
-- ---------------------------------------------------------------------
-- পরিদর্শক বা সংগ্রহকারী অ্যাকাউন্ট মুছে ফেললেও পরিদর্শন আর মধুর
-- হিসাব হারানো চলবে না — খামারের ইতিহাস ভেঙে যাবে।
CALL sp_set_fk_action('users', 'upazila_id', 'upazilas', 'id', 'SET NULL');
CALL sp_set_fk_action('cropper_profiles', 'main_crop_id', 'crops', 'id', 'SET NULL');
CALL sp_set_fk_action('inspections', 'inspector_id', 'users', 'id', 'SET NULL');
CALL sp_set_fk_action('harvests', 'harvester_id', 'users', 'id', 'SET NULL');
CALL sp_set_fk_action('harvests', 'flora_id', 'flora', 'id', 'SET NULL');
CALL sp_set_fk_action('hive_events', 'actor_id', 'users', 'id', 'SET NULL');
CALL sp_set_fk_action('audit_log', 'actor_id', 'users', 'id', 'SET NULL');

-- ---------------------------------------------------------------------
-- গ. RESTRICT — ব্যবহার হওয়া তথ্য মোছাই যাবে না
-- ---------------------------------------------------------------------
-- যে উপজেলায় খামার আছে সেটা, বা যে প্রজাতির বাক্স আছে সেটা মুছতে
-- দেওয়া বিপজ্জনক — তাতে অনেক সারি অনাথ হয়ে যাবে।
CALL sp_set_fk_action('farms', 'upazila_id', 'upazilas', 'id', 'RESTRICT');
CALL sp_set_fk_action('hives', 'species_id', 'bee_species', 'id', 'RESTRICT');
CALL sp_set_fk_action('spray_alerts', 'upazila_id', 'upazilas', 'id', 'RESTRICT');
CALL sp_set_fk_action('spray_alerts', 'crop_id', 'crops', 'id', 'RESTRICT');

-- ---- যাচাই ----
SELECT rc.DELETE_RULE                                        AS `ON DELETE`,
       COUNT(*)                                              AS `কতগুলো FK`,
       GROUP_CONCAT(DISTINCT rc.TABLE_NAME ORDER BY rc.TABLE_NAME SEPARATOR ', ') AS `টেবিল`
  FROM information_schema.REFERENTIAL_CONSTRAINTS rc
 WHERE rc.CONSTRAINT_SCHEMA = DATABASE()
 GROUP BY rc.DELETE_RULE
 ORDER BY `কতগুলো FK` DESC;
