FROM ubuntu:jammy as build

ENV TZ=Europe/London
WORKDIR /build

RUN apt update && \
    apt install -y --no-install-recommends \
    git g++ make pkg-config libtool ca-certificates \
    libyaml-perl libtemplate-perl libregexp-grammars-perl libssl-dev zlib1g-dev \
    liblmdb-dev libflatbuffers-dev libsecp256k1-dev \
    libzstd-dev && \
    rm -rf /var/lib/apt/lists/*

ENV PATH="/usr/bin:${PATH}"

COPY . .
RUN git submodule update --init && \
    make setup-golpe && \
    make -j2

FROM ubuntu:jammy as runner

WORKDIR /app

RUN apt update && \
    apt install -y --no-install-recommends \
    ca-certificates liblmdb0 libflatbuffers1 libsecp256k1-0 libb2-1 libzstd1 curl unzip cron lsb-release gnupg && \
    rm -rf /var/lib/apt/lists/* && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt update && \
    apt install -y nodejs && \
    rm -rf /var/lib/apt/lists/* && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
    apt update && \
    apt install -y google-cloud-sdk && \
    rm -rf /var/lib/apt/lists/* && \
    npm install redis
 
COPY --from=build /build/redisClient.js redisClient.js
COPY --from=build /build/whitelist.js whitelist.js
COPY --from=build /build/strfry strfry
COPY --from=build /build/backup_script.sh backup_script.sh
COPY --from=build /build/sync_script.sh sync_script.sh

RUN chmod +x *.sh whitelist.js