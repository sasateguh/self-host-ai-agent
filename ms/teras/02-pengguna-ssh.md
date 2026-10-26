<!-- generated from kandungan/ms/teras/02-pengguna-ssh.md by alat/bina.py: edit the template, not this file -->
# 2. Akaun pengguna dan kunci SSH

**Jawapan ringkas:** cipta pengguna biasa dengan hak `sudo`, beri kunci SSH anda kepadanya, dan sahkan anda boleh log
masuk sebagai pengguna itu. Kemudian tetapkan pelayan SSH supaya menerima kunci sahaja dan menolak `root`. Langkah
terakhir membuktikannya dari komputer anda sendiri: log masuk kata laluan ditolak, begitu juga `root`.

Diuji pada: `ubuntu:24.04` (VM), 2026-10-25.

Langkah bertanda "di komputer anda" dijalankan dalam terminal di komputer riba atau meja anda. Yang lain dijalankan di
pelayan, dalam sesi `ssh root@203.0.113.10` dari bab 1. Gantikan `203.0.113.10` dengan alamat
pelayan anda dan `ejen` dengan nama pengguna yang anda mahu.

## 1. Semak kunci anda (di komputer anda)

Ini mencetak cap jari kunci yang anda beri kepada penyedia. Jika fail itu tiada, cipta kunci dengan
`ssh-keygen -t ed25519` dan pilih frasa laluan, kemudian tambah fail `.pub` ke pelayan dalam panel penyedia.

```bash
ssh-keygen -lf ~/.ssh/id_ed25519.pub
```

## 2. Log masuk sebagai root (di komputer anda)

```bash
ssh -o StrictHostKeyChecking=accept-new root@203.0.113.10 whoami
```

## 3. Lihat apa yang pelayan terima sekarang (di komputer anda)

Ini bertanya kepada pelayan kaedah log masuk yang ditawarkannya, tanpa log masuk. Pelayan baharu selalunya menyenaraikan
`password` di sebelah `publickey`. Maksudnya sesiapa di internet boleh mencuba kata laluan terhadapnya.

```bash
out="$(ssh -o PubkeyAuthentication=no -o BatchMode=yes root@203.0.113.10 true 2>&1 || true)"
echo "$out" | tail -n 1
```

## 4. Cipta pengguna

Pengguna itu tiada kata laluan pada mulanya, menyertai kumpulan `sudo`, dan menerima salinan kunci yang dibenarkan untuk
root, jadi kunci yang sama boleh log masuk. Kata laluan rawak untuk `sudo` ditulis ke fail yang hanya root boleh baca.

```bash
adduser --disabled-password --comment "" ejen
usermod -aG sudo ejen
umask 077
openssl rand -base64 24 > /root/ejen-sudo-password.txt
echo "ejen:$(cat /root/ejen-sudo-password.txt)" | chpasswd
install -d -m 700 -o ejen -g ejen /home/ejen/.ssh
install -m 600 -o ejen -g ejen /root/.ssh/authorized_keys /home/ejen/.ssh/authorized_keys
id ejen
```

Baca kata laluan itu dengan `cat /root/ejen-sudo-password.txt` dan simpan dalam pengurus kata
laluan anda. Anda menaipnya bila `sudo` meminta. Langkah 9 memadam fail itu.

## 5. Log masuk sebagai pengguna baharu (di komputer anda)

Biarkan sesi root terbuka sehingga langkah 8 lulus. Jika ada yang tidak kena, anda masih boleh membaikinya dari situ
(atau dari konsol web penyedia).

```bash
ssh ejen@203.0.113.10 'whoami; id -nG'
```

## 6. Benarkan kunci sahaja, tolak root

Tetapan diletak dalam fail sendiri, bukan dengan menyunting `/etc/ssh/sshd_config`. Ubuntu membaca setiap fail dalam
`/etc/ssh/sshd_config.d/`, dan penyedia selalunya meletak fail di situ yang menghidupkan semula kata laluan. `sshd -t`
menyemak sintaks sebelum muat semula, jadi salah taip tidak boleh menghentikan SSH. Baris terakhir gagal kecuali
ketiga-tiga tetapan berkuat kuasa.

```bash
cat > /etc/ssh/sshd_config.d/00-hardening.conf <<'EOF'
# Keys only, no root login. sshd keeps the FIRST value it reads for each setting
# and reads this folder in name order, so the 00- prefix wins over provider files.
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF
sshd -t
systemctl reload ssh
sshd -T | grep -E '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication) '
test "$(sshd -T | grep -cE '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication) no$')" = 3
```

## 7. Buktikan kata laluan ditolak (di komputer anda)

Pelayan kini mesti menyenaraikan `publickey` sahaja.

```bash
out="$(ssh -o PubkeyAuthentication=no -o BatchMode=yes ejen@203.0.113.10 true 2>&1 || true)"
echo "$out" | tail -n 1
echo "$out" | grep 'Permission denied (publickey)' >/dev/null
```

## 8. Buktikan root ditolak (di komputer anda)

```bash
if ssh -o BatchMode=yes root@203.0.113.10 true; then
  echo "root can still log in"
  exit 1
fi
echo "root login refused"
```

```bash
ssh ejen@203.0.113.10 'whoami; sudo -n true 2>/dev/null || echo "sudo asks for a password"'
```

Mulai sekarang, log masuk dengan `ssh ejen@203.0.113.10` dan letak `sudo` di hadapan
arahan yang mengubah sistem. Anda boleh menutup sesi root.

## 9. Padam fail kata laluan

```bash
sudo shred -u /root/ejen-sudo-password.txt
sudo ls /root
```

Seterusnya: [3. Firewall dan kemas kini automatik](03-firewall-kemas-kini.md).
