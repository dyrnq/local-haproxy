#!/bin/bash
set -e

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- haproxy "$@"
fi

if [ "$1" = 'haproxy' ]; then
	shift # "haproxy"
	# if the user wants "haproxy", let's add a couple useful flags
	#   -W  -- "master-worker mode" (similar to the old "haproxy-systemd-wrapper"; allows for reload via "SIGUSR2")
	#   -db -- disables background mode
	set -- haproxy -W -db "$@"
fi

if [ -f /usr/local/etc/haproxy/haproxy.cfg ]; then
sed -i '/^frontend  main/,$s/^/##/' /usr/local/etc/haproxy/haproxy.cfg
fi

cat < /dev/null > /usr/local/etc/haproxy/local.cfg

IP=${IP:-autodetect}
IP_AUTODETECTION_METHOD=${IP_AUTODETECTION_METHOD:-first-found}
PORT=${PORT:-8443}
FRONTEND_NAME=${FRONTEND_NAME:-frontend_${PORT}}
BACKEND_NAME=${BACKEND_NAME:-backend_${PORT}}
MODE=${MODE:-tcp}
BALANCE=${BALANCE:-roundrobin}
ADV_CHECK=${ADV_CHECK:-httpchk}
HTTP_CHECK="${HTTP_CHECK:-http-check expect status 200}"
HTTPCHK_PARAMS="${HTTPCHK_PARAMS:-GET /livez}"

BACKEND_SERVER=${BACKEND_SERVER:-}

FQDN_IP=${FQDN_IP:-autodetect}
FQDN_IP_AUTODETECTION_METHOD=${FQDN_IP_AUTODETECTION_METHOD:-${IP_AUTODETECTION_METHOD}}
FQDN="${FQDN:-}"
HOSTS_FILE="${HOSTS_FILE:-/host/etc/hosts}"
VRRBOSE="${VRRBOSE:-}"

if [ -n "${VRRBOSE}" ]; then set -x; fi

if [ "${IP}" = "autodetect" ]; then

if [ "${IP_AUTODETECTION_METHOD}" = "first-found" ]; then
autodetect_interface=$(ip route | awk '/default/ {print $5}' | head -n1)
else
autodetect_interface=$(awk -F= '{print $2}' <<EOF
${IP_AUTODETECTION_METHOD}
EOF
)
fi



    IP_VALUE=$(/sbin/ip -o -4 addr list "${autodetect_interface}" | awk '{print $4}' | cut -d/ -f1 | head -n1);
else
    IP_VALUE="${IP}"
fi


(
echo "frontend ${FRONTEND_NAME}"
echo "  mode ${MODE}"
echo "  bind ${IP_VALUE}:${PORT} name ${FRONTEND_NAME}"
echo "  default_backend ${BACKEND_NAME}"
echo ""
echo ""
echo "backend ${BACKEND_NAME}"
echo "  description ${BACKEND_NAME}"
echo "  mode ${MODE}"
echo "  balance ${BALANCE}"
echo "  option ${ADV_CHECK} ${HTTPCHK_PARAMS}"
) > /usr/local/etc/haproxy/local.cfg

if [ -n "${HTTP_CHECK}" ]; then
    echo "  ${HTTP_CHECK}" >> /usr/local/etc/haproxy/local.cfg
fi



IFS=',' read -r -a backend_server_array <<EOF
${BACKEND_SERVER}
EOF

for i in "${!backend_server_array[@]}"; do
element="${backend_server_array[$i]}";
echo "  server server_${i} ${element}" >> /usr/local/etc/haproxy/local.cfg
done

cat < /usr/local/etc/haproxy/local.cfg

if [ -n "${FQDN}" ] && [ -w "${HOSTS_FILE}" ]; then

    if [ "${FQDN_IP}" = "autodetect" ]; then

if [ "${FQDN_IP_AUTODETECTION_METHOD}" = "first-found" ]; then
fqdn_autodetect_interface=$(ip route | awk '/default/ {print $5}' | head -n1)
else
fqdn_autodetect_interface=$(awk -F= '{print $2}' <<EOF
${FQDN_IP_AUTODETECTION_METHOD}
EOF
)
fi
        FQDN_IP_VALUE=$(/sbin/ip -o -4 addr list "${fqdn_autodetect_interface}" | awk '{print $4}' | cut -d/ -f1 | head -n1);
    else
        FQDN_IP_VALUE="${FQDN_IP}"
    fi

    if grep -q "${FQDN}" "${HOSTS_FILE}"; then
        sed "s@.*${FQDN}@${FQDN_IP_VALUE} ${FQDN}@g" "${HOSTS_FILE}" > /tmp/tmpfile;
        cat /tmp/tmpfile > "${HOSTS_FILE}"
    else
        ## append directly
        echo "${FQDN_IP_VALUE}" "${FQDN}" >> "${HOSTS_FILE}";
    fi


fi

if [ -n "${VRRBOSE}" ]; then set +x; fi




exec "$@" -f /usr/local/etc/haproxy/local.cfg