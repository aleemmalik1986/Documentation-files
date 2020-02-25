#!/bin/bash -ex
yum -y update

yum install python3 httpd httpd-devel gcc mariadb-server python-devel mysql-devel python3-devel mariadb ruby aws-cli wget -y

mkdir /opt/django

python3 -m venv /opt/django/

cd /opt/django/

source /opt/django/bin/activate

pip3 install django

pip3 install mod-wsgi==4.7.1

pip3 install mysqlclient

systemctl start mariadb

systemctl enable mariadb

mysqladmin password 'root'
mysql --host=localhost --user=root --password=root -e 'DELETE FROM mysql.user WHERE User="";'
mysql --host=localhost --user=root --password=root -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql --host=localhost --user=root --password=root -e 'DROP DATABASE test;'
mysql --host=localhost --user=root --password=root -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
mysql --host=localhost --user=root --password=root -e 'FLUSH PRIVILEGES;'
mysql --host=localhost --user=root --password=root -e 'CREATE DATABASE djangoproject_db  CHARACTER SET UTF8;'
mysql --host=localhost --user=root --password=root -e 'CREATE USER django_db_user@localhost IDENTIFIED BY "djangodbuserpass";'
mysql --host=localhost --user=root --password=root -e 'GRANT ALL PRIVILEGES ON djangoproject_db.* TO django_db_user@localhost;'
mysql --host=localhost --user=root --password=root -e 'FLUSH PRIVILEGES;'

cd /opt/django/

source /opt/django/bin/activate

mkdir /var/log/httpd/django

mkdir /opt/django/run

mkdir /opt/django/run/static

django-admin startproject djangoproject

mv djangoproject src

cd src/djangoproject

wget https://raw.githubusercontent.com/aleemmalik1986/Documentation-files/master/django_mysql_settings.py

mv django_mysql_settings.py settings.py

wget https://raw.githubusercontent.com/aleemmalik1986/Documentation-files/master/django_mysql_wsgi.py

mv django_mysql_wsgi.py wsgi.py

wget https://raw.githubusercontent.com/aleemmalik1986/Documentation-files/master/httpd_django.conf

mv httpd_django.conf /etc/httpd/conf.d/django.conf

mod_wsgi-express module-config >> /etc/httpd/conf/httpd.conf

systemctl restart mariadb

systemctl start httpd

systemctl enable httpd
