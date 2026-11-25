"""sql/07_procedures.sql — ৬টা stored PROCEDURE।

transaction, SIGNAL, EXIT HANDLER, CURSOR, SAVEPOINT আর OUT প্যারামিটার —
সবগুলোই আসল কাজে ব্যবহার হয়েছে, দেখানোর জন্য আলাদা করে নয়।
"""

from django.db import migrations

from apps.dbschema.sqlfiles import sql_file_operation


class Migration(migrations.Migration):

    dependencies = [
        ('dbschema', '0005_functions'),
    ]

    operations = [
        sql_file_operation('07_procedures.sql', '07_procedures_down.sql'),
    ]
