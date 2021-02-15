FROM {{ foreman_frontend_base_image }}
MAINTAINER IDEV-FSD <idev-fsd@groupes.epfl.ch>

## https://stackoverflow.com/a/7662245/435004
RUN echo 'gem: --no-document' >> ~/.gemrc

USER 0
# Just for comfort (M-x grep-find):
RUN microdnf install findutils && microdnf clean all

# The foreman_ansible plugin requires native extensions:
RUN set -e -x; \
  rpm -qa --queryformat '%{NAME}\n' | sort > /dev/shm/packages; \
  microdnf install redhat-rpm-config git \
    gcc-c++ make bzip2 gettext tar \
    libxml2-devel libcurl-devel ruby-devel \
    postgresql-devel; \
  su -l -s /bin/bash foreman -c " \
  set -e -x; \
  export PATH=/home/foreman/bin:$PATH; \
  echo "\""gem 'foreman_ansible'"\"" > bundler.d/foreman_ansible.rb; \
  bundle install; \
  npm install --no-optional; \
  ./node_modules/webpack/bin/webpack.js --config config/webpack.config.js ; \
  npm run analyze ; \
  rm -rf public/webpack/stats.json ./node_modules vendor/ruby/*/cache vendor/ruby/*/gems/*/node_modules bundler.d/nulldb.rb db/schema.rb; \
  bundle install --without "\"'${BUNDLER_SKIPPED_GROUPS}'\"" assets"; \
  rpm -e $(rpm -qa --queryformat '%{NAME}\n' | sort | comm -1 -3 /dev/shm/packages -); \
  microdnf clean all

USER 1001

# These plugins are pure Ruby:
RUN set -e -x; \
  echo "gem 'foreman_bootdisk'" > bundler.d/foreman_bootdisk.rb; \
  echo "gem 'foreman_discovery'" > bundler.d/foreman_discovery.rb; \
  bundle install
