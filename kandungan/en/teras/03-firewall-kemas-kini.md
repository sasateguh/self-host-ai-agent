# 3. Firewall and automatic updates

**Short answer:** install the latest updates, then turn on `ufw` so that only SSH can reach the server from outside,
and turn on `unattended-upgrades` so security fixes install themselves every day. The steps start a temporary web
server on port {{config:port.ejen_dalaman}} and check it from your computer before and after the firewall, so you see
the firewall block a port that is really listening.

Tested on: {{diuji:teras/03-firewall-kemas-kini}}.

Run these steps as the user from chapter 2 (`ssh {{config:contoh.pengguna}}@{{config:contoh.ip_vps}}`). Steps marked
"on your computer" run in a terminal on your own machine.

## 1. Install updates

If the last line says a reboot is required, run `sudo reboot`, wait a minute and log in again.

{{langkah:teras/03-firewall-kemas-kini/kemas-kini}}

## 2. Start a temporary test server

This serves an empty folder on port {{config:port.ejen_dalaman}}, the port an agent might listen on later.

{{langkah:teras/03-firewall-kemas-kini/pelayan-cuba}}

## 3. Check it from outside (on your computer)

Without a firewall, anyone can reach it.

{{langkah:teras/03-firewall-kemas-kini/sebelum}}

## 4. Turn on the firewall

The rules block every incoming connection except SSH, and allow everything outgoing (updates, the model provider,
Telegram). Allow SSH before `ufw enable`, or the firewall cuts off your own session.

{{langkah:teras/03-firewall-kemas-kini/ufw}}

## 5. Check again (on your computer)

The test server is still running, but the port is now blocked from outside, while SSH stays open.

{{langkah:teras/03-firewall-kemas-kini/selepas}}

Chapter 5 opens ports {{config:port.http}} and {{config:port.https}} for HTTPS. The agent itself never needs an open
port: the reverse proxy reaches it on the server. Docker can publish ports past `ufw`; chapter 4 shows how to avoid
that.

## 6. Stop the test server

{{langkah:teras/03-firewall-kemas-kini/henti-pelayan-cuba}}

## 7. Turn on automatic security updates

`unattended-upgrades` installs security fixes once a day. The two settings below turn on the daily package list
refresh and the upgrade itself. The dry run at the end shows what it would do now, without changing anything.

{{langkah:teras/03-firewall-kemas-kini/kemas-kini-automatik}}

Some fixes, such as a new kernel, only take effect after a reboot. Check for `/var/run/reboot-required` when you log in,
or read chapter 9 for monitoring that tells you.
