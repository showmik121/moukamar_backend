"""sql/06_functions.sql — ৮টা stored FUNCTION।"""

from django.db import migrations

from apps.dbschema.sqlfiles import sql_file_operation


class Migration(migrations.Migration):

    dependencies = [
        ('dbschema', '0004_views'),
    ]

    operations = [
        sql_file_operation('06_functions.sql', '06_functions_down.sql'),
    ]
