service postgresql start 
export USER=root
. /root/.nix-profile/etc/profile.d/nix.sh
touch /var/log/rhodecode-vcsserver.log
touch /var/log/rhodecode-enterprise-ce.log
cd /rhodecode-develop/rhodecode-vcsserver
export LOCALE_ARCHIVE=`nix-env --installed --no-name --out-path --query glibc-locales`/lib/locale/locale-archive
nix-shell --run "gunicorn --paster configs/production.ini" > /var/log/rhodecode-vcsserver.log &
cd /rhodecode-develop/rhodecode-enterprise-ce 
nix-shell --run "gunicorn --paster configs/production.ini" > /var/log/rhodecode-enterprise-ce.log &
tail -f /var/log/rhodecode-*.log
