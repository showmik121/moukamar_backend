"""audit_log-এর trigger যাতে জানতে পারে কে সারিটা বদলাল।

সমস্যা: `sql/08_triggers.sql`-এর audit trigger গুলো ডাটাবেজের ভেতরে
চলে, আর ডাটাবেজ অ্যাপের লগ-ইন করা ব্যবহারকারীকে চেনে না।

সমাধান: প্রতিটা request-এর শুরুতে `SET @app_user_id = <id>` চালানো হয়।
trigger ওই session variable পড়ে audit_log.actor_id-তে বসায়। কেউ
সরাসরি SQL দিয়ে বদলালে variable-টা ফাঁকা থাকে, তখন actor NULL হয় —
সেটাও একটা তথ্য: "অ্যাপের বাইরে থেকে বদলানো হয়েছে"।

খরচ: প্রতি request-এ একটা বাড়তি ছোট query। নিরীক্ষার হিসাব রাখার
জন্য এটা সস্তা।
"""

from django.db import connection


class AuditUserMiddleware:
    """ডাটাবেজ session-এ চলতি ব্যবহারকারীর id বসায়।

    AuthenticationMiddleware-এর পরে বসাতে হবে, নাহলে request.user থাকে না।
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        user = getattr(request, 'user', None)
        user_id = user.id if (user is not None and user.is_authenticated) else None

        try:
            with connection.cursor() as cursor:
                cursor.execute('SET @app_user_id = %s', [user_id])
        except Exception:
            # ডাটাবেজ না থাকলেও অ্যাপ যেন ৫০০ না দেয় — নিরীক্ষার
            # actor তখন NULL হবে, কিন্তু request চলবে
            pass

        return self.get_response(request)
