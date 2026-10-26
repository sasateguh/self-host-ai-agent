# 5. Domain name and HTTPS

**Short answer:** point a name such as `{{config:contoh.subdomain_ejen}}` at your server with a DNS `A` record, open
ports {{config:port.http}} and {{config:port.https}}, and put Caddy in front of the agent. Caddy gets a free Let's
Encrypt certificate by itself, renews it before it expires, and forwards requests to the agent on
`127.0.0.1:{{config:port.ejen_dalaman}}`, which stays closed to the internet.

Tested on: {{diuji:teras/05-domain-https}}.

How this chapter is tested: `{{config:contoh.domain}}` is a reserved name that nobody can get a certificate for, so the
test network plays the part of the internet. It points `{{config:contoh.subdomain_ejen}}` at the test server, and
answers Let's Encrypt's address with Pebble, the test certificate authority published by Let's Encrypt. Pebble checks
the server from outside before it issues anything, the same way Let's Encrypt does. The commands on this page are run
exactly as written; your server talks to the real Let's Encrypt.

Run these steps as the user from chapter 2, on a server that has the firewall from chapter 3. Replace
`{{config:contoh.subdomain_ejen}}`, `{{config:contoh.emel_sijil}}` and `{{config:contoh.ip_vps}}` with your own name,
email address and server address.

## 1. Point the name at your server

At the company where you bought the domain (or wherever its DNS is hosted), add a record:

| Type | Name | Value |
|---|---|---|
| `A` | `agent` | `{{config:contoh.ip_vps}}` |

If your server also has an IPv6 address, add an `AAAA` record with it, or leave IPv6 out entirely: a wrong `AAAA` record
makes the certificate fail. Changes can take a few minutes to spread. Check from your computer; the first line should
show your server's address:

{{langkah:teras/05-domain-https/dns}}

Some providers block ping replies. That is fine as long as the address is right.

## 2. Start a stand-in for the agent

The agent is installed in a later chapter. Until then, this small web server plays its part on
`127.0.0.1:{{config:port.ejen_dalaman}}`.

{{langkah:teras/05-domain-https/ejen-cuba}}

## 3. Install Caddy

These are the commands from Caddy's installation page for Ubuntu. They add Caddy's package repository, so `apt` keeps it
up to date with the rest of the system.

{{langkah:teras/05-domain-https/pasang-caddy}}

## 4. Open ports {{config:port.http}} and {{config:port.https}}

Let's Encrypt checks that you control the name by connecting to your server on these ports, and visitors use them.

{{langkah:teras/05-domain-https/firewall}}

## 5. Tell Caddy about your name

The whole configuration is a few lines. The email address is where Let's Encrypt writes if something is wrong with your
certificate.

{{langkah:teras/05-domain-https/caddyfile}}

## 6. Wait for the certificate

Caddy asks for the certificate as soon as it reloads. This usually takes a few seconds.

{{langkah:teras/05-domain-https/sijil}}

If the certificate does not arrive, `sudo journalctl -u caddy --no-pager | tail -n 30` shows why. The usual causes are a
DNS record that points somewhere else, or ports {{config:port.http}} and {{config:port.https}} still closed (check both
`ufw` and any firewall in your provider's control panel).

## 7. Check from your computer

The page arrives over HTTPS with a valid certificate, and plain HTTP is redirected to HTTPS.

{{langkah:teras/05-domain-https/https}}

The agent's own port stays closed. Only Caddy, on the same server, can reach it:

{{langkah:teras/05-domain-https/port-dalaman}}

## 8. Stop the stand-in

{{langkah:teras/05-domain-https/henti-ejen-cuba}}

Until the agent is installed, the address answers with an error page (HTTP 502). The agent chapters tell Caddy which
port the agent uses, if it differs from {{config:port.ejen_dalaman}}. Caddy renews the certificate by itself well before it
expires; there is nothing to schedule.
