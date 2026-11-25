"""sql/09_events.sql — ৩টা scheduled EVENT।"""

from django.db import migrations

from apps.dbschema.sqlfiles import sql_file_operation


class Migration(migrations.Migration):

    dependencies = [
        ('dbschema', '0007_triggers'),
    ]

    operations = [
        sql_file_operation('09_events.sql', '09_events_down.sql'),
    ]
