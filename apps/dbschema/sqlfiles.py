"""`sql/` ফোল্ডারের হাতে লেখা SQL ফাইল migration থেকে চালানোর ব্যবস্থা।

কেন দরকার:
  টেবিল, PK, FK, UNIQUE — এগুলো Django migration বানায়। কিন্তু CHECK,
  FULLTEXT index, VIEW, FUNCTION, PROCEDURE, TRIGGER আর EVENT ORM থেকে
  বলা যায় না। সেগুলো `sql/`-এ হাতে লেখা আছে, আর এই app-এর migration
  সেই ফাইলগুলো চালায়।

  ফলে `python manage.py migrate` একটা কমান্ডেই পুরো ডাটাবেজ দাঁড়িয়ে
  যায় — টেবিল থেকে trigger পর্যন্ত। আর SQL গুলো আলাদা পড়ার মতো
  ফাইলেই থাকে, course-এ জমা দেওয়ার জন্য।
"""

from pathlib import Path

from django.conf import settings
from django.db import migrations

SQL_DIR = Path(settings.BASE_DIR) / 'sql'


def split_statements(text):
    """SQL লেখা থেকে একটা একটা statement বের করে।

    MySQL-এর driver একবারে একটাই statement নেয়, তাই ফাইলটা ভাগ করতে হয়।
    `DELIMITER $$` মানা হয় — procedure ও trigger-এর ভেতরে `;` থাকে,
    সেগুলো যেন মাঝখানে কাটা না পড়ে।

    সীমা: string literal-এর ভেতরে delimiter থাকলে এই ভাগ করা ভুল হবে।
    আমাদের ফাইলগুলোতে সেরকম নেই; নতুন SQL লেখার সময় মনে রাখা দরকার।
    """
    delimiter = ';'
    buffer = []
    statements = []

    for raw_line in text.splitlines():
        line = raw_line.strip()

        # DELIMITER নিজে SQL নয়, mysql client-এর নির্দেশ
        if line.upper().startswith('DELIMITER '):
            if buffer:
                statements.append('\n'.join(buffer))
                buffer = []
            delimiter = line.split(None, 1)[1].strip()
            continue

        # শুধু মন্তব্যের লাইন — statement শুরু না হলে বাদ
        if not buffer and (not line or line.startswith('--')):
            continue

        buffer.append(raw_line)

        if line.endswith(delimiter):
            joined = '\n'.join(buffer).rstrip()
            joined = joined[: -len(delimiter)].rstrip()
            if joined:
                statements.append(joined)
            buffer = []

    if buffer:
        leftover = '\n'.join(buffer).strip()
        if leftover:
            statements.append(leftover)

    return [s for s in statements if s.strip()]


def run_sql_file(filename):
    """একটা `.sql` ফাইল চালানোর callable ফেরত দেয় (RunPython-এর জন্য)।"""

    def _run(apps, schema_editor):
        path = SQL_DIR / filename
        if not path.exists():
            raise FileNotFoundError(f'SQL ফাইল পাওয়া যায়নি: {path}')
        sql = path.read_text(encoding='utf-8')
        with schema_editor.connection.cursor() as cursor:
            for statement in split_statements(sql):
                cursor.execute(statement)
                # ফাইলের শেষে যাচাইয়ের SELECT থাকে — ফলাফল পড়ে না ফেললে
                # পরের statement-এ "Commands out of sync" আসে
                if cursor.description is not None:
                    cursor.fetchall()

    _run.__name__ = f'run_{filename.replace(".", "_").replace("-", "_")}'
    return _run


def sql_file_operation(up_file, down_file=None):
    """`sql/<up_file>` চালায়, উল্টো দিকে `sql/<down_file>`।"""
    return migrations.RunPython(
        run_sql_file(up_file),
        run_sql_file(down_file) if down_file else migrations.RunPython.noop,
    )
