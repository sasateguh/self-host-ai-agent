<!-- generated from kandungan/en/teras/05-domain-https.md by alat/bina.py: edit the template, not this file -->
# 5. Domain name and HTTPS

**Short answer:** point a name such as `agent.example.com` at your server with a DNS `A` record, open
ports 80 and 443, and put Caddy in front of the agent. Caddy gets a free Let's
Encrypt certificate by itself, renews it before it expires, and forwards requests to the agent on
`127.0.0.1:8080`, which stays closed to the internet.

Tested on: `ubuntu:24.04` (VM), 2026-10-25.

How this chapter is tested: `example.com` is a reserved name that nobody can get a certificate for, so the
test network plays the part of the internet. It points `agent.example.com` at the test server, and
answers Let's Encrypt's address with Pebble, the test certificate authority published by Let's Encrypt. Pebble checks
the server from outside before it issues anything, the same way Let's Encrypt does. The commands on this page are run
exactly as written; your server talks to the real Let's Encrypt.

Run these steps as the user from chapter 2, on a server that has the firewall from chapter 3. Replace
`agent.example.com`, `admin@example.com` and `203.0.113.10` with your own name,
email address and server address.

## 1. Point the name at your server

At the company where you bought the domain (or wherever its DNS is hosted), add a record:

| Type | Name | Value |
|---|---|---|
| `A` | `agent` | `203.0.113.10` |

If your server also has an IPv6 address, add an `AAAA` record with it, or leave IPv6 out entirely: a wrong `AAAA` record
makes the certificate fail. Changes can take a few minutes to spread. Check from your computer; the first line should
show your server's address:

```bash
ping -c 1 agent.example.com
```

Some providers block ping replies. That is fine as long as the address is right.

## 2. Start a stand-in for the agent

The agent is installed in a later chapter. Until then, this small web server plays its part on
`127.0.0.1:8080`.

```bash
sudo install -d /srv/agent-test
echo "hello from the agent" | sudo tee /srv/agent-test/index.html >/dev/null
sudo systemd-run --unit=agent-test python3 -m http.server 8080 --bind 127.0.0.1 --directory /srv/agent-test
for _ in $(seq 20); do curl -fsS -o /dev/null http://127.0.0.1:8080/ && break; sleep 1; done
curl -fsS http://127.0.0.1:8080/
```

## 3. Install Caddy

These are the commands from Caddy's installation page for Ubuntu. They add Caddy's package repository, so `apt` keeps it
up to date with the rest of the system.

```bash
sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
  | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
  | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
sudo chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update
sudo apt-get install -y caddy
caddy version
systemctl is-active caddy
```

## 4. Open ports 80 and 443

Let's Encrypt checks that you control the name by connecting to your server on these ports, and visitors use them.

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw status
```

## 5. Tell Caddy about your name

The whole configuration is a few lines. The email address is where Let's Encrypt writes if something is wrong with your
certificate.

```bash
sudo tee /etc/caddy/Caddyfile >/dev/null <<'EOF'
{
	email admin@example.com
}

agent.example.com {
	reverse_proxy 127.0.0.1:8080
}
EOF
sudo caddy validate --config /etc/caddy/Caddyfile 2>&1 | tail -n 1
sudo systemctl reload caddy
```

## 6. Wait for the certificate

Caddy asks for the certificate as soon as it reloads. This usually takes a few seconds.

```bash
for _ in $(seq 60); do
  sudo journalctl -u caddy --no-pager | grep 'certificate obtained successfully' >/dev/null && break
  sleep 2
done
sudo journalctl -u caddy --no-pager -o cat | grep 'certificate obtained successfully' | tail -n 1
```

If the certificate does not arrive, `sudo journalctl -u caddy --no-pager | tail -n 30` shows why. The usual causes are a
DNS record that points somewhere else, or ports 80 and 443 still closed (check both
`ufw` and any firewall in your provider's control panel).

## 7. Check from your computer

The page arrives over HTTPS with a valid certificate, and plain HTTP is redirected to HTTPS.

```bash
curl -fsS https://agent.example.com/
curl -sS -o /dev/null -w 'http://  -> HTTP %{http_code} %{redirect_url}\n' http://agent.example.com/
curl -fsS -o /dev/null -w 'https:// -> HTTP %{http_code}, certificate check %{ssl_verify_result} (0 = valid)\n' https://agent.example.com/
```

The agent's own port stays closed. Only Caddy, on the same server, can reach it:

```bash
if nc -z -w 5 203.0.113.10 8080; then
  echo "port 8080 is reachable from outside"
  exit 1
fi
echo "port 8080 blocked from outside: only Caddy reaches the agent"
```

## 8. Stop the stand-in

```bash
sudo systemctl stop agent-test
sudo rm -r /srv/agent-test
```

Until the agent is installed, the address answers with an error page (HTTP 502). The agent chapters tell Caddy which
port the agent uses, if it differs from 8080. Caddy renews the certificate by itself well before it
expires; there is nothing to schedule.
