#!/bin/bash -ex

echo "project directory: $1"

myproj=$1

yum -y update

yum install python3 httpd httpd-devel gcc mariadb-server python-devel mysql-devel python3-devel mariadb ruby aws-cli wget -y

mkdir /opt/$myproj

python3 -m venv /opt/$myproj/

cd /opt/$myproj/

source /opt/$myproj/bin/activate

pip3 install django

pip3 install mod-wsgi==4.7.1

pip3 install mysqlclient

systemctl start mariadb

systemctl enable mariadb

mysqladmin password 'root'
mysql --host=localhost --user=root --password=root -e "DELETE FROM mysql.user WHERE User='';"
mysql --host=localhost --user=root --password=root -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql --host=localhost --user=root --password=root -e 'DROP DATABASE test;'
mysql --host=localhost --user=root --password=root -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
mysql --host=localhost --user=root --password=root -e 'FLUSH PRIVILEGES;'
mysql --host=localhost --user=root --password=root -e "CREATE DATABASE $myproj CHARACTER SET UTF8;"
mysql --host=localhost --user=root --password=root -e "CREATE USER $myproj@localhost IDENTIFIED BY 'djangodbuserpass';"
mysql --host=localhost --user=root --password=root -e "GRANT ALL PRIVILEGES ON $myproj.* TO $myproj@localhost;"
mysql --host=localhost --user=root --password=root -e 'FLUSH PRIVILEGES;'

cd /opt/$myproj/

source /opt/$myproj/bin/activate

mkdir /var/log/httpd/$myproj

mkdir /opt/$myproj/run

mkdir /opt/$myproj/run/static

django-admin startproject $myproj

mv $myproj src

cd src/$myproj

#set setting.py for mysql
echo "============Now setting setting.py and database============="
wget https://raw.githubusercontent.com/aleemmalik1986/Documentation-files/master/django_mysql_config_settings.py


getpublicip=`curl http://169.254.169.254/latest/meta-data/public-ipv4`
echo "ALLOWED_HOSTS = ['$getpublicip']">>django_mysql_config_settings.py
echo "ROOT_URLCONF = '$myproj.urls'">>django_mysql_config_settings.py
echo "WSGI_APPLICATION = '$myproj.wsgi.application'">>django_mysql_config_settings.py

echo "DATABASES = {" >>django_mysql_config_settings.py
echo "	'default': {" >>django_mysql_config_settings.py
echo "	'ENGINE': 'django.db.backends.mysql'," >>django_mysql_config_settings.py
echo "	'NAME': '$myproj'," >>django_mysql_config_settings.py
echo "	'USER': '$myproj'," >>django_mysql_config_settings.py
echo "  'PASSWORD': 'djangodbuserpass'," >>django_mysql_config_settings.py
echo "  'HOST': 'localhost'," >>django_mysql_config_settings.py
echo "  'PORT': ''," >>django_mysql_config_settings.py
echo "	'OPTIONS': {">>django_mysql_config_settings.py
echo "  'init_command': \"SET sql_mode='STRICT_TRANS_TABLES'\",">>django_mysql_config_settings.py
echo "	}">>django_mysql_config_settings.py
echo "	}">>django_mysql_config_settings.py
echo "}">>django_mysql_config_settings.py

mv django_mysql_config_settings.py settings.py

#set project path in wsgi.py
echo "============Now setting wsgi.py============="
echo "$(echo "sys.path.append(\"/opt/$myproj/src\")" | cat - wsgi.py)" > wsgi.py
echo "$(echo "import sys" | cat - wsgi.py)" > wsgi.py
#configure httpd virtual host
echo "============Now setting apache virtual host============="
touch /etc/httpd/conf.d/$myproj.conf
echo "<VirtualHost *:80>" >> /etc/httpd/conf.d/$myproj.conf
echo "	ServerAdmin webmaster@localhost" >> /etc/httpd/conf.d/$myproj.conf
echo "	DocumentRoot /var/www/html" >> /etc/httpd/conf.d/$myproj.conf
echo "	ErrorLog /var/log/httpd/$myproj/error.log" >> /etc/httpd/conf.d/$myproj.conf
echo "	CustomLog /var/log/httpd/$myproj/access.log combined" >> /etc/httpd/conf.d/$myproj.conf


echo "	Alias /static /opt/$myproj/run/static" >> /etc/httpd/conf.d/$myproj.conf
echo "	<Directory /opt/$myproj/run/static>" >> /etc/httpd/conf.d/$myproj.conf
echo "		Require all granted   " >> /etc/httpd/conf.d/$myproj.conf
echo "	</Directory> "	>> /etc/httpd/conf.d/$myproj.conf

echo "	<Directory /opt/$myproj/src/$myproj>" >>/etc/httpd/conf.d/$myproj.conf
echo "		<Files wsgi.py>		" >> /etc/httpd/conf.d/$myproj.conf
echo "			Require all granted" >> /etc/httpd/conf.d/$myproj.conf
echo "		</Files> " >> /etc/httpd/conf.d/$myproj.conf
echo "	</Directory>" >> /etc/httpd/conf.d/$myproj.conf
echo "	LogLevel info" >> /etc/httpd/conf.d/$myproj.conf
echo "	WSGIDaemonProcess $myproj  python-path=/opt/$myproj:/opt/$myproj/lib/python3.7/site-packages" >> /etc/httpd/conf.d/$myproj.conf
echo "	WSGIProcessGroup $myproj" >> /etc/httpd/conf.d/$myproj.conf
echo "	WSGIScriptAlias / /opt/$myproj/src/$myproj/wsgi.py" >> /etc/httpd/conf.d/$myproj.conf

echo "</VirtualHost>" >> /etc/httpd/conf.d/$myproj.conf



echo "============Now setting up mod_wsgi ============="

mod_wsgi-express module-config >> /etc/httpd/conf/httpd.conf

echo "============Now restarting apache and mairadb 1 ============="
systemctl restart mariadb

systemctl start httpd

systemctl enable httpd

echo "============Now running database migration ============="
cd /opt/$myproj/

source /opt/$myproj/bin/activate

cd /opt/$myproj/src/

python3 manage.py makemigrations
python3 manage.py migrate

echo "============Now running collect static migration ============="
python3 manage.py collectstatic

echo "============Now restarting apache and mairadb 2 ============="
systemctl restart mariadb

systemctl start httpd

systemctl enable httpd
