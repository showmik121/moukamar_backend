"""sql/05_views.sql — ৮টা ভিউ।

আগে Python-এ করা হিসাব আর কলামে জমানো derived মান — দুটোই এখন ভিউতে,
তাই অ্যাপ আর সরাসরি SQL দুই দিক থেকেই একই উত্তর আসে।
"""

from django.db import migrations

from apps.dbschema.sqlfiles import sql_file_operation


class Migration(migrations.Migration):

    dependencies = [
        ('dbschema', '0003_fk_actions'),
    ]

    operations = [
        sql_file_operation('05_views.sql', '05_views_down.sql'),
    ]
