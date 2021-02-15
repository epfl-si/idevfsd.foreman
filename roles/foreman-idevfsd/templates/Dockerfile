FROM {{ foreman_frontend_base_image }}
MAINTAINER IDEV-FSD <idev-fsd@groupes.epfl.ch>
RUN gem install foreman_bootdisk
RUN echo "gem 'foreman_bootdisk'" > bundler.d/foreman_bootdisk.rb; bundle install

# Just for comfort (M-x grep-find):
USER 0
RUN microdnf install findutils && microdnf clean all
USER 1001
