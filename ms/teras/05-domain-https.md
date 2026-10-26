<!-- generated from kandungan/ms/teras/05-domain-https.md by alat/bina.py: edit the template, not this file -->
# 5. Nama domain dan HTTPS

**Jawapan ringkas:** halakan nama seperti `agent.example.com` ke pelayan anda dengan rekod DNS `A`, buka
port 80 dan 443, dan letakkan Caddy di hadapan ejen. Caddy mendapatkan sijil Let's
Encrypt percuma sendiri, memperbaharuinya sebelum tamat tempoh, dan meneruskan permintaan kepada ejen di
`127.0.0.1:8080`, yang kekal tertutup kepada internet.

Diuji pada: `ubuntu:24.04` (VM), 2026-10-25.

Cara bab ini diuji: `example.com` ialah nama simpanan yang tiada siapa boleh dapatkan sijil untuknya, jadi
rangkaian ujian memainkan peranan internet. Ia menghalakan `agent.example.com` ke pelayan ujian, dan
menjawab alamat Let's Encrypt dengan Pebble, pihak berkuasa sijil ujian yang diterbitkan oleh Let's Encrypt. Pebble
menyemak pelayan dari luar sebelum mengeluarkan apa-apa, sama seperti Let's Encrypt. Arahan di halaman ini dijalankan
tepat seperti ditulis; pelayan anda berhubung dengan Let's Encrypt yang sebenar.

Jalankan langkah ini sebagai pengguna dari bab 2, pada pelayan yang sudah ada firewall dari bab 3. Gantikan
`agent.example.com`, `admin@example.com` dan `203.0.113.10` dengan nama, alamat
emel dan alamat pelayan anda sendiri.

## 1. Halakan nama ke pelayan anda

Di syarikat tempat anda membeli domain (atau di mana sahaja DNSnya dihoskan), tambah satu rekod:

| Jenis | Nama | Nilai |
|---|---|---|
| `A` | `agent` | `203.0.113.10` |

Jika pelayan anda juga ada alamat IPv6, tambah rekod `AAAA` dengannya, atau jangan letak IPv6 langsung: rekod `AAAA`
yang salah menggagalkan sijil. Perubahan boleh mengambil beberapa minit untuk tersebar. Semak dari komputer anda; baris
pertama sepatutnya menunjukkan alamat pelayan anda:

```bash
ping -c 1 agent.example.com
```

Sesetengah penyedia menyekat balasan ping. Itu tidak mengapa selagi alamatnya betul.

## 2. Mulakan pengganti ejen

Ejen dipasang dalam bab kemudian. Sehingga itu, pelayan web kecil ini memainkan peranannya di
`127.0.0.1:8080`.

```bash
sudo install -d /srv/agent-test
echo "hello from the agent" | sudo tee /srv/agent-test/index.html >/dev/null
sudo systemd-run --unit=agent-test python3 -m http.server 8080 --bind 127.0.0.1 --directory /srv/agent-test
for _ in $(seq 20); do curl -fsS -o /dev/null http://127.0.0.1:8080/ && break; sleep 1; done
curl -fsS http://127.0.0.1:8080/
```

## 3. Pasang Caddy

Ini arahan dari halaman pemasangan Caddy untuk Ubuntu. Ia menambah repositori pakej Caddy, jadi `apt` mengemas kininya
bersama sistem yang lain.

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

## 4. Buka port 80 dan 443

Let's Encrypt menyemak bahawa anda mengawal nama itu dengan menyambung ke pelayan anda pada port ini, dan pelawat juga
memakainya.

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw status
```

## 5. Beritahu Caddy nama anda

Seluruh konfigurasi hanya beberapa baris. Alamat emel ialah tempat Let's Encrypt menulis jika ada masalah dengan sijil
anda.

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

## 6. Tunggu sijil

Caddy meminta sijil sebaik sahaja ia dimuat semula. Biasanya ini mengambil beberapa saat.

```bash
for _ in $(seq 60); do
  sudo journalctl -u caddy --no-pager | grep 'certificate obtained successfully' >/dev/null && break
  sleep 2
done
sudo journalctl -u caddy --no-pager -o cat | grep 'certificate obtained successfully' | tail -n 1
```

Jika sijil tidak tiba, `sudo journalctl -u caddy --no-pager | tail -n 30` menunjukkan sebabnya. Punca biasa ialah rekod
DNS yang menghala ke tempat lain, atau port 80 dan 443 masih tertutup (semak `ufw`
dan juga firewall dalam panel kawalan penyedia anda).

## 7. Semak dari komputer anda

Halaman tiba melalui HTTPS dengan sijil yang sah, dan HTTP biasa dialihkan ke HTTPS.

```bash
curl -fsS https://agent.example.com/
curl -sS -o /dev/null -w 'http://  -> HTTP %{http_code} %{redirect_url}\n' http://agent.example.com/
curl -fsS -o /dev/null -w 'https:// -> HTTP %{http_code}, certificate check %{ssl_verify_result} (0 = valid)\n' https://agent.example.com/
```

Port ejen sendiri kekal tertutup. Hanya Caddy, di pelayan yang sama, boleh mencapainya:

```bash
if nc -z -w 5 203.0.113.10 8080; then
  echo "port 8080 is reachable from outside"
  exit 1
fi
echo "port 8080 blocked from outside: only Caddy reaches the agent"
```

## 8. Hentikan pengganti

```bash
sudo systemctl stop agent-test
sudo rm -r /srv/agent-test
```

Sehingga ejen dipasang, alamat itu menjawab dengan halaman ralat (HTTP 502). Bab ejen memberitahu Caddy port yang ejen
pakai, jika berbeza daripada 8080. Caddy memperbaharui sijil sendiri jauh sebelum tamat
tempoh; tiada apa-apa yang perlu dijadualkan.
