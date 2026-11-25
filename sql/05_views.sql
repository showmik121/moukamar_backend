-- =====================================================================
-- ০৫ — VIEW
--
-- ভিউ হলো সংরক্ষিত query — টেবিলের মতো ব্যবহার করা যায়, কিন্তু ডাটা
-- জমা থাকে না, প্রতিবার হিসেব হয়। এখানে সেই হিসেবগুলো রাখা হলো
-- যেগুলো আগে Python-এ করা হচ্ছিল বা কলামে জমিয়ে রাখা হচ্ছিল:
--
--   • বাক্সের শেষ পরিদর্শনের কত দিন হলো (আগে hives.last_inspection_days
--     কলামে জমানো ছিল, একদিন পরেই ভুল হয়ে যেত)
--   • চলতি রানী আছে কিনা ও তার বয়স (আগে hives টেবিলের কলামে)
--   • খামারি তালিকা ও ম্যাপের তথ্য (আগে Python-এ কয়েকটা query করে
--     জোড়া লাগানো হতো)
--   • এলাকার রোগের খবর (আগে হাতে ভরা outbreaks টেবিল থেকে)
--
-- লাভ: হিসাব এক জায়গায়, তাই অ্যাপ আর SQL দুই দিক থেকেই একই উত্তর।
--
-- চালান:  .\db.ps1 -File sql\05_views.sql
-- দেখুন:  .\db.ps1 -File queries\03_views.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- ১. v_hive_status — প্রতিটা বাক্সের চলতি অবস্থা
-- ---------------------------------------------------------------------
-- যা দেখায়: রানী আছে কিনা, রানীর বয়স, শেষ পরিদর্শনের কত দিন হলো,
-- পরিদর্শন বাকি কিনা, আর বাক্সটা এ পর্যন্ত কত মধু দিয়েছে।
--
-- LEFT JOIN দিয়ে derived table (ভেতরের GROUP BY) ব্যবহার করা হয়েছে,
-- যাতে প্রতিটা বাক্সের জন্য আলাদা করে subquery না চলে।
CREATE OR REPLACE VIEW v_hive_status AS
SELECT h.id                                   AS hive_id,
       h.code                                 AS code,
       h.farm_id                              AS farm_id,
       f.name                                 AS farm_name,
       f.owner_id                             AS owner_id,
       bs.name                                AS species,
       h.frames                               AS frames,
       h.filled                               AS filled,
       h.state                                AS state,
       -- চলতি রানী = যার removed_on এখনো ফাঁকা
       IF(q.id IS NULL, 'নেই', 'আছে')         AS queen,
       IFNULL(TIMESTAMPDIFF(YEAR, q.installed_on, CURDATE()), 0) AS queen_age,
       q.source                               AS queen_source,
       q.color_mark                           AS queen_color,
       q.installed_on                          AS queen_installed_on,
       -- শেষ পরিদর্শন
       li.last_inspection                     AS last_inspection,
       DATEDIFF(CURDATE(), li.last_inspection) AS days_since_inspection,
       CASE
           WHEN li.last_inspection IS NULL                        THEN 1
           WHEN DATEDIFF(CURDATE(), li.last_inspection) > 14      THEN 1
           ELSE 0
       END                                    AS inspection_overdue,
       IFNULL(hv.total_kg, 0)                 AS total_honey_kg,
       hv.last_harvest                        AS last_harvest
  FROM hives h
  JOIN farms f        ON f.id = h.farm_id
  JOIN bee_species bs ON bs.id = h.species_id
  LEFT JOIN queens q  ON q.hive_id = h.id AND q.removed_on IS NULL
  LEFT JOIN (SELECT hive_id, MAX(inspect_date) AS last_inspection
               FROM inspections
              GROUP BY hive_id) li ON li.hive_id = h.id
  LEFT JOIN (SELECT hive_id, SUM(kg) AS total_kg, MAX(harvest_date) AS last_harvest
               FROM harvests
              GROUP BY hive_id) hv ON hv.hive_id = h.id;


-- ---------------------------------------------------------------------
-- ২. v_overdue_hives — যেসব বাক্সের পরিদর্শন বাকি
-- ---------------------------------------------------------------------
-- এটা একটা ভিউয়ের উপর বসানো ভিউ। উপরের হিসাব আবার লেখার দরকার নেই —
-- শুধু ছেঁকে নেওয়া।
CREATE OR REPLACE VIEW v_overdue_hives AS
SELECT *
  FROM v_hive_status
 WHERE inspection_overdue = 1;


-- ---------------------------------------------------------------------
-- ৩. v_farm_summary — খামার অনুযায়ী সারাংশ (hives.html)
-- ---------------------------------------------------------------------
-- LEFT JOIN + aggregate: বাক্স নেই এমন খামারও তালিকায় থাকে (০ নিয়ে)।
-- মধু আর ফুলের নাম correlated subquery দিয়ে আনা হয়েছে, যাতে GROUP BY
-- জটিল না হয় আর সারি গুণ হয়ে না যায়।
CREATE OR REPLACE VIEW v_farm_summary AS
SELECT f.id                                                   AS farm_id,
       f.owner_id                                             AS owner_id,
       f.name                                                 AS farm_name,
       f.status                                               AS status,
       f.farm_type                                            AS farm_type,
       f.established_on                                       AS established_on,
       f.lat                                                  AS lat,
       f.lng                                                  AS lng,
       up.name                                                AS upazila,
       di.name                                                AS district,
       COUNT(h.id)                                            AS hive_count,
       -- SUM(শর্ত) গুনে ফেলে, কিন্তু MySQL সেটা DECIMAL হিসেবে ফেরত
       -- দেয় — গণনা তো পূর্ণসংখ্যা, তাই CAST করে নেওয়া হলো
       CAST(SUM(h.state = 'সবল') AS SIGNED)                    AS strong_count,
       CAST(SUM(h.state = 'দুর্বল') AS SIGNED)                 AS weak_count,
       CAST(SUM(h.state = 'রানীহীন') AS SIGNED)                AS queenless_count,
       CAST(IFNULL(SUM(h.filled), 0) AS SIGNED)                AS filled_frames,
       (SELECT IFNULL(SUM(hh.kg), 0)
          FROM harvests hh
          JOIN hives h2 ON h2.id = hh.hive_id
         WHERE h2.farm_id = f.id)                             AS total_honey_kg,
       (SELECT GROUP_CONCAT(fl.name ORDER BY fl.name SEPARATOR ', ')
          FROM farm_flora ff
          JOIN flora fl ON fl.id = ff.flora_id
         WHERE ff.farm_id = f.id)                             AS flora
  FROM farms f
  JOIN upazilas up  ON up.id = f.upazila_id
  JOIN districts di ON di.id = up.district_id
  LEFT JOIN hives h ON h.farm_id = f.id
 GROUP BY f.id, f.owner_id, f.name, f.status, f.farm_type,
          f.established_on, f.lat, f.lng, up.name, di.name;


-- ---------------------------------------------------------------------
-- ৪. v_farmer_directory — খামারি তালিকা ও ম্যাপ
-- ---------------------------------------------------------------------
-- directory.html আর map.html-এর প্রতিটা ঘর এখান থেকে আসে। আগে এই
-- জোড়া লাগানোর কাজটা Python-এ কয়েকটা query করে হতো; এখন একটা ভিউ।
--
-- অবস্থান: খামারের নিজের coordinate না থাকলে জেলার coordinate
-- (COALESCE) — এজন্যই districts টেবিলে lat/lng রাখা হয়েছে।
CREATE OR REPLACE VIEW v_farmer_directory AS
SELECT us.id                                                  AS user_id,
       us.name                                                AS name,
       us.phone                                               AS phone,
       us.created_at                                          AS created_at,
       IFNULL(NULLIF(fp.farm_name, ''),
              CONCAT(us.name, '-এর খামার'))                   AS farm_name,
       IFNULL(fp.farm_type, 'স্থায়ী')                         AS farm_type,
       IFNULL(fp.experience_years, 0)                         AS experience_years,
       IFNULL(fp.rating, 0)                                   AS rating,
       up.name                                                AS upazila,
       di.name                                                AS district,
       COALESCE((SELECT f.lat FROM farms f
                  WHERE f.owner_id = us.id AND f.lat IS NOT NULL
                  ORDER BY f.id LIMIT 1), di.lat)             AS lat,
       COALESCE((SELECT f.lng FROM farms f
                  WHERE f.owner_id = us.id AND f.lng IS NOT NULL
                  ORDER BY f.id LIMIT 1), di.lng)             AS lng,
       (SELECT COUNT(*) FROM farms f WHERE f.owner_id = us.id) AS farm_count,
       (SELECT COUNT(*)
          FROM hives h JOIN farms f ON f.id = h.farm_id
         WHERE f.owner_id = us.id)                            AS hive_count,
       (SELECT COUNT(*)
          FROM hives h JOIN farms f ON f.id = h.farm_id
         WHERE f.owner_id = us.id AND h.state <> 'রানীহীন')   AS active_hives,
       (SELECT IFNULL(SUM(hh.kg), 0)
          FROM harvests hh
          JOIN hives h ON h.id = hh.hive_id
          JOIN farms f ON f.id = h.farm_id
         WHERE f.owner_id = us.id)                            AS total_honey_kg,
       (SELECT GROUP_CONCAT(DISTINCT fl.name ORDER BY fl.name SEPARATOR ', ')
          FROM farm_flora ff
          JOIN flora fl ON fl.id = ff.flora_id
          JOIN farms f  ON f.id = ff.farm_id
         WHERE f.owner_id = us.id)                            AS flora
  FROM users us
  LEFT JOIN farmer_profiles fp ON fp.user_id = us.id
  LEFT JOIN upazilas up        ON up.id = us.upazila_id
  LEFT JOIN districts di       ON di.id = up.district_id
 WHERE us.role = 'farmer'
   AND us.is_active = 1;


-- ---------------------------------------------------------------------
-- ৫. v_monthly_honey — মাসভিত্তিক মধু (dashboard.html-এর চার্ট)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_monthly_honey AS
SELECT f.owner_id                      AS owner_id,
       YEAR(hh.harvest_date)           AS yr,
       MONTH(hh.harvest_date)          AS mn,
       mo.name_bn                      AS month_name,
       COUNT(*)                        AS harvest_count,
       COUNT(DISTINCT hh.hive_id)      AS hive_count,
       SUM(hh.kg)                      AS total_kg,
       ROUND(AVG(hh.kg), 2)            AS avg_kg,
       ROUND(AVG(hh.moisture), 1)      AS avg_moisture
  FROM harvests hh
  JOIN hives h  ON h.id = hh.hive_id
  JOIN farms f  ON f.id = h.farm_id
  JOIN months mo ON mo.month_no = MONTH(hh.harvest_date)
 GROUP BY f.owner_id, YEAR(hh.harvest_date), MONTH(hh.harvest_date), mo.name_bn;


-- ---------------------------------------------------------------------
-- ৬. v_area_outbreaks — গত ৩০ দিনে এলাকার রোগ (alerts.html)
-- ---------------------------------------------------------------------
-- আগে এটা হাতে ভরা `outbreaks` টেবিল ছিল — সংখ্যা পুরনো হয়ে যেত।
-- এখন পরিদর্শনের আসল তথ্য থেকে গোনা হয়, তাই সবসময় তাজা।
-- ভিউতে CURDATE() চলে (CHECK constraint-এ চলে না)।
CREATE OR REPLACE VIEW v_area_outbreaks AS
SELECT d.id                            AS disease_id,
       d.code                          AS disease_code,
       d.name                          AS disease,
       d.risk                          AS risk,
       up.name                         AS upazila,
       di.name                         AS district,
       COUNT(DISTINCT f.id)            AS farms_affected,
       COUNT(DISTINCT h.id)            AS hives_affected,
       MAX(i.inspect_date)             AS last_seen,
       IF(COUNT(DISTINCT f.id) >= 3, 1, 0) AS alert
  FROM inspection_diseases idis
  JOIN inspections i  ON i.id = idis.inspection_id
  JOIN hives h        ON h.id = i.hive_id
  JOIN farms f        ON f.id = h.farm_id
  JOIN upazilas up    ON up.id = f.upazila_id
  JOIN districts di   ON di.id = up.district_id
  JOIN diseases d     ON d.id = idis.disease_id
 WHERE i.inspect_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
 GROUP BY d.id, d.code, d.name, d.risk, up.name, di.name;


-- ---------------------------------------------------------------------
-- ৭. v_disease_symptoms — রোগ ও তার লক্ষণ এক সারিতে
-- ---------------------------------------------------------------------
-- disease_symptoms junction টেবিলটা M:N, তাই এক রোগে কয়েক সারি।
-- GROUP_CONCAT দিয়ে এক সারিতে এনে দিলে diseases.html-এর কাজ সহজ হয়।
-- LEFT JOIN রাখা হয়েছে যাতে লক্ষণ বসানো হয়নি এমন রোগও তালিকায় থাকে।
CREATE OR REPLACE VIEW v_disease_symptoms AS
SELECT d.id                                                        AS disease_id,
       d.code                                                      AS disease_code,
       d.name                                                      AS disease,
       d.kind                                                      AS kind,
       d.risk                                                      AS risk,
       COUNT(s.id)                                                 AS symptom_count,
       GROUP_CONCAT(s.code ORDER BY s.code SEPARATOR ',')          AS symptom_codes,
       GROUP_CONCAT(s.name ORDER BY s.code SEPARATOR ' · ')        AS symptom_names,
       (SELECT COUNT(*) FROM disease_steps st
         WHERE st.disease_id = d.id AND st.kind = 'treat')          AS treat_steps,
       (SELECT COUNT(*) FROM disease_steps st
         WHERE st.disease_id = d.id AND st.kind = 'prevent')        AS prevent_steps
  FROM diseases d
  LEFT JOIN disease_symptoms ds ON ds.disease_id = d.id
  LEFT JOIN symptoms s          ON s.id = ds.symptom_id
 GROUP BY d.id, d.code, d.name, d.kind, d.risk;


-- ---------------------------------------------------------------------
-- ৮. v_farmer_dashboard — হোমের সব সংখ্যা এক সারিতে
-- ---------------------------------------------------------------------
-- এটাও ভিউয়ের উপর ভিউ — v_hive_status থেকে পড়ে।
-- /api/dashboard/ endpoint এখান থেকেই উত্তর দেয়।
CREATE OR REPLACE VIEW v_farmer_dashboard AS
SELECT us.id                                                       AS owner_id,
       us.name                                                     AS owner_name,
       (SELECT COUNT(*) FROM farms f WHERE f.owner_id = us.id)      AS farms_total,
       (SELECT COUNT(*) FROM farms f
         WHERE f.owner_id = us.id AND f.status = 'সক্রিয়')          AS farms_active,
       (SELECT COUNT(*) FROM v_hive_status v
         WHERE v.owner_id = us.id)                                  AS hives_total,
       (SELECT COUNT(*) FROM v_hive_status v
         WHERE v.owner_id = us.id AND v.queen = 'নেই')              AS hives_queenless,
       (SELECT COUNT(*) FROM v_hive_status v
         WHERE v.owner_id = us.id AND v.inspection_overdue = 1)     AS overdue_inspections,
       (SELECT IFNULL(SUM(v.total_honey_kg), 0) FROM v_hive_status v
         WHERE v.owner_id = us.id)                                  AS honey_total_kg,
       (SELECT COUNT(*) FROM notifications n
         WHERE n.recipient_id = us.id AND n.unread = 1)             AS alerts_unread
  FROM users us
 WHERE us.role = 'farmer';


-- ---- যাচাই ----
SELECT TABLE_NAME AS `ভিউ`,
       (SELECT COUNT(*) FROM information_schema.COLUMNS c
         WHERE c.TABLE_SCHEMA = v.TABLE_SCHEMA AND c.TABLE_NAME = v.TABLE_NAME) AS `কলাম`
  FROM information_schema.VIEWS v
 WHERE TABLE_SCHEMA = DATABASE()
 ORDER BY TABLE_NAME;
