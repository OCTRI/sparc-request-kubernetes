# SPARCRequest Base Image
#
# Runs vanilla SPARCRequest using the default Rails application server (Puma)
#
# To build:
# docker build --rm --build-arg SPARC_VERSION=[version of SPARC] -t example.edu/sparc_request_base:SPARC_VERSION --pull .
#
FROM ruby:2.5

ARG SPARC_VERSION=3.8.1
ENV LANG=en_US.UTF-8

WORKDIR /opt

# Add dependencies for Rails and the Paperclip gem
RUN set -eux; \
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - ; \
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list; \
  apt-get update; \
  apt-get install -y \
    ghostscript \
    imagemagick \
    yarn; \
  rm -rf /var/lib/apt/lists/*; \
  \
  curl -L -o sparc-request.tgz https://github.com/sparc-request/sparc-request/archive/refs/tags/release-${SPARC_VERSION}.tar.gz; \
  tar zxf sparc-request.tgz; \
  rm sparc-request.tgz; \
  mv sparc-request-release-${SPARC_VERSION} sparc; \
  cd sparc; \
  gem install bundler; \
  bundle config --local without "development test" && \
  # TODO: Remove `bundle update mimemagic` line when upgrading to SPARC 3.9 \
  bundle update mimemagic; \
  bundle install; \
  yarn install;

EXPOSE 3000
CMD ["rails", "s", "-b", "0.0.0.0"]
