-- =====================================================================
-- ০৩ (উল্টো) — index সরানো
-- =====================================================================

DROP INDEX ft_symptom_name ON symptoms;
DROP INDEX ft_disease_search ON diseases;
DROP INDEX ft_disease_step_text ON disease_steps;

DROP INDEX ix_user_role_upazila_active ON users;
DROP INDEX ix_harvest_hive_kg ON harvests;
DROP INDEX ix_notif_unread_recent ON notifications;
DROP INDEX ix_farm_owner_status ON farms;
