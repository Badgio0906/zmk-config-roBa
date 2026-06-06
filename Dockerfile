FROM ghcr.io/skubmdi/docker-zmk-builder:main

WORKDIR /workspace
COPY config/west.yml /workspace/config/west.yml
COPY build.sh /usr/local/bin/build.sh
RUN chmod +x /usr/local/bin/build.sh && \
    west init -l config && west update && west zephyr-export
