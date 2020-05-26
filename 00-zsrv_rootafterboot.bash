#!/bin/bash
########################################################################
#        THIS IS FOR THE SERVER SIDE (WORDPRESS INSTALLATION)          #
# Run this script after first boot on the new system as root!          #
# You only need to run it once!                                        #
# It will                                                              #
#  - install lighttpd                                                  #
#  - install MariaDB                                                   #
#  - create the wordpress database                                     #
#  - download wp-cli                                                   #
#  - using wp-cli to download wordpress                                #
#  - create the database for wordpress                                 #
#  - using wp-cli to create wp-config.php                              #
#  - using wp-cli to install wordpress                                 #
#  - using wp-cli to install needed plugins                            #
#                                                                      #
# AN INTERNET CONNECTION IS REQUIRED !                                 #
########################################################################

# edit the vars here is better
#servername='dsserver'
db='dsdatabase'
dbuser='dswpuser'
dbpass='' # will be generated if not set
dbhost='localhost'
wptitle='dsserver'
wpadmin='dsadmin'
wpadminpass='' # will be generated if not set
wpadminemail='some@none.com'
wplocale='de_DE'
wppath='/srv/http'

########################################################################
# check internet connection (archlinuxarm.org)                         #
########################################################################
while ! timeout 5 ping -c 1 -n archlinuxarm.org &> /dev/null
do
    printf "%s\n" "no internet connection, please check! - Ctrl+C to exit!"
    sleep 1
done
printf "\n%s\n"  "Internet is accessible."

########################################################################
# check for multiple IPs and break if so
########################################################################
# get first 3 octets of network of default route
#network=$(route -n | grep "^0.0.0.0" | awk '{print $2}' | awk -F '.' '{print $1"."$2"."$3"."}')
# find ip from that network
#wpip=$(ip addr | grep "$network" | awk '{print $2}' | awk -F '/' '{print $1}')
# next line grabbed from CentOs8 /usr/share/cockpit/motd/update-motd script
# looks much simpler :) leaving old lines in with a comment just in case...
wpip=${3:-$(ip -o route get 255.0 2>/dev/null | sed -e 's/.*src \([^ ]*\) .*/\1/')}
ipcount=$(echo "$wpip" | wc -l)
if [ "$ipcount" != "1" ]
then
 echo -e "\nThe script detected 2 IP addresses and can not determine which one to use!"
 echo "Please use either Ethernet or WiFi but not both!"
 echo "The IPs are:"
 echo "$wpip"
 echo -e "Fix that now and re-run this script, please!\n"
 exit 1
fi
# define wpurl as $wpip
wpurl="http://${wpip}"

########################################################################
# initialize pacman keyring and populate Arch ARM package signing keys
########################################################################
pacman-key --init
pacman-key --populate archlinuxarm

########################################################################
# function to prepare and fix pacman-mirrorlist for Germany            #
# It should also work if you replace 'Germany' with your country       #
########################################################################
function fix_mirrorlist {
 cp -f /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
 echo "Backup of previous mirrorlist is at /etc/pacman.d/mirrorlist.bak"
 # use armreflector.bash to create a fast mirrorlist
 echo -n "Generating a more speedy mirrorlist..."
 ./armreflector.bash /etc/pacman.d/mirrorlist.bak > /etc/pacman.d/mirrorlist
 echo "done"
 pacman -Sy --noconfirm # only update package database
}
cp -f /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.original2 # just for sure
fix_mirrorlist

########################################################################
# Download latest pacman-mirrorlist and overwrite old
########################################################################
pacman -S pacman-mirrorlist --noconfirm
if [ -f /etc/pacman.d/mirrorlist.pacnew ]
then
 mv -f /etc/pacman.d/mirrorlist.pacnew /etc/pacman.d/mirrorlist
 fix_mirrorlist
fi

########################################################################
# fully update the system
########################################################################
pacman -Syu --noconfirm

########################################################################
# Install LAMP stack and everything needed to run wordpress later
########################################################################
# list of packages to install
packages="lighttpd,mariadb,php,php-fpm,pwgen,php-imagick,psutils"
# get list of already installed packages and store them in $installed
# --force can be used as "$1" to ignore the variable completely
installed=$(pacman -Q | cut -d ' ' -f 1 | tr '\n' '|')
if [ "$1" == "--force" ];then installed='';fi # override when --force
# install packages from list
for i in $(echo $packages | sed "s/,/ /g")
do
 if ! echo "$installed"|grep -q "$i" # only if not yet installed
 then
  LANG=C pacman -Si "$i" | grep -E "Name|Depends"; echo "----"
  pacman -S "$i" --noconfirm
 fi
done

# create lighttpd conf.d folder
mkdir -p /etc/lighttpd/conf.d
# create /etc/lighttpd/conf.d/fastcgi.conf
cat >"/etc/lighttpd/conf.d/fastcgi.conf" <<EOL
server.modules += ( "mod_fastcgi" )

index-file.names += ( "index.php" )

fastcgi.server = (
    ".php" => (
      "localhost" => (
        "socket" => "/run/php-fpm/php-fpm.sock",
        "broken-scriptfilename" => "enable"
      ))
)
EOL
# remove previous includes from lighttpd.conf
sed -i '/include.*fastcgi.conf/d' /etc/lighttpd/lighttpd.conf
# add an include for fastcgi.conf to lighttpd.conf
echo 'include "conf.d/fastcgi.conf"' >> /etc/lighttpd/lighttpd.conf

########################################################################
# configure PHP
########################################################################
# activate mysqli in php.ini
sed -i "s@;\(extension=mysqli\)@\1@g" /etc/php/php.ini
# activate imagick.so by editiing imagick.ini
sed -i 's@;\(extension=imagick\)@\1@g' /etc/php/conf.d/imagick.ini
# sed -i 's@extension=mysqli@extension=mysqli\nextension=imagick@g' /etc/php/php.ini

# set upload settings in php.ini
#max_execution_time = 300
#max_input_time = 300
#post_max_size = 1024M
#upload_max_filesize = 250M
sed -i "s@^\(file_uploads\).*@\1 = On@g" /etc/php/php.ini
sed -i "s@^\(max_execution_time\).*@\1 = 300@g" /etc/php/php.ini
sed -i "s@^\(max_input_time\).*@\1 = 300@g" /etc/php/php.ini
sed -i "s@^\(post_max_size\).*@\1 = 1024M@g" /etc/php/php.ini
sed -i "s@^\(upload_max_filesize\).*@\1 = 250M@g" /etc/php/php.ini

########################################################################
# fix /etc/ImageMagick-6/policy.xml
# fix /etc/ImageMagick-7/policy.xml
########################################################################
cp /etc/ImageMagick-7/policy.xml /etc/ImageMagick-7/policy.xml.bak
cat >"/etc/ImageMagick-7/policy.xml" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policymap [
  <!ELEMENT policymap (policy)+>
  <!ATTLIST policymap xmlns CDATA #FIXED ''>
  <!ELEMENT policy EMPTY>
  <!ATTLIST policy xmlns CDATA #FIXED '' domain NMTOKEN #REQUIRED
    name NMTOKEN #IMPLIED pattern CDATA #IMPLIED rights NMTOKEN #IMPLIED
    stealth NMTOKEN #IMPLIED value CDATA #IMPLIED>
]>
<policymap>
  <policy domain="*" rights="all" pattern="*" />
</policymap>
EOL

# start and enable lighttpd
systemctl start lighttpd
systemctl enable lighttpd
# start and enable php-fpm
systemctl start php-fpm
systemctl enable php-fpm

########################################################################
# configure MariaDB
########################################################################
# start and enable mariadb
mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
systemctl start mariadb
systemctl enable mariadb
# unattended execution of mysql_secure_installation
mysql_secure_installation <<EOF

n
n
y
y
y
y
EOF

########################################################################
# create a cleanup.bash that can remove the entire wordpress installation
# the wordpress database and the database user so we can re-run this
# script againg after we ran cleanup.bash
########################################################################
echo -e "#!/bin/bash\n" > ./cleanup.bash
echo "echo \"DROP USER IF EXISTS '${dbuser}'@'${dbhost}';\" | mysql -u root " >> ./cleanup.bash
echo "echo \"DROP DATABASE ${db};\" | mysql -u root" >> ./cleanup.bash
echo "rm -r -f -- \"${wppath}/\"*" >> ./cleanup.bash
echo "########################################################################"
echo -e "\n\nTo cleanup everything back where you started execute\n"
echo -e "  bash ./cleanup.bash \n"
echo "########################################################################"

########################################################################
# create wordpress database
########################################################################
if [ "$dbpass" == "" ]; then dbpass="$(pwgen -B -s 15 1)";fi
echo "CREATE DATABASE ${db}; \
      CREATE USER '${dbuser}'@'${dbhost}'; \
      SET PASSWORD FOR '${dbuser}'@'${dbhost}' = PASSWORD('${dbpass}'); \
      GRANT ALL PRIVILEGES ON ${db}.* TO '${dbuser}'@'${dbhost}' IDENTIFIED BY '${dbpass}'; \
      FLUSH PRIVILEGES;" | mysql -u root

########################################################################
# Download wp-cli (wp-cli.phar) for direct use without installation
########################################################################
cd
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
if php wp-cli.phar --info >/dev/null
then
 echo "WP-CLI present"
else
 echo "WP-CLI not ready - Break!"
 exit 1
fi

########################################################################
# download and extract wordpress to target folder with wp-cli
########################################################################
php wp-cli.phar --allow-root --path=${wppath} core download --locale=${wplocale}

########################################################################
# create and prefill wp-config.php using wp-cli
########################################################################
php wp-cli.phar --allow-root --path=${wppath} \
                config create \
                       --dbname=${db} \
                       --dbuser=${dbuser} \
                       --dbpass="${dbpass}"

########################################################################
# install wordpress using wp-cli
########################################################################
if [ "$wpadminpass" == "" ]; then wpadminpass="$(pwgen -B -s 15 1)"; fi
php wp-cli.phar --allow-root --path=${wppath} \
                core install \
                --url=${wpurl} \
                --title=${wptitle} \
                --admin_user=${wpadmin} \
                --admin_password="${wpadminpass}" \
                --admin_email=${wpadminemail}

########################################################################
# install wordpress plugins + plugin languages and activate them
########################################################################
php wp-cli.phar --allow-root --path=${wppath} plugin install foyer --activate
php wp-cli.phar --allow-root --path=${wppath} language plugin install foyer ${wplocale}
php wp-cli.phar --allow-root --path=${wppath} plugin install jellyfish-backdrop --activate
php wp-cli.phar --allow-root --path=${wppath} language plugin install jellyfish-backdrop ${wplocale}
php wp-cli.phar --allow-root --path=${wppath} plugin install theatre --activate
php wp-cli.phar --allow-root --path=${wppath} language plugin install theatre ${wplocale}
php wp-cli.phar --allow-root --path=${wppath} plugin install force-refresh --activate
php wp-cli.phar --allow-root --path=${wppath} language plugin install force-refresh ${wplocale}
php wp-cli.phar --allow-root --path=${wppath} plugin install all-in-one-wp-security-and-firewall --activate
php wp-cli.phar --allow-root --path=${wppath} language plugin install all-in-one-wp-security-and-firewall ${wplocale}

########################################################################
# update wordpress
########################################################################
php wp-cli.phar --path=/srv/http --allow-root language core update
php wp-cli.phar --path=/srv/http --allow-root language plugin update --all
php wp-cli.phar --path=/srv/http --allow-root language theme update --all

########################################################################
# set permissions on webroot to allow uploads for user http
########################################################################
chown -R -- http:http "${wppath}"

########################################################################
# output summary and credentials
########################################################################
# fix wordpress home
php wp-cli.phar --path=/srv/http --allow-root option update home "${wpurl}"
php wp-cli.phar --path=/srv/http --allow-root option update siteurl "${wpurl}"

# set the password again just in case we rerun the script
php wp-cli.phar --path=/srv/http --allow-root user update "${wpadmin}" --user_pass="${wpadminpass}"
echo "##############################################"
echo "# Installation summary (you should save it!) #"
echo "##############################################"
#echo "Servername        : $servername"
echo "Database          : $db"
echo "DB User           : $dbuser"
echo "DB Pass           : $dbpass"
echo "DB Host           : $dbhost" 
echo "WP Title          : $wptitle"
echo "WP Admin          : $wpadmin"
echo "WP Admin password : $wpadminpass"
echo "WP Admin email    : $wpadminemail"
echo "WP Locale         : $wplocale"       
echo "WP Path           : $wppath"
echo "##############################################"
echo -e "\nOpen ${wpurl}/wp-admin now and login with the following credentials:\n"
echo -e "User: ${wpadmin}"
echo -e "Pass: ${wpadminpass}\n"

########################################################################
#  END END END END END END END END END END END END END END END END END #
########################################################################
