<!-- generated from kandungan/ms/teras/03-firewall-kemas-kini.md by alat/bina.py: edit the template, not this file -->
# 3. Firewall dan kemas kini automatik

**Jawapan ringkas:** pasang kemas kini terkini, kemudian hidupkan `ufw` supaya hanya SSH boleh sampai ke pelayan dari
luar, dan hidupkan `unattended-upgrades` supaya pembaikan keselamatan dipasang sendiri setiap hari. Langkah di bawah
memulakan pelayan web sementara pada port 8080 dan menyemaknya dari komputer anda sebelum dan
selepas firewall, jadi anda melihat firewall menyekat port yang benar-benar sedang mendengar.

Diuji pada: `ubuntu:24.04` (VM), 2026-10-25.

Jalankan langkah ini sebagai pengguna dari bab 2 (`ssh ejen@203.0.113.10`). Langkah
bertanda "di komputer anda" dijalankan dalam terminal di mesin anda sendiri.

## 1. Pasang kemas kini

Jika baris terakhir menyatakan but semula diperlukan, jalankan `sudo reboot`, tunggu seminit dan log masuk semula.

```bash
sudo apt-get update
sudo apt-get -y upgrade
if [ -f /var/run/reboot-required ]; then echo "A reboot is required to finish the update."; fi
```

## 2. Mulakan pelayan ujian sementara

Ini menghidangkan folder kosong pada port 8080, port yang mungkin didengar oleh ejen kelak.

```bash
sudo systemd-run --unit=firewall-test python3 -m http.server 8080 --directory /srv
for _ in $(seq 20); do curl -fsS -o /dev/null http://127.0.0.1:8080/ && break; sleep 1; done
curl -fsS -o /dev/null -w 'test server: HTTP %{http_code}\n' http://127.0.0.1:8080/
```

## 3. Semak dari luar (di komputer anda)

Tanpa firewall, sesiapa boleh sampai kepadanya.

```bash
nc -z -w 5 203.0.113.10 8080 && echo "port 8080 reachable from outside (no firewall yet)"
```

## 4. Hidupkan firewall

Peraturan ini menyekat setiap sambungan masuk kecuali SSH, dan membenarkan semua sambungan keluar (kemas kini, penyedia
model, Telegram). Benarkan SSH sebelum `ufw enable`, atau firewall memutuskan sesi anda sendiri.

```bash
sudo apt-get install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw --force enable
sudo ufw status verbose
```

## 5. Semak semula (di komputer anda)

Pelayan ujian masih berjalan, tetapi port itu kini disekat dari luar, manakala SSH kekal terbuka.

```bash
if nc -z -w 5 203.0.113.10 8080; then
  echo "port 8080 is still reachable: the firewall is not blocking it"
  exit 1
fi
echo "port 8080 blocked from outside"
nc -z -w 5 203.0.113.10 22 && echo "port 22 (SSH) still open"
```

Bab 5 membuka port 80 dan 443 untuk HTTPS. Ejen sendiri tidak pernah memerlukan port
terbuka: proksi terbalik mencapainya di dalam pelayan. Docker boleh menerbitkan port melepasi `ufw`; bab 4 menunjukkan
cara mengelakkannya.

## 6. Hentikan pelayan ujian

```bash
sudo systemctl stop firewall-test
```

## 7. Hidupkan kemas kini keselamatan automatik

`unattended-upgrades` memasang pembaikan keselamatan sekali sehari. Dua tetapan di bawah menghidupkan muat semula senarai
pakej harian dan naik taraf itu sendiri. Larian cubaan di hujung menunjukkan apa yang akan dibuatnya sekarang, tanpa
mengubah apa-apa.

```bash
sudo apt-get install -y unattended-upgrades
sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
apt-config dump APT::Periodic::Unattended-Upgrade
systemctl is-enabled apt-daily-upgrade.timer
sudo unattended-upgrade --dry-run
echo "unattended upgrades: dry run passed"
```

Sesetengah pembaikan, seperti kernel baharu, hanya berkuat kuasa selepas but semula. Semak `/var/run/reboot-required`
bila anda log masuk, atau baca bab 9 untuk pemantauan yang memberitahu anda.
