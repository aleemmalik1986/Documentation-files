"""
WSGI config for djangoproject project.

It exposes the WSGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/3.0/howto/deployment/wsgi/
"""

print("=======i am in wsgi.py========")
import os
import sys

sys.path.append("/opt/django/src")

from django.core.wsgi import get_wsgi_application

myapp = os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'djangoproject.settings')
print(myapp)
application = get_wsgi_application()
