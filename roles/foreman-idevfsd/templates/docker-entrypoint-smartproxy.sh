#!/bin/bash

set -e -x

cd /usr/src/app
if grep :foreman_url: config/settings.yml; then
    # https://theforeman.org/plugins/foreman_ansible/3.x/index.html#2.1Ansiblecallback
    cat >>/etc/ansible/ansible.cfg <<CALLBACK_FOREMAN
[callback_foreman]
url =$( grep :foreman_url: config/settings.yml | cut -d: -f3- | sed 's|"||g' )
ssl_cert = /dev/null
ssl_key = /dev/null
verify_certs = 0
CALLBACK_FOREMAN
fi

mkdir -p /etc/service/smart-proxy
cat > /etc/service/smart-proxy/run <<SCRIPT
#!/bin/sh

cd /usr/src/app
exec bundle exec ./bin/smart-proxy

SCRIPT
chmod 0755 /etc/service/smart-proxy/run

exec busybox runsvdir -P /etc/service

