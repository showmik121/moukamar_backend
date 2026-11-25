"""সব app-এ ব্যবহার হওয়া ছোট সহায়ক।

দুটো জিনিস এখানে:
  ১. বাংলা সংখ্যা ও তারিখ — অ্যাপের পর্দায় সব সংখ্যা বাংলায় দেখানো
     হয়। frontend-এর নিজের bn() আছে, তবু কিছু জায়গায় (যেমন খামারির
     নিবন্ধনের তারিখ) সার্ভার সাজানো লেখা পাঠায়।
  ২. ভিউ থেকে পড়া — রিপোর্টের endpoint গুলো ORM ব্যবহার করে না,
     সরাসরি `sql/05_views.sql`-এর ভিউ থেকে পড়ে। dict_rows() সেই
     কাজটা করে: query চালিয়ে প্রতিটা সারি dict হিসেবে ফেরত দেয়।
  ৩. PROCEDURE ডাকা — call_proc() `sql/07_procedures.sql`-এর procedure
     চালায় আর OUT মানগুলো ফেরত দেয়। procedure SIGNAL দিয়ে ব্যবসার ভুল
     জানালে সেটা DRF-এর ValidationError হয়ে যায়, তাই অ্যাপে
     procedure-এর লেখা বাংলা বার্তাটাই দেখা যায়।
"""

from decimal import Decimal

from django.db import DatabaseError, connection
from rest_framework.exceptions import ValidationError

BN_DIGITS = '০১২৩৪৫৬৭৮৯'

BN_MONTHS = [
    'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
    'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
]


def bn_digits(value):
    """ইংরেজি অঙ্ককে বাংলা অঙ্কে — bn_digits(১৫) → '১৫'।"""
    return ''.join(BN_DIGITS[int(ch)] if ch.isdigit() else ch for ch in str(value))


def bn_date(value):
    """date/datetime → '১৫ জানুয়ারি ২০২৫'। None হলে খালি string।"""
    if not value:
        return ''
    return f'{bn_digits(value.day)} {BN_MONTHS[value.month - 1]} {bn_digits(value.year)}'


def dict_rows(sql, params=None):
    """SQL চালিয়ে প্রতিটা সারি dict হিসেবে ফেরত দেয়।

    ভিউ থেকে পড়ার জন্য। প্যারামিটার সবসময় %s দিয়ে পাঠাতে হবে —
    string জোড়া লাগিয়ে query বানালে SQL injection-এর পথ খুলে যায়।
    """
    with connection.cursor() as cursor:
        cursor.execute(sql, params or [])
        columns = [col[0] for col in cursor.description]
        return [dict(zip(columns, row)) for row in cursor.fetchall()]


def dict_row(sql, params=None):
    """একটাই সারি দরকার হলে — না পেলে None।"""
    rows = dict_rows(sql, params)
    return rows[0] if rows else None


def num(value, default=0):
    """Decimal / None → সাধারণ সংখ্যা (JSON-এ পাঠানোর জন্য)।"""
    if value is None:
        return default
    if isinstance(value, Decimal):
        return float(value)
    return value


def split_list(value):
    """GROUP_CONCAT-এর ফল ('সরিষা, লিচু') → তালিকা (['সরিষা', 'লিচু'])।"""
    if not value:
        return []
    return [part.strip() for part in str(value).split(',') if part.strip()]


def proc_message(exc):
    """ডাটাবেজের ভুল থেকে পড়ার মতো বার্তা বের করে।

    procedure-এর `SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '...'`
    driver-এ (1644, 'বাংলা বার্তা') হয়ে আসে — দ্বিতীয় অংশটাই দরকার।
    """
    args = getattr(exc, 'args', ())
    if len(args) > 1 and args[1]:
        return str(args[1])
    return str(exc)


def call_proc(sql, params=None, out_names=None):
    """CALL ... চালায় আর OUT মানগুলো dict হিসেবে ফেরত দেয়।

    out_names দিলে ধরে নেওয়া হয় CALL-এ `@নাম` বসানো আছে, যেমন:
        call_proc('CALL sp_add_harvest(%s, %s, @hid)', [a, b], ['hid'])

    procedure ব্যবসার ভুল জানালে ValidationError ওঠে — DRF সেটাকে
    ৪০০ সহ JSON বার্তা বানিয়ে অ্যাপে পাঠায়।
    """
    try:
        with connection.cursor() as cursor:
            cursor.execute(sql, params or [])
            # procedure-এর শেষে SELECT থাকলে ফলাফল পড়ে ফেলতে হয়,
            # নাহলে পরের query-তে "Commands out of sync" আসে
            if cursor.description is not None:
                cursor.fetchall()
            while cursor.nextset():
                if cursor.description is not None:
                    cursor.fetchall()

            if not out_names:
                return {}

            cursor.execute('SELECT ' + ', '.join(f'@{name}' for name in out_names))
            row = cursor.fetchone()
            return dict(zip(out_names, row))
    except DatabaseError as exc:
        raise ValidationError({'detail': proc_message(exc)})
