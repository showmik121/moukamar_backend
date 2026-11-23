@echo off
chcp 65001 > nul
echo ===================================================
echo   মৌখামার (Moukhamar) - Django Backend সার্ভার
echo ===================================================
echo.

cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
    echo [!] ভার্চুয়াল এনভায়রনমেন্ট তৈরি করা হচ্ছে...
    py -3.12 -m venv .venv
    call .venv\Scripts\activate.bat
    pip install -r requirements.txt pymysql
)

echo [✓] ডাটাবেজ মাইগ্রেশন প্রস্তুত করা হচ্ছে...
.venv\Scripts\python.exe manage.py makemigrations accounts farms alerts community reference >nul 2>&1

echo [✓] ডাটাবেজ টেবিল আপডেট করা হচ্ছে...
.venv\Scripts\python.exe manage.py migrate

echo.
echo [✓] Django সার্ভার চালু হচ্ছে: http://127.0.0.1:8000
echo (সার্ভার বন্ধ করতে Ctrl+C চাপুন)
echo.
.venv\Scripts\python.exe manage.py runserver 127.0.0.1:8000
pause
