ARG BASE_IMAGE
FROM ${BASE_IMAGE}
RUN apt update && apt install -y --no-install-recommends iproute2 psmisc jq
COPY docker-entrypoint.sh /
