<!-- generated from kandungan/ms/teras/01-pilih-vps.md by alat/bina.py: edit the template, not this file -->
# 1. Pilih VPS

**Jawapan ringkas:** sewa mesin maya KVM kecil yang menjalankan Ubuntu 24.04 LTS, dengan sekurang-kurangnya
2 GB RAM, 20 GB cakera dan alamat IPv4 awam. Masukkan kunci awam SSH anda semasa
menciptanya. Kemudian log masuk sekali dan jalankan semakan di bawah: ia mengesahkan sistem pengendalian, bahawa pelayan
itu mesin maya penuh, dan berapa banyak CPU, memori dan cakera yang anda benar-benar dapat.

Diuji pada: `ubuntu:24.04` (VM), 2026-10-25.

## Apa yang perlu dicari

| Kriteria | Kenapa penting untuk ejen AI |
|---|---|
| KVM (atau virtualisasi penuh lain) | Docker dan firewall dalam bab 3 memerlukan kernel sendiri. Pelan berasaskan bekas (OpenVZ, LXC) selalunya tidak boleh menjalankannya. |
| Imej Ubuntu 24.04 LTS | Setiap arahan dalam panduan ini diuji atas keluaran ini. |
| RAM 2 GB atau lebih | Ejen, Docker dan proksi terbalik berjalan serentak. Memori yang kurang menyebabkan proses dibunuh bila beban tinggi. |
| Cakera 20 GB atau lebih | Imej Docker, log dan backup bertambah dari semasa ke semasa. |
| 1 vCPU atau lebih | Ejen kebanyakan masa menunggu penyedia model, jadi CPU kurang penting berbanding memori. |
| Alamat IPv4 awam | Webhook Telegram, sijil HTTPS dan SSH dari kebanyakan rangkaian rumah menjangka IPv4. |
| Kunci SSH semasa dicipta | Anda tidak pernah perlukan kata laluan root, dan bab 2 mematikan log masuk kata laluan sepenuhnya. |
| Konsol web dalam panel penyedia | Jika perubahan firewall atau SSH mengunci anda di luar, konsol masih berfungsi. |
| Snapshot atau backup | Snapshot sebelum perubahan berisiko ialah jalan pulang paling cepat. Bab 6 menambah backup yang anda kawal sendiri. |
| Rantau dekat dengan anda | Kelewatan SSH lebih rendah. Lokasi penyedia model lebih mempengaruhi kelajuan ejen. |

Harga kerap berubah, jadi panduan ini tidak memetiknya. Bandingkan kriteria di atas di halaman setiap penyedia sendiri.
Beberapa penyedia yang menjual pelayan jenis ini, ikut abjad:

| Penyedia | Laman web |
|---|---|
| Akamai (Linode) | https://www.linode.com |
| DigitalOcean | https://www.digitalocean.com |
| Hetzner | https://www.hetzner.com/cloud |
| OVHcloud | https://www.ovhcloud.com |
| Vultr | https://www.vultr.com |

Tiada pautan ini membayar apa-apa kepada projek ini. Mana-mana penyedia yang memenuhi kriteria boleh dipakai.

## 1. Log masuk kali pertama

Penyedia memaparkan alamat IP pelayan anda selepas ia dicipta. Panduan ini memakai `203.0.113.10` sebagai
alamat contoh: gantikan dengan alamat anda dalam setiap arahan. Log masuk pertama ialah sebagai `root`, dengan kunci yang
anda masukkan. SSH meminta anda mempercayai kunci pelayan sekali, dan mengingatinya selepas itu.

```bash
ssh -o StrictHostKeyChecking=accept-new root@203.0.113.10 'hostname; uptime'
```

Kemudian buka sesi dengan `ssh root@203.0.113.10` dan jalankan tiga semakan seterusnya di dalamnya.

## 2. Semak sistem pengendalian

```bash
. /etc/os-release
echo "$PRETTY_NAME"
test "$ID" = ubuntu
```

## 3. Semak bahawa ia mesin maya penuh

`systemd-detect-virt` menamakan jenis virtualisasi. `kvm`, `microsoft`, `vmware` atau `xen` ialah mesin maya penuh. Jika
ia mencetak jenis bekas, semakan berhenti dengan ralat: minta pelan KVM daripada penyedia sebelum meneruskan.

```bash
virt="$(systemd-detect-virt)"
echo "virtualization: $virt"
case "$virt" in
  openvz|lxc|lxc-libvirt|systemd-nspawn|docker|podman|wsl)
    echo "This is a container, not a full virtual machine. Docker and the firewall chapter will not work here."
    exit 1 ;;
esac
```

## 4. Semak sumber yang anda dapat

Bandingkan output dengan pelan yang anda bayar. Cakera yang sedikit lebih kecil daripada yang diiklankan adalah biasa,
kerana sistem dan sistem fail memakai sebahagiannya.

```bash
echo "CPU cores: $(nproc)"
free -h --si | awk '/^Mem:/ {print "RAM: " $2}'
df -h --output=size,avail / | tail -n 1 | awk '{print "Disk: " $1 " total, " $2 " free"}'
```

Seterusnya: [2. Akaun pengguna dan kunci SSH](02-pengguna-ssh.md).
