
sostituzione_certificato() {

cd /var/www/html/$1/ssl/
rm /var/www/html/$1/ssl/$1.logik*


#wget -qO - https://raw.githubusercontent.com/way76/vte/master/azienda.logikadev.it.crt  > /var/www/html/$1/ssl/$1.logikadev.it.crt
#wget -qO - https://raw.githubusercontent.com/way76/vte/master/azienda.logikadev.it.key  > /var/www/html/$1/ssl/$1.logikadev.it.key

wget -qO - https://raw.githubusercontent.com/way76/vte/master/STAR_logikasoftware_cloud.crt  > /var/www/html/$1/ssl/logikasoftware-cloud.crt
wget -qO - https://raw.githubusercontent.com/way76/vte/master/STAR.logikasoftware.cloud_key.txt  > /var/www/html/$1/ssl/logikasoftware-cloud.key


a2enmod ssl
systemctl restart apache2

}


sostituzione_certificato $1
