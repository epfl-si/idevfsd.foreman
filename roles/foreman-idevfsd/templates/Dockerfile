FROM {{ foreman_frontend_base_image }}
MAINTAINER IDEV-FSD <idev-fsd@groupes.epfl.ch>

USER 0
# Just for comfort (M-x grep-find):
RUN microdnf install findutils && microdnf clean all

# The foreman_ansible plugin requires native extensions:
RUN set -e -x; \
  rpm -qa --queryformat '%{NAME}\n' | sort > /dev/shm/packages; \
  microdnf install ruby-devel glibc-devel gcc; \
  su -l -s /bin/bash foreman -c " \
  set -e -x; \
  export PATH=/home/foreman/bin:$PATH; \
  echo "\""gem 'foreman_ansible'"\"" > bundler.d/foreman_ansible.rb; \
  bundle install" ; \
  rpm -e $(rpm -qa --queryformat '%{NAME}\n' | sort | comm -1 -3 /dev/shm/packages -)

USER 1001

# These plugins are pure Ruby:
RUN set -e -x; \
  echo "gem 'foreman_bootdisk'" > bundler.d/foreman_bootdisk.rb; \
  echo "gem 'foreman_discovery'" > bundler.d/foreman_discovery.rb; \
  bundle install
