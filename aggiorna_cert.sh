
sostituzione_certificato() {

cd /var/www/html/$1/ssl/
rm /var/www/html/$1/ssl/logik*

wget -qO - https://raw.githubusercontent.com/way76/vte/master/ls_cloud.file1  > /var/www/html/$1/ssl/logikasoftware-cloud.crt
wget -qO - https://raw.githubusercontent.com/way76/vte/master/ls_cloud_key.file2  > /var/www/html/$1/ssl/logikasoftware-cloud.key


a2enmod ssl
systemctl restart apache2

}


sostituzione_certificato $1
