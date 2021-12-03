# SPARCRequest
#
# This image builds from the base SPARCRequest image and includes organization specific overrides.
#
# To build:
#
# docker build --rm -t example.edu/sparc_request --pull .
FROM example.edu/sparc_request_base:3.8.1

# Customizations can be loaded into the image using a similar pattern.
COPY ./deps/sparc/database.yml /opt/sparc/config/database.yml
COPY ./deps/sparc/tasks/*.rake /sparc/lib/tasks/
COPY ./deps/sparc/irb_status_cache.rb /sparc/app/lib/irb_status_cache.rb
