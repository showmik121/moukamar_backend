"""sql/03_indexes.sql — FULLTEXT, covering ও composite index।"""

from django.db import migrations

from apps.dbschema.sqlfiles import sql_file_operation


class Migration(migrations.Migration):

    dependencies = [
        ('dbschema', '0001_constraints'),
    ]

    operations = [
        sql_file_operation('03_indexes.sql', '03_indexes_down.sql'),
    ]
