-- =====================================================================
-- ০৪ (উল্টো) — সব FOREIGN KEY RESTRICT-এ ফেরানো
--
-- Django যে নাম (hash সহ) দিয়েছিল সেটা ফিরিয়ে আনা সম্ভব নয়, তাই
-- নিয়মটাই ডিফল্ট RESTRICT-এ ফেরানো হয় — Django নিজে যেমন বানায়।
-- =====================================================================

CALL sp_set_fk_action('upazilas', 'district_id', 'districts', 'id', 'RESTRICT');
CALL sp_set_fk_action('farmer_profiles', 'user_id', 'users', 'id', 'RESTRICT');
CALL sp_set_fk_action('cropper_profiles', 'user_id', 'users', 'id', 'RESTRICT');
CALL sp_set_fk_action('cropper_profiles', 'main_crop_id', 'crops', 'id', 'RESTRICT');
CALL sp_set_fk_action('farms', 'owner_id', 'users', 'id', 'RESTRICT');
CALL sp_set_fk_action('farms', 'upazila_id', 'upazilas', 'id', 'RESTRICT');
CALL sp_set_fk_action('farm_flora', 'farm_id', 'farms', 'id', 'RESTRICT');
CALL sp_set_fk_action('farm_flora', 'flora_id', 'flora', 'id', 'RESTRICT');
CALL sp_set_fk_action('hives', 'farm_id', 'farms', 'id', 'RESTRICT');
CALL sp_set_fk_action('hives', 'species_id', 'bee_species', 'id', 'RESTRICT');
CALL sp_set_fk_action('queens', 'hive_id', 'hives', 'id', 'RESTRICT');
CALL sp_set_fk_action('hive_events', 'hive_id', 'hives', 'id', 'RESTRICT');
CALL sp_set_fk_action('hive_events', 'actor_id', 'users', 'id', 'RESTRICT');
CALL sp_set_fk_action('inspections', 'hive_id', 'hives', 'id', 'RESTRICT');
CALL sp_set_fk_action('inspections', 'inspector_id', 'users', 'id', 'RESTRICT');
CALL sp_set_fk_action('inspection_diseases', 'inspection_id', 'inspections', 'id', 'RESTRICT');
CALL sp_set_fk_action('inspection_diseases', 'disease_id', 'diseases', 'id', 'RESTRICT');
CALL sp_set_fk_action('harvests', 'hive_id', 'hives', 'id', 'RESTRICT');
CALL sp_set_fk_action('harvests', 'harvester_id', 'users', 'id', 'RESTRICT');
CALL sp_set_fk_action('harvests', 'flora_id', 'flora', 'id', 'RESTRICT');
CALL sp_set_fk_action('disease_symptoms', 'disease_id', 'diseases', 'id', 'RESTRICT');
CALL sp_set_fk_action('disease_symptoms', 'symptom_id', 'symptoms', 'id', 'RESTRICT');
CALL sp_set_fk_action('disease_steps', 'disease_id', 'diseases', 'id', 'RESTRICT');
CALL sp_set_fk_action('flora_blooms', 'flora_id', 'flora', 'id', 'RESTRICT');
CALL sp_set_fk_action('flora_blooms', 'month_id', 'months', 'month_no', 'RESTRICT');
CALL sp_set_fk_action('users', 'upazila_id', 'upazilas', 'id', 'RESTRICT');
CALL sp_set_fk_action('notifications', 'recipient_id', 'users', 'id', 'RESTRICT');
CALL sp_set_fk_action('spray_alerts', 'cropper_id', 'users', 'id', 'RESTRICT');
CALL sp_set_fk_action('spray_alerts', 'upazila_id', 'upazilas', 'id', 'RESTRICT');
CALL sp_set_fk_action('spray_alerts', 'crop_id', 'crops', 'id', 'RESTRICT');
CALL sp_set_fk_action('posts', 'author_id', 'users', 'id', 'RESTRICT');
CALL sp_set_fk_action('post_tags', 'post_id', 'posts', 'id', 'RESTRICT');
CALL sp_set_fk_action('post_tags', 'tag_id', 'tags', 'id', 'RESTRICT');
CALL sp_set_fk_action('post_votes', 'post_id', 'posts', 'id', 'RESTRICT');
CALL sp_set_fk_action('post_votes', 'user_id', 'users', 'id', 'RESTRICT');
CALL sp_set_fk_action('comments', 'post_id', 'posts', 'id', 'RESTRICT');
CALL sp_set_fk_action('comments', 'author_id', 'users', 'id', 'RESTRICT');
CALL sp_set_fk_action('audit_log', 'actor_id', 'users', 'id', 'RESTRICT');

DROP PROCEDURE IF EXISTS sp_set_fk_action;
