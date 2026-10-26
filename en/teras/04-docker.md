<!-- generated from kandungan/en/teras/04-docker.md by alat/bina.py: edit the template, not this file -->
# 4. Docker, without opening holes in the firewall

**Short answer:** install Docker from Docker's own package repository, cap the size of container logs, and publish
container ports on `127.0.0.1` only. A port published the usual way (`-p 8080:80`) is reachable
from the whole internet even though `ufw` from chapter 3 blocks it, because Docker writes its own firewall rules ahead of
`ufw`. The steps below show this from your computer, then close the hole.

Tested on: `ubuntu:24.04` (VM), 2026-10-26.

Run these steps as the user from chapter 2, on a server that already has the firewall from chapter 3. Steps marked "on
your computer" run in a terminal on your own machine.

## 1. Install Docker from Docker's repository

Ubuntu's own `docker.io` package is often several versions behind. These are the commands from Docker's installation
page: add Docker's signing key, add the repository for your Ubuntu release, install the engine and the Compose plugin.

```bash
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo docker version --format 'Docker Engine {{.Server.Version}}'
sudo docker compose version
```

This guide runs Docker with `sudo` and does not add your user to the `docker` group. Membership of that group is the
same as having root without a password, so an attacker who gets into your user account would own the whole server.

## 2. Keep container logs small

By default Docker keeps every line a container prints, forever. An agent that logs each message can fill a small disk
in weeks. The `local` log driver below keeps at most three files of 10 MB per container. It applies to containers
created after the change.

```bash
sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
  "log-driver": "local",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
sudo systemctl restart docker
sudo docker info --format 'log driver: {{.LoggingDriver}}'
```

## 3. Check that Docker works

```bash
sudo docker run --rm hello-world | grep 'Hello from Docker!'
```

## 4. See the problem: a published port bypasses `ufw`

Start a small web server in a container and publish it on port 8080, the way most examples on
the internet do. The first line shows that `ufw` is active.

```bash
sudo ufw status | sed -n 1p
sudo docker run -d --name port-test -p 8080:80 nginx:alpine
for _ in $(seq 30); do curl -fsS -o /dev/null http://127.0.0.1:8080/ && break; sleep 1; done
sudo docker port port-test
```

Now check from your computer. Chapter 3 blocked this port, yet it answers:

```bash
nc -z -w 5 203.0.113.10 8080 && echo "port 8080 reachable from outside, although ufw only allows SSH"
```

Docker sends traffic for published ports through its own `iptables` chains, which the kernel checks before the `ufw`
rules. `ufw status` will not show these ports either, so the firewall looks closed while it is open.

## 5. Publish on `127.0.0.1` only

Put `127.0.0.1:` in front of the port. The container is then reachable from programs on the server (such as the reverse
proxy in chapter 5) and from nowhere else.

```bash
sudo docker rm -f port-test
sudo docker run -d --name port-test -p 127.0.0.1:8080:80 nginx:alpine
for _ in $(seq 30); do curl -fsS -o /dev/null http://127.0.0.1:8080/ && break; sleep 1; done
curl -fsS -o /dev/null -w 'on the server: HTTP %{http_code}\n' http://127.0.0.1:8080/
sudo docker port port-test
```

Check again from your computer:

```bash
if nc -z -w 5 203.0.113.10 8080; then
  echo "port 8080 is still reachable from outside"
  exit 1
fi
echo "port 8080 blocked from outside"
```

## 6. The same rule in Docker Compose

Most agents ship a `compose.yaml`. Before you start one, look at every `ports:` line and make sure it starts with
`127.0.0.1:`. Here is a small example:

```bash
sudo docker rm -f port-test
sudo install -d /srv/port-test
sudo tee /srv/port-test/compose.yaml >/dev/null <<'EOF'
services:
  web:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:80"
EOF
cd /srv/port-test
sudo docker compose up -d --wait
sudo docker compose ps --format '{{.Name}}: {{.Ports}}'
curl -fsS -o /dev/null -w 'on the server: HTTP %{http_code}\n' http://127.0.0.1:8080/
```

From your computer:

```bash
if nc -z -w 5 203.0.113.10 8080; then
  echo "port 8080 is reachable from outside"
  exit 1
fi
echo "port 8080 blocked from outside"
```

If a service does not need to be reached from the server at all (for example a database used only by other
containers), remove its `ports:` lines. Containers in the same Compose file reach each other by service name without
any published port.

## 7. Clean up

Remove the test containers and images. Docker stays installed for the agent chapters.

```bash
cd /srv/port-test
sudo docker compose down
cd /
sudo rm -r /srv/port-test
sudo docker image rm nginx:alpine hello-world
echo "containers left: $(sudo docker ps -aq | wc -l)"
```
