-- =====================================================================
-- ১১ (উল্টো) — ব্যবহারকারী ও ROLE সরানো
--
-- ব্যবহারকারী মুছলে তার পাওয়া ROLE-ও আপনা থেকে চলে যায়।
-- =====================================================================

DROP USER IF EXISTS 'mk_app'@'localhost';
DROP USER IF EXISTS 'mk_report'@'localhost';
DROP USER IF EXISTS 'mk_owner'@'localhost';

DROP ROLE IF EXISTS 'mk_role_app';
DROP ROLE IF EXISTS 'mk_role_readonly';
DROP ROLE IF EXISTS 'mk_role_owner';

FLUSH PRIVILEGES;
