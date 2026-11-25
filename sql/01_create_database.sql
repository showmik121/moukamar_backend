-- =====================================================================
-- ০১ — ডাটাবেজ তৈরি
-- চালান:  .\db.ps1 -NoDb -File sql\01_create_database.sql
-- (এই একটাই ফাইল -NoDb দিয়ে চালাতে হয়, কারণ ডাটাবেজটাই তখন থাকে না)
-- =====================================================================

-- বাংলা লেখার জন্য utf8mb4 অপরিহার্য। utf8 (পুরনো) ৩ বাইট পর্যন্ত রাখে,
-- বাংলা যুক্তাক্ষর ও ইমোজিতে ৪ বাইট লাগে — তাই utf8mb4।
CREATE DATABASE IF NOT EXISTS moukhamar_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE moukhamar_db;

-- EVENT scheduler চালু — sql/08_events.sql-এর রাতের কাজগুলোর জন্য লাগবে
SET GLOBAL event_scheduler = ON;

-- যাচাই
SELECT SCHEMA_NAME                  AS `ডাটাবেজ`,
       DEFAULT_CHARACTER_SET_NAME   AS `charset`,
       DEFAULT_COLLATION_NAME       AS `collation`
  FROM information_schema.SCHEMATA
 WHERE SCHEMA_NAME = 'moukhamar_db';

SELECT @@event_scheduler AS `event scheduler`;
