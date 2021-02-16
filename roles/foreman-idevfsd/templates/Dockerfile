FROM {{ foreman_frontend_base_image }} AS kitchensink

## https://stackoverflow.com/a/7662245/435004
RUN echo 'gem: --no-document' >> ~/.gemrc

USER 0
# The foreman_ansible plugin requires native extensions:
RUN  microdnf install redhat-rpm-config git \
    gcc-c++ make bzip2 gettext tar \
    libxml2-devel libcurl-devel ruby-devel \
    postgresql-devel
USER 1001
RUN echo "gem 'foreman_ansible'" > bundler.d/foreman_ansible.rb
RUN echo "gem 'foreman_bootdisk'" > bundler.d/foreman_bootdisk.rb
RUN echo "gem 'foreman_discovery'" > bundler.d/foreman_discovery.rb

RUN bundle install
RUN npm install --no-optional
# Stray dependency of foreman-tasks:
RUN npm i --save humanize-duration
RUN ./node_modules/webpack/bin/webpack.js --config config/webpack.config.js
RUN npm run analyze
RUN bundle install --without "${BUNDLER_SKIPPED_GROUPS}" assets

##################################################################################
FROM {{ foreman_frontend_base_image }}
MAINTAINER IDEV-FSD <idev-fsd@groupes.epfl.ch>

# Just for comfort (M-x grep-find):
USER 0
RUN microdnf install findutils && microdnf clean all
USER 1001

RUN rm -rf bin vendor bundler.d app public db && mkdir bin vendor bundler.d app public db
COPY --from=kitchensink /home/foreman/bin/ /home/foreman/bin/
COPY --from=kitchensink /home/foreman/vendor/ /home/foreman/vendor/
COPY --from=kitchensink /home/foreman/bundler.d/ /home/foreman/bundler.d/
COPY --from=kitchensink /home/foreman/app/ /home/foreman/app/
COPY --from=kitchensink /home/foreman/public/ /home/foreman/public/
COPY --from=kitchensink /home/foreman/db/ /home/foreman/db/
