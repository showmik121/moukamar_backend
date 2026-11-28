"""জেলা-উপজেলার নাম থেকে Upazila সারি বের করার সহায়ক।

frontend (bd-locations.js) নাম পাঠায়, ডাটাবেজ id চায় — এই ফাঁকটা
এখানে একবারই পূরণ করা হয়েছে, যাতে প্রতিটা view-তে বারবার লিখতে না হয়।
"""

from .models import District, Upazila


def resolve_upazila(district_name, upazila_name):
    """নাম দিয়ে Upazila ফেরত দেয়; তালিকায় না থাকলে None।

    শুধু খোঁজে, তৈরি করে না। আগে অচেনা নাম এলে নতুন জেলা/উপজেলা বানিয়ে
    ফেলত — ভুল encoding-এ আসা "?????" বা বানান ভুলও স্থায়ী জেলা হয়ে
    যেত। seed-এ ৬৪ জেলা ও ৫০১ উপজেলা আছে, frontend-এর তালিকাও সেটাই;
    তালিকার বাইরের নাম হলে ডাকা জায়গাটা বাংলা বার্তা দিয়ে আটকায়।
    উপজেলা ফাঁকা থাকলে ওই জেলার "সদর" উপজেলা।
    """
    district_name = (district_name or '').strip()
    upazila_name = (upazila_name or '').strip() or 'সদর'
    if not district_name:
        return None
    return Upazila.objects.filter(district__name=district_name, name=upazila_name).first()


def district_point(district_name):
    """জেলার lat/lng — নতুন খামারের অবস্থান বসানোর জন্য।

    আগে এটা কোডে DISTRICT_COORDS নামে hardcoded ছিল (আর সেই import-ই
    ভেঙে নিবন্ধনের খামার তৈরি চুপচাপ fail করত)। এখন districts টেবিল থেকে।
    """
    district = District.objects.filter(name=(district_name or '').strip()).first()
    if district and district.lat is not None and district.lng is not None:
        return district.lat, district.lng
    return None, None
