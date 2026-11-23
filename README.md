# মৌখামার — Django Backend

## ইনস্টল করুন

```bash
# ১. Python 3.11+ ও MySQL ইনস্টল আছে ধরে নিচ্ছি

# ২. Virtual environment তৈরি করুন
python -m venv venv
venv\Scripts\activate   # Windows

# ৩. প্যাকেজ ইনস্টল করুন
pip install -r requirements.txt

# ৪. MySQL-এ database তৈরি করুন
mysql -u root -p < setup_db.sql

# ৫. settings.py-তে MySQL পাসওয়ার্ড দিন
# DATABASES > PASSWORD = 'আপনার_পাসওয়ার্ড'

# ৬. Migration চালান
python manage.py makemigrations
python manage.py migrate

# ৭. Admin user তৈরি করুন
python manage.py createsuperuser

# ৮. Server চালু করুন
python manage.py runserver 8000
```

## Electron app-এর সাথে সংযোগ

```bash
# Backend চালু রেখে Electron চালু করুন
MK_BACKEND_URL=http://127.0.0.1:8000 npm start
```

## API Endpoints

| Method | URL | কাজ |
|--------|-----|-----|
| POST | /api/auth/register/ | নিবন্ধন |
| POST | /api/auth/login/ | লগ ইন |
| POST | /api/auth/logout/ | লগ আউট |
| GET/PATCH | /api/auth/me/ | প্রোফাইল |
| GET | /api/dashboard/ | ড্যাশবোর্ড তথ্য |
| GET/POST | /api/farms/ | খামার |
| GET/POST | /api/hives/ | বাক্স |
| GET/POST | /api/inspections/ | পরিদর্শন |
| GET/POST | /api/harvests/ | মধু সংগ্রহ |
| GET | /api/notifications/ | সতর্কতা |
| POST | /api/notifications/read-all/ | সব পড়া |
| POST | /api/spray-alerts/ | স্প্রে নোটিশ |
| GET/POST | /api/community/posts/ | পোস্ট |
| GET | /api/diseases/ | রোগ তালিকা |
| GET | /api/flora/ | ফুলের ক্যালেন্ডার |
| GET | /api/farmers/ | খামারি তালিকা |
