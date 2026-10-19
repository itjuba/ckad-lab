# Pod with a named port and an IP script

Namespace: `lyra`

Team Lyra needs a web server Pod and a small script their on-call engineers can run.

1. Create a Pod named `lyra-web` in Namespace `lyra`:
   - image `httpd:2.4-alpine`
   - container name `lyra-web-container`
   - container port `80`, named `http`

2. Write a script `/opt/course/2/pod-ip.sh` that prints only the IP address of
   that Pod (nothing else). Use `kubectl`, not the `k` alias.
