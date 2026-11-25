"""জেলা-উপজেলার নাম থেকে Upazila সারি বের করার সহায়ক।

frontend (bd-locations.js) নাম পাঠায়, ডাটাবেজ id চায় — এই ফাঁকটা
এখানে একবারই পূরণ করা হয়েছে, যাতে প্রতিটা view-তে বারবার লিখতে না হয়।
"""

from .models import District, Upazila


def resolve_upazila(district_name, upazila_name):
    """নাম দিয়ে Upazila ফেরত দেয়। না থাকলে তৈরি করে।

    seed-এ ৬৪ জেলা ও উপজেলা আছে, তবু কেউ তালিকার বাইরের নাম পাঠালে
    নিবন্ধন আটকে যাওয়ার চেয়ে সারিটা তৈরি করে নেওয়াই ভালো।
    """
    district_name = (district_name or '').strip()
    upazila_name = (upazila_name or '').strip()
    if not district_name:
        return None

    district, _ = District.objects.get_or_create(name=district_name)
    if not upazila_name:
        upazila_name = 'সদর'
    upazila, _ = Upazila.objects.get_or_create(district=district, name=upazila_name)
    return upazila


def district_point(district_name):
    """জেলার lat/lng — নতুন খামারের অবস্থান বসানোর জন্য।

    আগে এটা কোডে DISTRICT_COORDS নামে hardcoded ছিল (আর সেই import-ই
    ভেঙে নিবন্ধনের খামার তৈরি চুপচাপ fail করত)। এখন districts টেবিল থেকে।
    """
    district = District.objects.filter(name=(district_name or '').strip()).first()
    if district and district.lat is not None and district.lng is not None:
        return district.lat, district.lng
    return None, None
