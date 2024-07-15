# local-haproxy

use `bash` and env generate `/usr/local/etc/haproxy/local.cfg` and append `-f /usr/local/etc/haproxy/local.cfg` to haproxy

## features

- keepalived-free
- update host `/etc/hosts` if set `FQDN` and `FQDN_IP`
- healthcheck

## envs

| name                         | describe                       | default                      |
|------------------------------|--------------------------------|------------------------------|
| IP                           | fronted ip                     | autodetect                   |
| IP_AUTODETECTION_METHOD      | fronted ip autodetection       | first-found                  |
| PORT                         | fronted port                   | 8443                         |
| FRONTEND_NAME                | fronted name                   | frontend_${PORT}             |
| BACKEND_NAME                 | backend name                   | backend_${PORT}              |
| MODE                         | mode                           | tcp                          |
| FRONTEND_MODE                | fronted mode                   | ${MODE}                      |
| BACKEND_MODE                 | backend mode                   | ${MODE}                      |
| BALANCE                      | balance                        | roundrobin                   |
| ADV_CHECK                    | adv_check                      | httpchk                      |
| HTTP_CHECK                   | http_check                     | http-check expect status 200 |
| HTTPCHK_PARAMS               | httpcheck_params               | GET /livez                   |
| BACKEND_SERVER               | backend_server comma separated |                              |
| FQDN_IP                      | fqdn_ip                        | autodetect                   |
| FQDN_IP_AUTODETECTION_METHOD | fqdn_ip autodetection          | ${IP_AUTODETECTION_METHOD}   |
| FQDN                         | fqdn                           |                              |
| HOSTS_FILE                   | hosts file path                | /host/etc/hosts              |
| VRRBOSE                      | verbose                        |                              |

## run

### docker

```bash
docker \
run \
-d \
--name local-haproxy \
--restart always \
--privileged \
--network host \
--env "IP_AUTODETECTION_METHOD=interface=eth1" \
--env "BACKEND_SERVER=192.168.55.111:6443 check check-ssl verify none,192.168.55.112:6443 check check-ssl verify none,192.168.55.113:6443 check check-ssl verify none" \
--env "FQDN=demo.local" \
--env "FQDN_IP_AUTODETECTION_METHOD=interface=eth1" \
--volume /etc/hosts:/host/etc/hosts:rw \
dyrnq/local-haproxy:latest
```

### kubernetes static-pod

```bash
cat > /etc/kubernetes/manifests/local-haproxy.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: local-haproxy
  namespace: kube-system
spec:
  hostNetwork: true
  nodeSelector:
    kubernetes.io/os: linux
  containers:
  - name: haproxy
    resources:
      requests:
        cpu: 250m
    image: dyrnq/local-haproxy:latest
    imagePullPolicy: IfNotPresent
    env:
    - name: IP_AUTODETECTION_METHOD
      value: "interface=eth1"
    - name: PORT
      value: "8443"
    - name: BACKEND_SERVER
      value: "192.168.55.111:6443 check check-ssl verify none,192.168.55.112:6443 check check-ssl verify none,192.168.55.113:6443 check check-ssl verify none"
    - name: FQDN
      value: "demo.local"
    volumeMounts:
    - mountPath: /host/etc/hosts
      name: etc-hosts-dir
      readOnly: false
    - mountPath: /etc/localtime
      name: localtime
      readOnly: true
    - mountPath: /usr/local/share/ca-certificates
      name: usr-local-share-ca-certificates
      readOnly: true
    - mountPath: /usr/share/ca-certificates
      name: usr-share-ca-certificates
      readOnly: true
  volumes:
  - hostPath:
      path: /etc/hosts
      type: ""
    name: etc-hosts-dir
  - hostPath:
      path: /etc/localtime
      type: ""
    name: localtime
  - hostPath:
      path: /usr/local/share/ca-certificates
      type: DirectoryOrCreate
    name: usr-local-share-ca-certificates
  - hostPath:
      path: /usr/share/ca-certificates
      type: DirectoryOrCreate
    name: usr-share-ca-certificates
EOF
```


```bash
kubectl logs local-haproxy-master2 -n kube-system
frontend frontend_8443
  mode tcp
  bind 192.168.55.112:8443 name frontend_8443
  default_backend backend_8443


backend backend_8443
  description backend_8443
  mode tcp
  balance roundrobin
  option httpchk GET /livez
  http-check expect status 200
  server server_0 192.168.55.111:6443 check check-ssl verify none
  server server_1 192.168.55.112:6443 check check-ssl verify none
  server server_2 192.168.55.113:6443 check check-ssl verify none
[NOTICE]   (1) : haproxy version is 3.0.2-a45a8e6
[NOTICE]   (1) : path to executable is /usr/local/sbin/haproxy
[WARNING]  (1) : config : parsing [/usr/local/etc/haproxy/haproxy.cfg:46] : 'option httplog' not usable with frontend 'frontend_8443' (needs 'mode http'). Falling back to 'option tcplog'.
[WARNING]  (1) : config : 'option forwardfor' ignored for frontend 'frontend_8443' as it requires HTTP mode.
[WARNING]  (1) : config : 'option forwardfor' ignored for backend 'backend_8443' as it requires HTTP mode.
[NOTICE]   (1) : New worker (29) forked
[NOTICE]   (1) : Loading success.
```

```bash
curl -k https://demo.local:8443/livez
```

## ref

- [haproxytech/haproxy-debian](https://hub.docker.com/r/haproxytech/haproxy-debian)
- [haproxytech/haproxy-docker-debian/blob/main/3.0/Dockerfile](https://github.com/haproxytech/haproxy-docker-debian/blob/main/3.0/Dockerfile)
- [haproxytech/haproxy-docker-debian/blob/main/3.0/docker-entrypoint.sh](https://github.com/haproxytech/haproxy-docker-debian/blob/main/3.0/docker-entrypoint.sh)