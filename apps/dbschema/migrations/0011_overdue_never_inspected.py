"""sql/07_procedures.sql আর sql/09_events.sql আবার চালানো।

পরিবর্তন: কখনো পরিদর্শন না হওয়া বাক্সে `days_since_inspection` NULL
আসে। আগে `IF(v_days >= 999, …)` NULL-এ মিথ্যা হতো আর CONCAT পুরো
বার্তাটাই NULL করে দিত — notifications.body NOT NULL বলে
sp_notify_overdue_inspections আর রাতের ev_nightly_overdue_alerts দুটোই
ভেঙে যেত (নতুন বাক্স যোগ করলেই "সতর্কতা পাঠান" বোতাম ৪০০ দিত)।

দুটো ফাইলই `DROP … IF EXISTS` দিয়ে শুরু, তাই আবার চালানো নিরাপদ।
"""

from django.db import migrations

from apps.dbschema.sqlfiles import run_sql_file


class Migration(migrations.Migration):

    dependencies = [
        ('dbschema', '0010_procedures_backdated_inspection'),
    ]

    operations = [
        migrations.RunPython(run_sql_file('07_procedures.sql'), migrations.RunPython.noop),
        migrations.RunPython(run_sql_file('09_events.sql'), migrations.RunPython.noop),
    ]
