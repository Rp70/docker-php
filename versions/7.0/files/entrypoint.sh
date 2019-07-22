#!/bin/sh
set -e

### Moved to 00_entrypoint.sh
# if [ -d /entrypoint/overwrite ]; then
# 	echo "Overwriting files (if any)"
# 	cp -fvab /entrypoint/overwrite/* /
# 	echo
# fi


if [ -e /entrypoint-hook-start.sh ]; then
	. /entrypoint-hook-start.sh
fi


ENVIRONMENT_REPLACE=${ENVIRONMENT_REPLACE:=''}
CRON_ENABLE=${CRON_ENABLE:=''}
CRON_COMMANDS=${CRON_COMMANDS:=''}
MEMCACHED_ENABLE=${MEMCACHED_ENABLE:=''}
NGINX_ENABLE=${NGINX_ENABLE:=''}
NGINX_PROCESSES=${NGINX_PROCESSES:='2'}
NGINX_REALIP_FROM=${NGINX_REALIP_FROM:=''}
NGINX_REALIP_HEADER=${NGINX_REALIP_HEADER:='X-Forwarded-For'}
PHPFPM_MAX_CHILDREN=${PHPFPM_MAX_CHILDREN:='5'}


CMD=${CMD:='startup'}
SUPERVISOR_ENABLE=0

if [ "$CRON_COMMANDS" != '' ]; then
	CRON_ENABLE="1"
fi
if [ "$CRON_ENABLE" = '' ]; then
	rm -f /etc/supervisor/conf.d/crond.conf
else
	SUPERVISOR_ENABLE=$((SUPERVISOR_ENABLE+1))
fi

if [ "$MEMCACHED_ENABLE" = '' ]; then
	rm -f /etc/supervisor/conf.d/memcached.conf
else
	SUPERVISOR_ENABLE=$((SUPERVISOR_ENABLE+1))
fi

if [ "$NGINX_ENABLE" = '' ]; then
	rm -f /etc/supervisor/conf.d/nginx.conf
else
	SUPERVISOR_ENABLE=$((SUPERVISOR_ENABLE+1))
	ENVIRONMENT_REPLACE="$ENVIRONMENT_REPLACE /etc/nginx"
	
	#rm -rf /etc/nginx/sites-available/default
	#sed -i 's/^user/daemon off;\nuser/g' /etc/nginx/nginx.conf
	#sed -i 's/^user www-data;/user coin;/g' /etc/nginx/nginx.conf
	sed -i "s/^worker_processes auto;/worker_processes $NGINX_PROCESSES;/g" /etc/nginx/nginx.conf
	#sed -i 's/\baccess_log[^;]*;/access_log \/dev\/stdout;/g' /etc/nginx/nginx.conf
	#sed -i 's/\berror_log[^;]*;/error_log \/dev\/stdout;/g' /etc/nginx/nginx.conf

	rm -rf /etc/nginx/modules-enabled/*.conf
	
	### realip_module ###
	# Cloudflare IPv4: https://www.cloudflare.com/ips-v4
	# Cloudflare IPv6: https://www.cloudflare.com/ips-v6
	CONFFILE=/etc/nginx/conf.d/realip.conf
	IPADDRS=""
	for ipaddr in $NGINX_REALIP_FROM; do
		if [ "$ipaddr" = "cloudflare" ]; then
			IPADDRS="$IPADDRS `curl -f --connect-timeout 30 https://www.cloudflare.com/ips-v4 2> /dev/null`"
			if [ $? -gt 0 ]; then
				IPADDRS="$IPADDRS `cat /tmp/cloudflare-ips-v4 2> /dev/null`"
			fi
			sleep 1

			IPADDRS="$IPADDRS `curl -f --connect-timeout 30 https://www.cloudflare.com/ips-v6 2> /dev/null`"
			if [ $? -gt 0 ]; then
				IPADDRS="$IPADDRS `cat /tmp/cloudflare-ips-v6 2> /dev/null`"
			fi

			NGINX_REALIP_HEADER='CF-Connecting-IP'
		else
			# Try to get IP if it's a hostname
			for ipaddr2 in `getent hosts $ipaddr | awk '{print $1}'`; do
				IPADDRS="$IPADDRS $ipaddr2"
			done
		fi
	done

	if [ "$IPADDRS" != '' ]; then
		echo "### This file is auto-generated. ###" > $CONFFILE
		echo "### Your changes will be overwriten. ###" >> $CONFFILE
		echo >> $CONFFILE
		for ipaddr in $IPADDRS; do
			echo "set_real_ip_from $ipaddr;" >> $CONFFILE
		done
		echo "real_ip_header $NGINX_REALIP_HEADER;" >> $CONFFILE
	fi
	### / realip_module ###
fi


if [ "$ENVIRONMENT_REPLACE" != '' ]; then
	SHELLFORMAT='';
	for varname in `env | cut -d'='  -f 1`; do
		SHELLFORMAT="\$$varname $SHELLFORMAT";
	done
	SHELLFORMAT="'$SHELLFORMAT'"
	
	for envfile in $ENVIRONMENT_REPLACE; do
		echo "Replacing variables in $envfile"
		for configfile in `find $envfile -type f ! -path '*~'`; do
			echo $configfile
			# This will mess files with escaped chars.
			# It will mess: return 200 'User-Agent: *\nDisallow: /';
			#content=`cat $configfile`
			#echo "$content" | envsubst "$SHELLFORMAT" > $configfile
			
			# Temp file is slow but won't mess files with escaped chars.
			cp -f $configfile /dev/shm/envsubst.tmp
			envsubst "$SHELLFORMAT" < /dev/shm/envsubst.tmp > $configfile
		done
	done
	
	rm -f /dev/shm/envsubst.tmp
fi


# PHP-FPM tweaks
sed -i -e "s/^pm.max_children =.*/pm.max_children = $PHPFPM_MAX_CHILDREN/" /usr/local/etc/php-fpm.d/www.conf


mkdir -p /var/log/php-fpm
touch /var/log/php-fpm/error.log
chown -R www-data:www-data /var/log/php-fpm
chmod 0777 /var/log/php-fpm

if [ -e /entrypoint-hook-end.sh ]; then
	. /entrypoint-hook-end.sh
fi


# Correct broken stuff caused by hooks, inherited docker images
chmod a+rwxt /tmp

if [ "$CMD" = 'startup' ]; then
	if [ "$SUPERVISOR_ENABLE" -gt 0 ]; then
		exec supervisord --nodaemon;
	else
		exec php-fpm --nodaemonize;
	fi
else
	exec "$@"
fi
