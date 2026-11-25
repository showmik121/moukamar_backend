import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent


def load_env(path=BASE_DIR / '.env'):
    """.env ফাইল পড়ে os.environ-এ বসায় (বাইরের কোনো প্যাকেজ লাগে না)।

    আগে থেকে সেট করা environment variable বদলায় না — তাই
    `$env:DB_PASSWORD="..."` দিয়ে চালালে সেটাই আগে।
    """
    if not path.exists():
        return
    for line in path.read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        key, _, value = line.partition('=')
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


load_env()

SECRET_KEY = os.environ.get('SECRET_KEY', 'moukhamar-django-insecure-dev-key')
DEBUG = os.environ.get('DEBUG', 'True').lower() in ('1', 'true', 'yes')
ALLOWED_HOSTS = ['localhost', '127.0.0.1', '*']

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'corsheaders',
    'apps.locations',
    'apps.accounts',
    'apps.reference',
    'apps.farms',
    'apps.alerts',
    'apps.community',
    'apps.trust',
    # শুধু migration রাখে — sql/ ফোল্ডারের হাতে লেখা CHECK, index, view,
    # procedure, trigger ও event এখান থেকে চলে (কোনো model নেই)
    'apps.dbschema',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    # AuthenticationMiddleware-এর পরে থাকতে হবে — audit_log-এর trigger
    # যাতে জানে কে সারিটা বদলাল (sql/08_triggers.sql দেখুন)
    'apps.trust.middleware.AuditUserMiddleware',
]

ROOT_URLCONF = 'moukhamar.urls'

TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [],
    'APP_DIRS': True,
    'OPTIONS': {
        'context_processors': [
            'django.template.context_processors.debug',
            'django.template.context_processors.request',
            'django.contrib.auth.context_processors.auth',
            'django.contrib.messages.context_processors.messages',
        ],
    },
}]

WSGI_APPLICATION = 'moukhamar.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': os.environ.get('DB_NAME', 'moukhamar_db'),
        'USER': os.environ.get('DB_USER', 'root'),
        'PASSWORD': os.environ.get('DB_PASSWORD', ''),   # .env ফাইলে দিন
        'HOST': os.environ.get('DB_HOST', '127.0.0.1'),
        'PORT': os.environ.get('DB_PORT', '3306'),
        'OPTIONS': {
            'charset': 'utf8mb4',
            'init_command': "SET sql_mode='STRICT_TRANS_TABLES'",
        },
    }
}

AUTH_USER_MODEL = 'accounts.User'

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.SessionAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    'DEFAULT_RENDERER_CLASSES': [
        'rest_framework.renderers.JSONRenderer',
    ],
}

CORS_ALLOW_ALL_ORIGINS = True  # production-এ নির্দিষ্ট origin দিন
CORS_ALLOW_CREDENTIALS = True

LANGUAGE_CODE = 'bn'
TIME_ZONE = 'Asia/Dhaka'
USE_I18N = True
USE_TZ = True

AUTHENTICATION_BACKENDS = [
    'apps.accounts.backends.PhoneOrEmailBackend',
    'django.contrib.auth.backends.ModelBackend',
]

STATIC_URL = '/static/'
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

SESSION_COOKIE_AGE = 60 * 60 * 24 * 7  # ৭ দিন
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = 'Lax'
CSRF_COOKIE_SAMESITE = 'Lax'
