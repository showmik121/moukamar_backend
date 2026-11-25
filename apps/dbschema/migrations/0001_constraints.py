"""sql/02_constraints.sql — ব্যবসার নিয়মগুলো CHECK constraint হিসেবে।

সব app-এর টেবিল তৈরি হওয়ার পর চলতে হবে, তাই প্রতিটার উপর নির্ভরতা।
"""

from django.db import migrations

from apps.dbschema.sqlfiles import sql_file_operation


class Migration(migrations.Migration):

    dependencies = [
        ('locations', '0001_initial'),
        ('accounts', '0001_initial'),
        ('reference', '0001_initial'),
        ('farms', '0001_initial'),
        ('alerts', '0001_initial'),
        ('community', '0001_initial'),
        ('trust', '0001_initial'),
    ]

    operations = [
        sql_file_operation('02_constraints.sql', '02_constraints_down.sql'),
    ]
