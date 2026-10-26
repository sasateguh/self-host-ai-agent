<!-- generated from kandungan/en/teras/02-pengguna-ssh.md by alat/bina.py: edit the template, not this file -->
# 2. A user account and SSH keys

**Short answer:** create an ordinary user with `sudo` rights, give it your SSH key, and confirm you can log in as that
user. Then tell the SSH server to accept keys only and to refuse `root`. The last steps prove it from your own
computer: a password login is refused, and so is `root`.

Tested on: `ubuntu:24.04` (VM), 2026-10-25.

Steps marked "on your computer" run in a terminal on your laptop or desktop. The others run on the server, inside the
`ssh root@203.0.113.10` session from chapter 1. Replace `203.0.113.10` with your server's
address and `ejen` with the user name you want.

## 1. Check your key (on your computer)

This prints the fingerprint of the key you gave the provider. If the file does not exist, create a key with
`ssh-keygen -t ed25519` and choose a passphrase, then add the `.pub` file to the server in the provider's panel.

```bash
ssh-keygen -lf ~/.ssh/id_ed25519.pub
```

## 2. Log in as root (on your computer)

```bash
ssh -o StrictHostKeyChecking=accept-new root@203.0.113.10 whoami
```

## 3. See what the server accepts now (on your computer)

This asks the server which login methods it offers, without logging in. A new server often lists `password` next to
`publickey`. That means anyone on the internet can try passwords against it.

```bash
out="$(ssh -o PubkeyAuthentication=no -o BatchMode=yes root@203.0.113.10 true 2>&1 || true)"
echo "$out" | tail -n 1
```

## 4. Create the user

The user gets no password at first, joins the `sudo` group, and receives a copy of root's authorised keys, so the same
key logs in. A random password for `sudo` is written to a file that only root can read.

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

Read that password with `cat /root/ejen-sudo-password.txt` and store it in your password
manager. You type it when `sudo` asks. Step 9 deletes the file.

## 5. Log in as the new user (on your computer)

Keep the root session open until step 8 passes. If something goes wrong, you can still fix it from there (or from the
provider's web console).

```bash
ssh ejen@203.0.113.10 'whoami; id -nG'
```

## 6. Allow keys only, refuse root

The settings go into their own file instead of editing `/etc/ssh/sshd_config`. Ubuntu reads every file in
`/etc/ssh/sshd_config.d/`, and providers often drop a file there that turns passwords back on. `sshd -t` checks the
syntax before the reload, so a typo cannot stop SSH. The last line fails unless all three settings are in effect.

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

## 7. Prove passwords are refused (on your computer)

The server must now list only `publickey`.

```bash
out="$(ssh -o PubkeyAuthentication=no -o BatchMode=yes ejen@203.0.113.10 true 2>&1 || true)"
echo "$out" | tail -n 1
echo "$out" | grep 'Permission denied (publickey)' >/dev/null
```

## 8. Prove root is refused (on your computer)

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

From now on, log in with `ssh ejen@203.0.113.10` and put `sudo` in front of commands
that change the system. You can close the root session.

## 9. Delete the password file

```bash
sudo shred -u /root/ejen-sudo-password.txt
sudo ls /root
```

Next: [3. Firewall and automatic updates](03-firewall-kemas-kini.md).
