# 2. A user account and SSH keys

**Short answer:** create an ordinary user with `sudo` rights, give it your SSH key, and confirm you can log in as that
user. Then tell the SSH server to accept keys only and to refuse `root`. The last steps prove it from your own
computer: a password login is refused, and so is `root`.

Tested on: {{diuji:teras/02-pengguna-ssh}}.

Steps marked "on your computer" run in a terminal on your laptop or desktop. The others run on the server, inside the
`ssh root@{{config:contoh.ip_vps}}` session from chapter 1. Replace `{{config:contoh.ip_vps}}` with your server's
address and `{{config:contoh.pengguna}}` with the user name you want.

## 1. Check your key (on your computer)

This prints the fingerprint of the key you gave the provider. If the file does not exist, create a key with
`ssh-keygen -t ed25519` and choose a passphrase, then add the `.pub` file to the server in the provider's panel.

{{langkah:teras/02-pengguna-ssh/kunci-anda}}

## 2. Log in as root (on your computer)

{{langkah:teras/02-pengguna-ssh/masuk-root}}

## 3. See what the server accepts now (on your computer)

This asks the server which login methods it offers, without logging in. A new server often lists `password` next to
`publickey`. That means anyone on the internet can try passwords against it.

{{langkah:teras/02-pengguna-ssh/sebelum}}

## 4. Create the user

The user gets no password at first, joins the `sudo` group, and receives a copy of root's authorised keys, so the same
key logs in. A random password for `sudo` is written to a file that only root can read.

{{langkah:teras/02-pengguna-ssh/cipta-pengguna}}

Read that password with `cat /root/{{config:contoh.pengguna}}-sudo-password.txt` and store it in your password
manager. You type it when `sudo` asks. Step 9 deletes the file.

## 5. Log in as the new user (on your computer)

Keep the root session open until step 8 passes. If something goes wrong, you can still fix it from there (or from the
provider's web console).

{{langkah:teras/02-pengguna-ssh/masuk-pengguna}}

## 6. Allow keys only, refuse root

The settings go into their own file instead of editing `/etc/ssh/sshd_config`. Ubuntu reads every file in
`/etc/ssh/sshd_config.d/`, and providers often drop a file there that turns passwords back on. `sshd -t` checks the
syntax before the reload, so a typo cannot stop SSH. The last line fails unless all three settings are in effect.

{{langkah:teras/02-pengguna-ssh/kunci-ssh}}

## 7. Prove passwords are refused (on your computer)

The server must now list only `publickey`.

{{langkah:teras/02-pengguna-ssh/kata-laluan-ditolak}}

## 8. Prove root is refused (on your computer)

{{langkah:teras/02-pengguna-ssh/root-ditolak}}

{{langkah:teras/02-pengguna-ssh/masuk-semula}}

From now on, log in with `ssh {{config:contoh.pengguna}}@{{config:contoh.ip_vps}}` and put `sudo` in front of commands
that change the system. You can close the root session.

## 9. Delete the password file

{{langkah:teras/02-pengguna-ssh/buang-fail-kata-laluan}}

Next: [3. Firewall and automatic updates](03-firewall-kemas-kini.md).
