"""sql/08_triggers.sql — ১২টা TRIGGER।

এই migration-এর সাথেই Python থেকে দুটো কাজ সরানো হয়েছে, কারণ এখন
trigger সেগুলো করে:
  • স্প্রে নোটিশ থেকে এলাকার খামারিদের সতর্কতা (apps/alerts/views.py)
  • posts.upvote_count-এর গণনা (apps/community/views.py)
একই নিয়ম দুই জায়গায় থাকলে কাজ দুবার হতো।
"""

from django.db import migrations

from apps.dbschema.sqlfiles import sql_file_operation


class Migration(migrations.Migration):

    dependencies = [
        ('dbschema', '0006_procedures'),
    ]

    operations = [
        sql_file_operation('08_triggers.sql', '08_triggers_down.sql'),
    ]
