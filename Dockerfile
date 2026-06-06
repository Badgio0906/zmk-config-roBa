FROM ghcr.io/skubmdi/docker-zmk-builder:main

WORKDIR /workspace
COPY config/west.yml /workspace/config/west.yml
COPY build.sh /usr/local/bin/build.sh
RUN chmod +x /usr/local/bin/build.sh && \
    west init -l config && west update && west zephyr-export && \
    sed -i 's/config LV_DISP_DEF_REFR_PERIOD/config LV_DEF_REFR_PERIOD/' \
    /workspace/prospector-zmk-module/boards/shields/prospector_adapter/Kconfig.defconfig
