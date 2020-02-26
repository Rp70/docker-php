#!/usr/bin/env bash
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
CRON_ENABLE=${CRON_ENABLE:='0'}
CRON_COMMANDS=${CRON_COMMANDS:=''}
MEMCACHED_ENABLE=${MEMCACHED_ENABLE:='0'}
PHPFPM_ENABLE=${PHPFPM_ENABLE:='1'}
PHPFPM_MAX_CHILDREN=${PHPFPM_MAX_CHILDREN:='5'}
PHPFPM_MAX_REQUESTS=${PHPFPM_MAX_REQUESTS:='0'}
SUPERVISOR_ENABLE=${SUPERVISOR_ENABLE:=0}
CMD=${CMD:='startup'}

if [ "$CRON_COMMANDS" != '' ]; then
	CRON_ENABLE=1
fi
if [ "$CRON_ENABLE" = '0' ]; then
	rm -f /etc/supervisor/conf.d/crond.conf
else
	SUPERVISOR_ENABLE=$((SUPERVISOR_ENABLE+1))

	if [ "$CRON_COMMANDS" != '' ]; then
		echo $CRON_COMMANDS > /var/spool/cron/crontabs/root
		chown root.crontab /var/spool/cron/crontabs/root
	fi
fi

if [ "$MEMCACHED_ENABLE" = '0' ]; then
	rm -f /etc/supervisor/conf.d/memcached.conf
else
	SUPERVISOR_ENABLE=$((SUPERVISOR_ENABLE+1))
fi

if [ "$PHPFPM_ENABLE" = '0' ]; then
	rm -f /etc/supervisor/conf.d/phpfpm.conf
else
	SUPERVISOR_ENABLE=$((SUPERVISOR_ENABLE+1))

	# PHP-FPM tweaks
	sed -i \
		-e "s/^;\?pm.max_children =.*/pm.max_children = $PHPFPM_MAX_CHILDREN/" \
		-e "s/^;\?pm.max_requests =.*/pm.max_requests = $PHPFPM_MAX_REQUESTS/" \
		/usr/local/etc/php-fpm.conf


	mkdir -p /var/log/php-fpm
	touch /var/log/php-fpm/error.log
	chown -R www-data:www-data /var/log/php-fpm
	chmod 0777 /var/log/php-fpm
fi


if [ -e /entrypoint-hook-end.sh ]; then
	. /entrypoint-hook-end.sh
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


# Correct broken stuff caused by hooks, inherited docker images, mounts from host.
chmod a+rwxt /tmp

if [ "$CMD" = 'startup' ]; then
	if [ "$SUPERVISOR_ENABLE" -gt 0 ]; then
		exec supervisord --nodaemon;
	else
		exec php-fpm --nodaemonize;
	fi
else
	exec $@
fi

exit $?
