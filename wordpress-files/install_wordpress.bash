#!/bin/bash
########################################################################
#        THIS IS FOR THE SERVER SIDE (WORDPRESS INSTALLATION)          #
# Run this script after first boot on the new system as root!          #
# You only need to run it once!                                        #
# It will                                                              #
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
wppath='/var/www/html'
corecache=/root/.wp-cli/cache/core
wpversion='6.6.1'
lfiles=./files
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
# configure MariaDB
########################################################################
# start and enable mariadb
systemctl stop mariadb
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
#cd
curl https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o ./wp-cli.phar
chmod +x ./wp-cli.phar
if [ -f ./wp-cli.phar ]
then
 echo "WP-CLI present"
else
 echo "WP-CLI not ready - Break!"
 exit 1
fi

########################################################################
# inject existing files into wp-cli cache
########################################################################
mkdir -p "$corecache"
cp "$lfiles/wordpress-$wpversion-de_DE.tar.gz" "$corecache"
cp "$lfiles/wordpress-$wpversion-en_US.tar.gz" "$corecache"

# simulate download (would download but because of cache files present
# and version pinned using local cached files)
# wordpress will extracted to $wppath
php wp-cli.phar --allow-root --path=${wppath} core download --locale=${wplocale} --version=$wpversion

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
#		--version=$wpversion

########################################################################
# install wordpress plugins + plugin languages and activate them
########################################################################
# Foyer
mypath=$(pwd)
# wget https://github.com/mennolui/wp-foyer/archive/refs/heads/master.zip -O $lfiles/foyer.zip
php wp-cli.phar --allow-root --path=${wppath} plugin install $lfiles/foyer.zip --activate
php wp-cli.phar --allow-root --path=${wppath} language plugin install $lfiles/plugin-foyer-1.7.5-de_DE-1523207365.zip ${wplocale}
# Theatre
php wp-cli.phar --allow-root --path=${wppath} plugin install $lfiles/theatre-0.18.5.zip --activate
php wp-cli.phar --allow-root --path=${wppath} language plugin install $lfiles/plugin-theatre-0.18.3-de_DE-1665398556.zip  ${wplocale}

# Force Rrefresh
php wp-cli.phar --allow-root --path=${wppath} plugin install $lfiles/force-refresh-2.11.0.zip --activate

# AIO WP Security
php wp-cli.phar --allow-root --path=${wppath} plugin install $lfiles/all-in-one-wp-security-and-firewall-5.3.1.zip --activate
php wp-cli.phar --allow-root --path=${wppath} language plugin install $lfiles/plugin-all-in-one-wp-security-and-firewall-5.3.1-de_DE-1709088146.zip  ${wplocale}

# Jellyfish Backdrop
php wp-cli.phar --allow-root --path=${wppath} plugin install $lfiles/jellyfish-backdrop-0.7.0.zip --activate

########################################################################
# update wordpress
########################################################################
#php wp-cli.phar --path=$wppath --allow-root language core update
#php wp-cli.phar --path=$wppath --allow-root language plugin update --all
#php wp-cli.phar --path=$wppath --allow-root language theme update --all

########################################################################
# set theme to twentytwentytwo to avoid problems with foyer plugin
########################################################################
php wp-cli.phar --path=$wppath --allow-root theme activate twentytwentytwo

########################################################################
# set permissions on webroot to allow uploads for user http
########################################################################
chown -R -- http:http "${wppath}"

########################################################################
# output summary and credentials
########################################################################
# fix wordpress home
php wp-cli.phar --path=$wppath --allow-root option update home "${wpurl}"
php wp-cli.phar --path=$wppath --allow-root option update siteurl "${wpurl}"

# set the password again just in case we rerun the script
php wp-cli.phar --path=$wppath --allow-root user update "${wpadmin}" --user_pass="${wpadminpass}"
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
echo -e "\n\nYou should reboot now to glue everything together!"
echo -e "Make sure to write down the above login credentials before!\n"

########################################################################
#  END END END END END END END END END END END END END END END END END #
########################################################################
