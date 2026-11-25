# মৌখামার — Django Backend

MySQL 8.0 + Django 4.2 + DRF।

| কী জানতে চান | কোথায় |
|---|---|
| ডাটাবেজের ডিজাইন, কোন নিয়ম কোথায় ভাঙছিল, কী কী ফাইল আছে | **[sql/00_DESIGN.md](sql/00_DESIGN.md)** |
| ER ডায়াগ্রাম, প্রতিটা টেবিলের কলাম, ON DELETE তালিকা | **[sql/ERD.md](sql/ERD.md)** |
| পুরো schema এক ফাইলে (জমা দেওয়ার জন্য) | **[sql/schema_dump.sql](sql/schema_dump.sql)** |
| presentation ও viva-তে কী চালাবেন | নিচের [SQL চালানো](#sql-চালানো--dbps1) অংশ |

**ডাটাবেজে এখন যা আছে:** ৩০টা টেবিল (+ Django-র ৯টা), ৪৭টা FOREIGN KEY,
১১২টা index, ২৮টা CHECK constraint, ৮টা VIEW, ৮টা FUNCTION, ৭টা
PROCEDURE, ১২টা TRIGGER, ৩টা EVENT আর ৩টা ROLE। সবই
`python manage.py migrate` একটা কমান্ডে তৈরি হয়।

## ইনস্টল করুন

```powershell
# ১. Python 3.12 ও MySQL 8.0 ইনস্টল আছে ধরে নিচ্ছি

# ২. Virtual environment ও প্যাকেজ
py -3.12 -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt

# ৩. .env ফাইল বানান (.env.example কপি করে) আর MySQL পাসওয়ার্ড লিখুন
copy .env.example .env
#    DB_PASSWORD=আপনার_পাসওয়ার্ড
#    settings.py আর কোডে পাসওয়ার্ড রাখে না, .env থেকে পড়ে

# ৪. ডাটাবেজ তৈরি
.\db.ps1 -NoDb -File sql\01_create_database.sql

# ৫. টেবিল + CHECK constraint + index + FK নিয়ম
#    (apps/dbschema-র migration sql/02…04 ফাইলগুলোও চালিয়ে দেয়)
python manage.py migrate

# ৬. reference ডাটা — ৬৪ জেলা, ৫০১ উপজেলা, ৮টা রোগ, লক্ষণ, ফুল
.\db.ps1 -File sql\10_seed.sql

# ৭. ডেমো ব্যবহারকারী ও নমুনা খামার
python manage.py seed_demo

# ৮. অ্যাডমিন ব্যবহারকারী (ঐচ্ছিক)
python manage.py createsuperuser

# ৯. সার্ভার
python manage.py runserver 8000
```

সব ঠিক আছে কিনা একবারে দেখতে:

```powershell
.venv\Scripts\python.exe verify_api.py
```

৭৮টা যাচাই চালায় — endpoint, অনুমতি, junction টেবিল থেকে ডাটা আসা,
নিবন্ধনে খামার তৈরি, পাসওয়ার্ড বদল, CHECK constraint গুলো আসলেই ভুল
ডাটা আটকায় কিনা, ভিউয়ের হিসাব ORM-এর হিসাবের সাথে মেলে কিনা,
procedure গুলো ভুল ডাটায় বাংলা বার্তা দিয়ে আটকায় কিনা, আর trigger
গুলো আপনা থেকে ঠিক কাজ করে কিনা (স্প্রে নোটিশ থেকে **ঠিক একটা**
সতর্কতা, audit_log-এ কে বদলাল)। নিজের তৈরি সব সারি নিজেই মুছে দেয়,
তাই বারবার চালানো যায়।

`queries/` ফোল্ডারের কোনো demo ফাইল মাঝপথে থেমে গেলে ডাটাবেজ আগের
অবস্থায় ফেরাতে:

```powershell
python manage.py seed_demo --reset
```

## ডেমো লগ ইন

| কে | মোবাইল | পাসওয়ার্ড |
|---|---|---|
| খামারি | 01712345678 | demo1234 |
| কৃষক | 01812345678 | demo1234 |

frontend-এর লগ ইন পাতার "demo তথ্য বসান" বোতামের সাথে মিলিয়ে বানানো।

## SQL চালানো — `db.ps1`

পাসওয়ার্ড `.env` থেকে নেয় (command line-এ লেখা হয় না), আর বাংলা লেখা ভাঙে না।

```powershell
.\db.ps1 "SELECT * FROM hives LIMIT 5"   # সরাসরি query
.\db.ps1 -Objects                        # সব table/view/procedure/function/trigger/event
.\db.ps1 -Tables                         # টেবিল ও সারির সংখ্যা
.\db.ps1 -File queries\00_inspect.sql    # ফাইল চালানো
.\db.ps1 -Force -File queries\01_...sql  # ভুল হলেও থামবে না
.\db.ps1 -Dump                           # sql\schema_dump.sql নতুন করে বানায়
.\db.ps1                                 # mysql> prompt
```

`queries/` ফোল্ডারে topic অনুযায়ী সাজানো query — presentation ও viva-র জন্য:

| ফাইল | কী দেখায় |
|---|---|
| `00_inspect.sql` | ডাটাবেজে কী আছে — টেবিল, ভিউ, procedure, trigger, FK, CHECK, index |
| `01_constraints.sql` | CHECK, FOREIGN KEY ও UNIQUE আসলেই ভুল ডাটা আটকায় (১৭টা ভুল চেষ্টা, শেষে ROLLBACK) |
| `02_indexes.sql` | EXPLAIN — FULLTEXT বনাম LIKE, covering index, আর ৫০,০০০ সারিতে index-এর আগে-পরে |
| `03_views.sql` | ৮টা ভিউ, ভিউয়ের উপর ভিউ, ভিউ-টেবিল JOIN, আর ভিউ যে ডাটা জমায় না তার হাতে-কলমে প্রমাণ |
| `04_routines.sql` | FUNCTION SELECT/WHERE/ORDER BY-তে, OUT প্যারামিটার, CURSOR, SAVEPOINT, আর ৮টা SIGNAL বার্তা |
| `05_triggers.sql` | স্প্রে নোটিশ থেকে আপনা থেকে সতর্কতা, upvote গণনা, audit_log-এ আগের-নতুন মান, আর CHECK যা পারে না |
| `06_events_users.sql` | EVENT-এর ভেতরের query হাতে চালিয়ে দেখা, ROLE ও GRANT, আর অ্যাপ কেন `audit_log` বদলাতে পারে না |

`01_constraints.sql`, `04_routines.sql` আর `05_triggers.sql` চালাতে
`-Force` লাগে, কারণ ওদের কিছু statement ইচ্ছে করে ভুল — ডাটাবেজ,
procedure আর trigger সেগুলো আটকায় কিনা সেটাই দেখার জিনিস।

## Electron app-এর সাথে সংযোগ

```powershell
# Backend চালু রেখে frontend ফোল্ডারে
$env:MK_BACKEND_URL="http://127.0.0.1:8000"; npm start
```

## API Endpoints

সব `/api/` দিয়ে শুরু। লগ ইন ছাড়া শুধু **খোলা** চিহ্নিত endpoint চলে।

### লগ ইন ও প্রোফাইল
| Method | URL | কাজ |
|--------|-----|-----|
| POST | `/auth/register/` | নিবন্ধন (খামারির প্রথম খামারও তৈরি হয়) · খোলা |
| POST | `/auth/login/` | মোবাইল বা ইমেইল দিয়ে লগ ইন · খোলা |
| POST | `/auth/logout/` | লগ আউট |
| GET/PATCH | `/auth/me/` | নিজের প্রোফাইল দেখা ও বদল |
| POST | `/auth/password/` | পাসওয়ার্ড বদল |
| GET | `/auth/users/` | সব ব্যবহারকারী (অ্যাডমিন প্যানেল) · খোলা |

### খামার, বাক্স, পরিদর্শন, মধু
| Method | URL | কাজ |
|--------|-----|-----|
| GET | `/dashboard/` | হোমের সব সংখ্যা এক অনুরোধে · ভিউ |
| GET/POST | `/farms/` | খামার তালিকা ও নতুন খামার |
| GET | `/farms/summary/` | খামার অনুযায়ী বাক্সের সারাংশ · ভিউ |
| GET/PATCH/DELETE | `/farms/<id>/` | একটা খামার |
| GET/POST | `/hives/?farm=<id>` | বাক্স |
| GET | `/hives/status/?farm=&overdue=1` | বাক্সের চলতি অবস্থা — রানী, শেষ পরিদর্শন, মধু · ভিউ |
| POST | `/hives/remind-overdue/` | বাকি পরিদর্শনের সতর্কতা পাঠানো · procedure (CURSOR) |
| GET | `/reports/monthly-honey/` | মাসভিত্তিক মধু · ভিউ |
| GET | `/reports/season/?year=` | মৌসুমের হিসাব, সেরা বাক্স · procedure (OUT) |
| GET/PATCH/DELETE | `/hives/<code>/` | একটা বাক্স (যেমন MK-001) |
| GET/POST | `/hives/<code>/events/` | বাক্সের ইতিহাস |
| GET/POST | `/hives/<code>/queens/` | রানী বসানো ও বদল · procedure |
| POST | `/hives/<code>/move/` | বাক্স অন্য খামারে সরানো · procedure |
| GET/POST | `/inspections/?hive=<code>` | পরিদর্শন · procedure |
| GET/POST | `/harvests/?hive=<code>` | মধু সংগ্রহ · procedure |

### সতর্কতা ও কমিউনিটি
| Method | URL | কাজ |
|--------|-----|-----|
| GET | `/notifications/` | নিজের সতর্কতা |
| POST | `/notifications/read-all/` | সব পড়া চিহ্ন |
| GET/POST | `/spray-alerts/` | কৃষকের স্প্রে নোটিশ → এলাকার খামারিদের সতর্কতা |
| GET/POST | `/community/posts/?category=&tag=` | পোস্ট |
| POST | `/community/posts/<id>/upvote/` | upvote (একজন একবার) |
| POST | `/community/posts/<id>/comments/` | মন্তব্য |

### তথ্যভাণ্ডার (সব খোলা)
| Method | URL | কাজ |
|--------|-----|-----|
| GET | `/diseases/` | রোগ — লক্ষণ, ধাপে ধাপে চিকিৎসা ও প্রতিরোধ সহ |
| GET | `/disease-symptoms/` | রোগ ↔ লক্ষণ এক সারিতে · ভিউ |
| GET | `/symptoms/` | লক্ষণের তালিকা `{কোড: নাম}` |
| GET | `/flora/` | ফুল ও কোন মাসে ফোটে |
| GET | `/months/` · `/crops/` · `/bee-species/` | lookup তালিকা |
| GET | `/outbreaks/` | গত ৩০ দিনে এলাকার রোগ (পরিদর্শন থেকে গোনা) · ভিউ |
| GET | `/farmers/?district=&upazila=&flora=` | খামারি তালিকা · ভিউ |
| GET | `/map-farmers/` | ম্যাপের জন্য একই তথ্য · ভিউ |

**· ভিউ** চিহ্নিত endpoint গুলো ORM ব্যবহার করে না — সরাসরি
`sql/05_views.sql`-এর ভিউ থেকে পড়ে। CRUD-এর জন্য ORM (যাচাই,
serializer, অনুমতি), আর হিসাব করা সংখ্যার জন্য ভিউ — তাই হিসাবটা এক
জায়গায় থাকে, অ্যাপ আর SQL দুই দিক থেকেই একই উত্তর আসে।

**· procedure** চিহ্নিত endpoint গুলো `sql/07_procedures.sql`-এর
procedure ডাকে। যেসব কাজে কয়েকটা টেবিল একসাথে বদলাতে হয় (পরিদর্শন
লেখা + রোগ বসানো + বাক্সের অবস্থা + ইতিহাস) সেগুলো Python-এ লেখা ছিল;
এখন procedure-এ, একটা transaction-এ। ভুল ডাটায় procedure
`SIGNAL SQLSTATE '45000'` দিয়ে বাংলা বার্তা পাঠায়, আর সেটা অ্যাপে
৪০০-র `detail` হয়ে পৌঁছায় — তাই নিয়মটা দুই জায়গায় আলাদা করে লেখা নেই।

**যে কাজগুলো Python-এ আর নেই — trigger করে** (`sql/08_triggers.sql`):

| কাজ | কোন trigger |
|---|---|
| স্প্রে নোটিশ → ওই উপজেলার সব খামারিকে সতর্কতা | `trg_spray_alert_fanout` |
| `posts.upvote_count`-এর গণনা | `trg_post_vote_after_insert/delete` |
| বেশি ঝুঁকির রোগ পেলে মালিককে সতর্কতা | `trg_inspection_disease_notify` |
| রানীহীন বাক্সে রানী বসলে অবস্থা বদল | `trg_queen_after_insert` |
| বাক্স ও মধুর প্রতিটা বদল-মোছা `audit_log`-এ | ৪টা audit trigger |

`audit_log`-এ "কে বদলাল" বসানোর জন্য `apps/trust/middleware.py` প্রতিটা
request-এ `SET @app_user_id = <id>` চালায়, আর trigger সেটা পড়ে। কেউ
অ্যাপ বাইপাস করে সরাসরি SQL দিলে variable ফাঁকা থাকে — তখন actor NULL,
অর্থাৎ "অ্যাপের বাইরে থেকে বদলানো হয়েছে"।

## ফোল্ডার

```
moukamar_backend/
├── apps/
│   ├── locations/   # districts, upazilas
│   ├── accounts/    # users + farmer_profiles + cropper_profiles
│   ├── reference/   # months, crops, bee_species, flora, symptoms, diseases
│   ├── farms/       # farms, hives, queens, inspections, harvests
│   ├── alerts/      # spray_alerts, notifications
│   ├── community/   # posts, tags, comments, votes
│   ├── trust/       # audit_log
│   └── common.py    # বাংলা সংখ্যা ও তারিখ
├── sql/             # ডিজাইন, ডাটাবেজ তৈরি, seed  (পরে: view, procedure, trigger)
├── queries/         # topic অনুযায়ী query — viva-র জন্য
├── db.ps1           # SQL চালানোর সহজ উপায়
└── verify_api.py    # পুরো API একবারে যাচাই
```
