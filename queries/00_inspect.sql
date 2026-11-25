-- =====================================================================
-- ০০ — ডাটাবেজ পরিচিতি (viva-তে স্যার প্রথমে যা দেখতে চান)
-- চালান:  .\db.ps1 -File queries\00_inspect.sql
-- একটা একটা করে দেখাতে চাইলে Workbench-এ খুলে প্রতিটা ব্লক Ctrl+Enter
-- =====================================================================

-- ১. কোন ডাটাবেজে আছি, MySQL-এর কোন ভার্সন
SELECT DATABASE() AS `চলতি ডাটাবেজ`, VERSION() AS `MySQL ভার্সন`, NOW() AS `এখন`;

-- ২. সব টেবিল, সারির সংখ্যা ও charset
SELECT TABLE_NAME                AS `টেবিল`,
       TABLE_ROWS                AS `সারি (আনুমানিক)`,
       ENGINE                    AS `engine`,
       TABLE_COLLATION           AS `collation`
  FROM information_schema.TABLES
 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'BASE TABLE'
 ORDER BY TABLE_NAME;

-- ৩. সব VIEW
SELECT TABLE_NAME AS `ভিউ` FROM information_schema.VIEWS
 WHERE TABLE_SCHEMA = DATABASE() ORDER BY TABLE_NAME;

-- ৪. সব stored PROCEDURE ও FUNCTION
SELECT ROUTINE_TYPE AS `ধরন`, ROUTINE_NAME AS `নাম`, CREATED AS `তৈরি`
  FROM information_schema.ROUTINES
 WHERE ROUTINE_SCHEMA = DATABASE() ORDER BY ROUTINE_TYPE, ROUTINE_NAME;

-- ৫. সব TRIGGER — কোন টেবিলে, কখন চলে
SELECT TRIGGER_NAME        AS `ট্রিগার`,
       EVENT_OBJECT_TABLE  AS `টেবিল`,
       ACTION_TIMING       AS `কখন`,
       EVENT_MANIPULATION  AS `কোন কাজে`
  FROM information_schema.TRIGGERS
 WHERE TRIGGER_SCHEMA = DATABASE() ORDER BY EVENT_OBJECT_TABLE, ACTION_TIMING;

-- ৬. সব EVENT (scheduled job)
SELECT EVENT_NAME AS `ইভেন্ট`, STATUS AS `অবস্থা`, INTERVAL_VALUE AS `প্রতি`,
       INTERVAL_FIELD AS `একক`, LAST_EXECUTED AS `শেষ চলেছে`
  FROM information_schema.EVENTS WHERE EVENT_SCHEMA = DATABASE();

-- ৭. সব FOREIGN KEY — কোন টেবিল কোন টেবিলের সাথে জোড়া
SELECT CONSTRAINT_NAME  AS `নাম`,
       CONCAT(TABLE_NAME, '.', COLUMN_NAME)                       AS `থেকে`,
       CONCAT(REFERENCED_TABLE_NAME, '.', REFERENCED_COLUMN_NAME) AS `যেখানে`
  FROM information_schema.KEY_COLUMN_USAGE
 WHERE TABLE_SCHEMA = DATABASE() AND REFERENCED_TABLE_NAME IS NOT NULL
 ORDER BY TABLE_NAME;

-- ৮. সব CHECK constraint
SELECT CONSTRAINT_NAME AS `নাম`, CHECK_CLAUSE AS `শর্ত`
  FROM information_schema.CHECK_CONSTRAINTS
 WHERE CONSTRAINT_SCHEMA = DATABASE();

-- ৯. সব INDEX — কোন টেবিলের কোন কলামে
SELECT TABLE_NAME AS `টেবিল`, INDEX_NAME AS `ইনডেক্স`,
       GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS `কলাম`,
       IF(NON_UNIQUE = 0, 'UNIQUE', '-')               AS `ধরন`,
       INDEX_TYPE                                      AS `index type`
  FROM information_schema.STATISTICS
 WHERE TABLE_SCHEMA = DATABASE()
 GROUP BY TABLE_NAME, INDEX_NAME, NON_UNIQUE, INDEX_TYPE
 ORDER BY TABLE_NAME, INDEX_NAME;

-- ১০. একটা টেবিলের পুরো গঠন (নাম বদলে যেকোনো টেবিল দেখান)
DESCRIBE hives;
SHOW CREATE TABLE hives;
