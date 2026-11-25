"""sql/11_users_grants.sql — ৩টা ROLE আর ৩টা ডাটাবেজ ব্যবহারকারী।

এটা schema নয়, সার্ভারের অনুমতি — তবু migration-এ রাখা হলো যাতে
`migrate` একটা কমান্ডেই পুরো ডাটাবেজ দাঁড়িয়ে যায়। এই migration
চালাতে যে ব্যবহারকারী `migrate` চালাচ্ছে তার CREATE USER অনুমতি
লাগবে (root বা mk_owner)।
"""

from django.db import migrations

from apps.dbschema.sqlfiles import sql_file_operation


class Migration(migrations.Migration):

    dependencies = [
        ('dbschema', '0008_events'),
    ]

    operations = [
        sql_file_operation('11_users_grants.sql', '11_users_grants_down.sql'),
    ]
