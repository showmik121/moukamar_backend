"""sql/07_procedures.sql আবার চালানো — sp_record_inspection-এর পরিবর্তন।

পরিবর্তন: পুরনো তারিখের পরিদর্শন লিখলে বাক্সের চলতি অবস্থা (filled,
state) আর বদলায় না। procedure গুলো `DROP ... IF EXISTS` দিয়ে শুরু হয়,
তাই ফাইলটা আবার চালানো নিরাপদ।
"""

from django.db import migrations

from apps.dbschema.sqlfiles import run_sql_file


class Migration(migrations.Migration):

    dependencies = [
        ('dbschema', '0009_users_grants'),
    ]

    operations = [
        migrations.RunPython(run_sql_file('07_procedures.sql'), migrations.RunPython.noop),
    ]
