#!/usr/bin/env bash
# Bab teras 2: pengguna biasa dengan sudo, log masuk kunci SSH sahaja, root dan kata laluan ditolak (diukur dari luar).
# Jalankan: python3 alat/uji.py teras/02-pengguna-ssh
# @perlu vm

# @langkah kunci-anda luar
ssh-keygen -lf ~/.ssh/id_ed25519.pub

# @langkah masuk-root luar
ssh -o StrictHostKeyChecking=accept-new root@203.0.113.10 whoami

# @langkah sebelum luar
out="$(ssh -o PubkeyAuthentication=no -o BatchMode=yes root@203.0.113.10 true 2>&1 || true)"
echo "$out" | tail -n 1

# @langkah cipta-pengguna
adduser --disabled-password --comment "" ejen
usermod -aG sudo ejen
umask 077
openssl rand -base64 24 > /root/ejen-sudo-password.txt
echo "ejen:$(cat /root/ejen-sudo-password.txt)" | chpasswd
install -d -m 700 -o ejen -g ejen /home/ejen/.ssh
install -m 600 -o ejen -g ejen /root/.ssh/authorized_keys /home/ejen/.ssh/authorized_keys
id ejen

# @langkah masuk-pengguna luar
ssh ejen@203.0.113.10 'whoami; id -nG'

# @langkah kunci-ssh
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

# @langkah kata-laluan-ditolak luar
out="$(ssh -o PubkeyAuthentication=no -o BatchMode=yes ejen@203.0.113.10 true 2>&1 || true)"
echo "$out" | tail -n 1
echo "$out" | grep 'Permission denied (publickey)' >/dev/null

# @langkah root-ditolak luar
if ssh -o BatchMode=yes root@203.0.113.10 true; then
  echo "root can still log in"
  exit 1
fi
echo "root login refused"

# @langkah masuk-semula luar
ssh ejen@203.0.113.10 'whoami; sudo -n true 2>/dev/null || echo "sudo asks for a password"'

# @langkah buang-fail-kata-laluan
sudo shred -u /root/ejen-sudo-password.txt
sudo ls /root
