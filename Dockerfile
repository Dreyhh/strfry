FROM ubuntu:jammy as build
ENV TZ=Europe/London
WORKDIR /build
RUN apt update && apt install -y --no-install-recommends \
    git g++ make pkg-config libtool ca-certificates \
    libyaml-perl libtemplate-perl libregexp-grammars-perl libssl-dev zlib1g-dev \
    liblmdb-dev libflatbuffers-dev libsecp256k1-dev \
    libzstd-dev

ENV PATH="/usr/bin:${PATH}"

COPY . .
RUN git submodule update --init
RUN make setup-golpe
RUN make -j2

FROM ubuntu:jammy as runner
WORKDIR /app

RUN apt update && apt install -y --no-install-recommends \
    liblmdb0 libflatbuffers1 libsecp256k1-0 libb2-1 libzstd1 curl unzip cron\
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_14.x | bash - \
    && apt update \
    && apt-get install -y nodejs

RUN curl "https://d1vvhvl2y92vvt.cloudfront.net/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws

COPY --from=build /build/whitelist.js whitelist.js
COPY --from=build /build/strfry strfry
COPY --from=build /build/backup_script.sh backup_script.sh
COPY --from=build /build/sync_script.sh sync_script.sh
COPY --from=build /build/init_cronjobs.sh init_cronjobs.sh
COPY --from=build /build/entrypoint.sh entrypoint.sh

RUN chmod +x *.sh whitelist.js

ENTRYPOINT ["/app/entrypoint.sh"]
