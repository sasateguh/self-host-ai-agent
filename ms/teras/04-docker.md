<!-- generated from kandungan/ms/teras/04-docker.md by alat/bina.py: edit the template, not this file -->
# 4. Docker, tanpa membuka lubang pada firewall

**Jawapan ringkas:** pasang Docker dari repositori pakej Docker sendiri, hadkan saiz log bekas, dan terbitkan port bekas
pada `127.0.0.1` sahaja. Port yang diterbitkan cara biasa (`-p 8080:80`) boleh dicapai dari
seluruh internet walaupun `ufw` dari bab 3 menyekatnya, kerana Docker menulis peraturan firewallnya sendiri di hadapan
`ufw`. Langkah di bawah menunjukkan perkara ini dari komputer anda, kemudian menutup lubang itu.

Diuji pada: `ubuntu:24.04` (VM), 2026-10-26.

Jalankan langkah ini sebagai pengguna dari bab 2, pada pelayan yang sudah ada firewall dari bab 3. Langkah bertanda "di
komputer anda" dijalankan dalam terminal di mesin anda sendiri.

## 1. Pasang Docker dari repositori Docker

Pakej `docker.io` Ubuntu sering ketinggalan beberapa versi. Ini arahan dari halaman pemasangan Docker: tambah kunci
tandatangan Docker, tambah repositori untuk keluaran Ubuntu anda, pasang enjin dan pemalam Compose.

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

Panduan ini menjalankan Docker dengan `sudo` dan tidak menambah pengguna anda ke kumpulan `docker`. Ahli kumpulan itu
sama seperti memegang root tanpa kata laluan, jadi penyerang yang masuk ke akaun anda akan menguasai seluruh pelayan.

## 2. Kecilkan log bekas

Secara lalai Docker menyimpan setiap baris yang dicetak bekas, selama-lamanya. Ejen yang merekod setiap mesej boleh
memenuhkan cakera kecil dalam beberapa minggu. Pemacu log `local` di bawah menyimpan paling banyak tiga fail 10 MB bagi
setiap bekas. Ia terpakai pada bekas yang dicipta selepas perubahan ini.

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

## 3. Semak Docker berfungsi

```bash
sudo docker run --rm hello-world | grep 'Hello from Docker!'
```

## 4. Lihat masalahnya: port yang diterbitkan melepasi `ufw`

Mulakan pelayan web kecil dalam bekas dan terbitkan pada port 8080, seperti kebanyakan contoh
di internet. Baris pertama menunjukkan `ufw` aktif.

```bash
sudo ufw status | sed -n 1p
sudo docker run -d --name port-test -p 8080:80 nginx:alpine
for _ in $(seq 30); do curl -fsS -o /dev/null http://127.0.0.1:8080/ && break; sleep 1; done
sudo docker port port-test
```

Sekarang semak dari komputer anda. Bab 3 sudah menyekat port ini, tetapi ia tetap menjawab:

```bash
nc -z -w 5 203.0.113.10 8080 && echo "port 8080 reachable from outside, although ufw only allows SSH"
```

Docker menghantar trafik port yang diterbitkan melalui rantaian `iptables` miliknya, yang disemak oleh kernel sebelum
peraturan `ufw`. `ufw status` juga tidak memaparkan port ini, jadi firewall nampak tertutup sedangkan ia terbuka.

## 5. Terbitkan pada `127.0.0.1` sahaja

Letakkan `127.0.0.1:` di hadapan port. Bekas itu kemudian boleh dicapai oleh program di pelayan (seperti proksi
terbalik dalam bab 5) dan tidak dari tempat lain.

```bash
sudo docker rm -f port-test
sudo docker run -d --name port-test -p 127.0.0.1:8080:80 nginx:alpine
for _ in $(seq 30); do curl -fsS -o /dev/null http://127.0.0.1:8080/ && break; sleep 1; done
curl -fsS -o /dev/null -w 'on the server: HTTP %{http_code}\n' http://127.0.0.1:8080/
sudo docker port port-test
```

Semak sekali lagi dari komputer anda:

```bash
if nc -z -w 5 203.0.113.10 8080; then
  echo "port 8080 is still reachable from outside"
  exit 1
fi
echo "port 8080 blocked from outside"
```

## 6. Peraturan yang sama dalam Docker Compose

Kebanyakan ejen datang dengan `compose.yaml`. Sebelum memulakannya, lihat setiap baris `ports:` dan pastikan ia bermula
dengan `127.0.0.1:`. Ini contoh kecil:

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

Dari komputer anda:

```bash
if nc -z -w 5 203.0.113.10 8080; then
  echo "port 8080 is reachable from outside"
  exit 1
fi
echo "port 8080 blocked from outside"
```

Jika satu servis tidak perlu dicapai dari pelayan langsung (contohnya pangkalan data yang hanya dipakai bekas lain),
buang baris `ports:` servis itu. Bekas dalam fail Compose yang sama mencapai satu sama lain melalui nama servis tanpa
sebarang port diterbitkan.

## 7. Kemas

Buang bekas dan imej ujian. Docker kekal dipasang untuk bab ejen.

```bash
cd /srv/port-test
sudo docker compose down
cd /
sudo rm -r /srv/port-test
sudo docker image rm nginx:alpine hello-world
echo "containers left: $(sudo docker ps -aq | wc -l)"
```
