"""চলতি ডাটাবেজ থেকে ER ডায়াগ্রাম ও টেবিলের তালিকা বানায়।

হাতে আঁকা ডায়াগ্রাম পুরনো হয়ে যায় — কোনো কলাম যোগ করলে ছবিটা আর
মেলে না। এই script information_schema থেকে পড়ে, তাই যা বের হয় সেটা
ডাটাবেজে যা আছে তাই।

চালান (backend ফোল্ডার থেকে):
    .venv\\Scripts\\python.exe sql\\gen_erd.py

লেখে: sql/ERD.md — mermaid ডায়াগ্রাম, GitHub-এ ছবি হয়ে দেখায়।
MySQL Workbench-এর Database → Reverse Engineer দিয়েও ছবি বের করা যায়;
সেটা ছাপানোর জন্য ভালো, আর এটা রিপোর্টে বসানোর জন্য।
"""

import io
import os
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'moukhamar.settings')

import django  # noqa: E402

django.setup()

from django.db import connection  # noqa: E402

# Django-র নিজের টেবিল ডায়াগ্রামে দেখানোর দরকার নেই
SKIP_PREFIXES = ('django_', 'auth_', 'users_groups', 'users_user_permissions')

GROUPS = [
    ('এলাকা', ['districts', 'upazilas']),
    ('মানুষ', ['users', 'farmer_profiles', 'cropper_profiles']),
    ('খামার ও বাক্স', ['farms', 'farm_flora', 'hives', 'queens', 'hive_events']),
    ('পরিদর্শন ও রোগ', ['inspections', 'inspection_diseases', 'diseases',
                         'disease_symptoms', 'disease_steps', 'symptoms']),
    ('মধু ও ফুল', ['harvests', 'flora', 'flora_blooms', 'months']),
    ('সতর্কতা', ['spray_alerts', 'notifications', 'crops']),
    ('কমিউনিটি', ['posts', 'tags', 'post_tags', 'post_votes', 'comments']),
    ('তথ্যভাণ্ডার', ['bee_species']),
    ('নিরীক্ষা', ['audit_log']),
]


def rows(sql, params=None):
    with connection.cursor() as cursor:
        cursor.execute(sql, params or [])
        cols = [c[0] for c in cursor.description]
        return [dict(zip(cols, r)) for r in cursor.fetchall()]


def skip(name):
    return any(name.startswith(p) for p in SKIP_PREFIXES)


def main():
    tables = [r['TABLE_NAME'] for r in rows("""
        SELECT TABLE_NAME FROM information_schema.TABLES
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'BASE TABLE'
         ORDER BY TABLE_NAME
    """) if not skip(r['TABLE_NAME'])]

    fks = [r for r in rows("""
        SELECT kcu.TABLE_NAME, kcu.COLUMN_NAME,
               kcu.REFERENCED_TABLE_NAME, kcu.REFERENCED_COLUMN_NAME,
               rc.DELETE_RULE,
               c.IS_NULLABLE
          FROM information_schema.KEY_COLUMN_USAGE kcu
          JOIN information_schema.REFERENTIAL_CONSTRAINTS rc
               ON rc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
              AND rc.CONSTRAINT_SCHEMA = kcu.TABLE_SCHEMA
          JOIN information_schema.COLUMNS c
               ON c.TABLE_SCHEMA = kcu.TABLE_SCHEMA
              AND c.TABLE_NAME = kcu.TABLE_NAME
              AND c.COLUMN_NAME = kcu.COLUMN_NAME
         WHERE kcu.TABLE_SCHEMA = DATABASE()
           AND kcu.REFERENCED_TABLE_NAME IS NOT NULL
         ORDER BY kcu.TABLE_NAME, kcu.COLUMN_NAME
    """) if not skip(r['TABLE_NAME']) and not skip(r['REFERENCED_TABLE_NAME'])]

    cols = rows("""
        SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY
          FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE()
         ORDER BY TABLE_NAME, ORDINAL_POSITION
    """)
    by_table = {}
    for c in cols:
        by_table.setdefault(c['TABLE_NAME'], []).append(c)

    out = []
    out.append('# মৌখামার — ER ডায়াগ্রাম ও টেবিলের তালিকা')
    out.append('')
    out.append('> এই ফাইলটা হাতে লেখা নয় — `sql/gen_erd.py` চলতি ডাটাবেজের')
    out.append('> `information_schema` থেকে পড়ে বানায়। schema বদলালে আবার')
    out.append('> চালালেই হালনাগাদ হয়ে যায়।')
    out.append('')
    out.append(f'**টেবিল:** {len(tables)}টি · **সম্পর্ক (FOREIGN KEY):** {len(fks)}টি')
    out.append('')
    out.append('ছাপানোর জন্য ছবি দরকার হলে MySQL Workbench-এ')
    out.append('*Database → Reverse Engineer* দিলে নিজে এঁকে দেয়।')
    out.append('')

    # ---- mermaid ডায়াগ্রাম ----
    out.append('## ER ডায়াগ্রাম')
    out.append('')
    out.append('```mermaid')
    out.append('erDiagram')
    for fk in fks:
        # সন্তানের কলাম NULL হতে পারলে সম্পর্কটা ঐচ্ছিক
        left = '|o' if fk['IS_NULLABLE'] == 'YES' else '||'
        label = fk['COLUMN_NAME']
        if label.endswith('_id'):
            label = label[:-3]
        out.append(f"    {fk['REFERENCED_TABLE_NAME']} {left}--o{{ "
                   f"{fk['TABLE_NAME']} : {label}")
    out.append('```')
    out.append('')
    out.append('`||--o{` মানে মা-সারি থাকতেই হবে, `|o--o{` মানে ঐচ্ছিক (NULL চলে)।')
    out.append('')

    # ---- ON DELETE তালিকা ----
    out.append('## FOREIGN KEY-র ON DELETE নিয়ম')
    out.append('')
    out.append('| সন্তান | কলাম | মা-টেবিল | মা-সারি মুছলে |')
    out.append('|---|---|---|---|')
    rule_bn = {'CASCADE': 'সন্তানও মুছবে', 'SET NULL': 'ফাঁকা হবে',
               'RESTRICT': 'মোছাই যাবে না', 'NO ACTION': 'মোছাই যাবে না'}
    for fk in sorted(fks, key=lambda f: (f['DELETE_RULE'], f['TABLE_NAME'])):
        out.append(f"| `{fk['TABLE_NAME']}` | `{fk['COLUMN_NAME']}` | "
                   f"`{fk['REFERENCED_TABLE_NAME']}` | "
                   f"{fk['DELETE_RULE']} — {rule_bn.get(fk['DELETE_RULE'], '')} |")
    out.append('')

    # ---- টেবিলের কলাম ----
    out.append('## টেবিলের কলাম')
    out.append('')
    seen = set()
    for group_name, group_tables in GROUPS:
        present = [t for t in group_tables if t in by_table]
        if not present:
            continue
        out.append(f'### {group_name}')
        out.append('')
        for table in present:
            seen.add(table)
            out.append(f'**`{table}`**')
            out.append('')
            out.append('| কলাম | ধরন | NULL | key |')
            out.append('|---|---|---|---|')
            for c in by_table[table]:
                key = {'PRI': 'PK', 'UNI': 'UNIQUE', 'MUL': 'index'}.get(c['COLUMN_KEY'], '')
                null = 'হ্যাঁ' if c['IS_NULLABLE'] == 'YES' else '—'
                out.append(f"| `{c['COLUMN_NAME']}` | {c['COLUMN_TYPE']} | {null} | {key} |")
            out.append('')

    extra = [t for t in tables if t not in seen]
    if extra:
        out.append('### অন্যান্য')
        out.append('')
        for table in extra:
            out.append(f'- `{table}`')
        out.append('')

    target = BASE / 'sql' / 'ERD.md'
    io.open(target, 'w', encoding='utf-8', newline='\n').write('\n'.join(out) + '\n')
    print(f'tables={len(tables)} foreign_keys={len(fks)}')
    print(f'written: {target}')


if __name__ == '__main__':
    main()
