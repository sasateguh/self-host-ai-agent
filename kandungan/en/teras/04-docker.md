# 4. Docker, without opening holes in the firewall

**Short answer:** install Docker from Docker's own package repository, cap the size of container logs, and publish
container ports on `127.0.0.1` only. A port published the usual way (`-p {{config:port.ejen_dalaman}}:80`) is reachable
from the whole internet even though `ufw` from chapter 3 blocks it, because Docker writes its own firewall rules ahead of
`ufw`. The steps below show this from your computer, then close the hole.

Tested on: {{diuji:teras/04-docker}}.

Run these steps as the user from chapter 2, on a server that already has the firewall from chapter 3. Steps marked "on
your computer" run in a terminal on your own machine.

## 1. Install Docker from Docker's repository

Ubuntu's own `docker.io` package is often several versions behind. These are the commands from Docker's installation
page: add Docker's signing key, add the repository for your Ubuntu release, install the engine and the Compose plugin.

{{langkah:teras/04-docker/pasang}}

This guide runs Docker with `sudo` and does not add your user to the `docker` group. Membership of that group is the
same as having root without a password, so an attacker who gets into your user account would own the whole server.

## 2. Keep container logs small

By default Docker keeps every line a container prints, forever. An agent that logs each message can fill a small disk
in weeks. The `local` log driver below keeps at most three files of 10 MB per container. It applies to containers
created after the change.

{{langkah:teras/04-docker/log}}

## 3. Check that Docker works

{{langkah:teras/04-docker/hello}}

## 4. See the problem: a published port bypasses `ufw`

Start a small web server in a container and publish it on port {{config:port.ejen_dalaman}}, the way most examples on
the internet do. The first line shows that `ufw` is active.

{{langkah:teras/04-docker/terbit-semua}}

Now check from your computer. Chapter 3 blocked this port, yet it answers:

{{langkah:teras/04-docker/terbit-semua-luar}}

Docker sends traffic for published ports through its own `iptables` chains, which the kernel checks before the `ufw`
rules. `ufw status` will not show these ports either, so the firewall looks closed while it is open.

## 5. Publish on `127.0.0.1` only

Put `127.0.0.1:` in front of the port. The container is then reachable from programs on the server (such as the reverse
proxy in chapter 5) and from nowhere else.

{{langkah:teras/04-docker/terbit-tempatan}}

Check again from your computer:

{{langkah:teras/04-docker/terbit-tempatan-luar}}

## 6. The same rule in Docker Compose

Most agents ship a `compose.yaml`. Before you start one, look at every `ports:` line and make sure it starts with
`127.0.0.1:`. Here is a small example:

{{langkah:teras/04-docker/compose}}

From your computer:

{{langkah:teras/04-docker/compose-luar}}

If a service does not need to be reached from the server at all (for example a database used only by other
containers), remove its `ports:` lines. Containers in the same Compose file reach each other by service name without
any published port.

## 7. Clean up

Remove the test containers and images. Docker stays installed for the agent chapters.

{{langkah:teras/04-docker/kemas}}
