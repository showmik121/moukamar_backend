"""sql/04_fk_actions.sql — প্রতিটা FOREIGN KEY-র ON DELETE নিয়ম স্পষ্ট করা।

Django model-এ `on_delete=CASCADE` লেখা থাকলেও সেটা Python-এ হয়,
ডাটাবেজে বসে না। এই migration সেটা ডাটাবেজেও বসিয়ে দেয়।
"""

from django.db import migrations

from apps.dbschema.sqlfiles import sql_file_operation


class Migration(migrations.Migration):

    dependencies = [
        ('dbschema', '0002_indexes'),
    ]

    operations = [
        sql_file_operation('04_fk_actions.sql', '04_fk_actions_down.sql'),
    ]
