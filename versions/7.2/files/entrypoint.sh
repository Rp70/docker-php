#!/bin/sh
set -e

echo "Overwriting files (if any)"
if [ -d /entrypoint/overwrite ]; then
	cp -fvab /entrypoint/overwrite/* /
fi
echo


if [ -e /entrypoint-hook-start.sh ]; then
	. /entrypoint-hook-start.sh
fi

CRON_ENABLE=${CRON_ENABLE:=''}
CRON_COMMANDS=${CRON_COMMANDS:=''}
MEMCACHED_ENABLE=${MEMCACHED_ENABLE:=''}
NGINX_ENABLE=${NGINX_ENABLE:=''}
NGINX_PROCESSES=${NGINX_PROCESSES:='2'}
NGINX_REALIP_FROM=${NGINX_REALIP_FROM:=''}
NGINX_REALIP_HEADER=${NGINX_REALIP_HEADER:='X-Forwarded-For'}


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

	NGINX_REPLACE=${NGINX_REPLACE:='NGINX_FASTCGI_PASS'}
	NGINX_FASTCGI_PASS=${NGINX_FASTCGI_PASS:='127.0.0.1:9000'}
	echo "Replacing variables in /etc/nginx"
	SHELLFORMAT=''
	for varname in $NGINX_REPLACE; do
		SHELLFORMAT="\$$varname $SHELLFORMAT"
	done
	if [ "$SHELLFORMAT" != '' ]; then
		SHELLFORMAT="'$SHELLFORMAT'"
		for configfile in `find /etc/nginx -type f ! -path '*~'`; do
			echo $configfile
			content=`cat $configfile`
			echo "$content" | envsubst "$SHELLFORMAT" > $configfile
		done
	fi
	echo

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

mkdir -p /var/log/php-fpm
touch /var/log/php-fpm/error.log
chown -R www-data:www-data /var/log/php-fpm
chmod 0777 /var/log/php-fpm

if [ -e /entrypoint-hook-end.sh ]; then
	. /entrypoint-hook-end.sh
fi


# Correct broken stuff caused by hooks, inherited docker images
chmod a+rwxt /tmp

if [ "$1" = 'startup' ]; then
	if [ "$SUPERVISOR_ENABLE" -gt 0 ]; then
		exec supervisord --nodaemon;
	else
		exec php-fpm --nodaemonize;
	fi
else
	exec "$@"
fi
