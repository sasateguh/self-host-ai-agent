#!/usr/bin/env bash
# CA UJIAN untuk bab HTTPS (dijalankan oleh uji/vm/mula-vm.sh dalam bekas pelancar, BUKAN atas mesin anda).
# Bekas pelancar = "internet" bagi VM: di sini nama contoh (config [contoh]) menghala ke VM, dan pengeluar ACME lalai
# (Let's Encrypt, config [ca] hos_acme) dijawab oleh Pebble, CA ujian rasmi Let's Encrypt. VM hanya diberi dua perkara:
# nama hos ACME menghala ke bekas ini, dan CA tempatan yang menandatangani sijil TLS pelayan ACME itu. Arahan bab
# (cth Caddy dengan konfigurasi lalai) dijalankan tanpa diubah; Pebble mengesahkan cabaran dengan menyambung ke VM dari
# luar, seperti CA sebenar. Pebble melayan direktori di /dir, jadi nginx di hadapan memetakan /directory (laluan LE).
set -euo pipefail
: "${CA_URL:?}" "${CA_SHA256:?}" "${CA_HOS_ACME:?}" "${CA_NAMA_VM:?}" "${VM_IP:?}" "${VM_IP_PELANCAR:?}" "${VM_PENGGUNA:?}"
install -d -m 700 /vm/ca
cd /vm/ca
apt-get install -y -qq --no-install-recommends nginx openssl >/dev/null

curl -fsSL --retry 5 --retry-all-errors -o pebble.tar.gz "$CA_URL"
echo "$CA_SHA256  pebble.tar.gz" | sha256sum -c - >/dev/null
tar -xzf pebble.tar.gz
pebble="$(find /vm/ca -type f -name pebble | head -n 1)"
chmod 755 "$pebble"   # arkib keluaran menyimpan binari tanpa bit laksana
echo "ca: pebble ${CA_URL##*/download/} sha256 $CA_SHA256"

# CA tempatan sekali guna + sijil TLS untuk nama hos ACME (pelayan direktori, BUKAN sijil yang dikeluarkan kepada VM).
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -days 2 -subj "/CN=uji ACME CA" \
  -keyout ca.key -out ca.pem 2>/dev/null
san="$(for h in $CA_HOS_ACME; do printf 'DNS:%s,' "$h"; done)"
openssl req -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -subj "/CN=${CA_HOS_ACME%% *}" \
  -keyout acme.key -out acme.csr 2>/dev/null
openssl x509 -req -in acme.csr -CA ca.pem -CAkey ca.key -CAcreateserial -days 2 \
  -extfile <(printf 'subjectAltName=%s\n' "${san%,}") -out acme.pem 2>/dev/null

cat > pebble.json <<JSON
{"pebble": {"listenAddress": "127.0.0.1:14000", "managementListenAddress": "127.0.0.1:15000",
  "certificate": "/vm/ca/acme.pem", "privateKey": "/vm/ca/acme.key",
  "httpPort": 80, "tlsPort": 443, "ocspResponderURL": "", "externalAccountBindingRequired": false}}
JSON
# Tanpa kelewatan rawak dan tanpa penolakan nonce rawak (lalai Pebble untuk menguji klien), supaya larian stabil.
PEBBLE_VA_NOSLEEP=1 PEBBLE_WFE_NONCEREJECT=0 nohup "$pebble" -config pebble.json >pebble.log 2>&1 &
for _ in $(seq 30); do curl -fsSk -o /dev/null https://127.0.0.1:14000/dir && break; sleep 1; done
curl -fsSk -o /dev/null https://127.0.0.1:14000/dir

rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/conf.d/acme.conf <<NGINX
server {
  listen $VM_IP_PELANCAR:443 ssl;
  server_name $CA_HOS_ACME;
  ssl_certificate /vm/ca/acme.pem;
  ssl_certificate_key /vm/ca/acme.key;
  proxy_set_header Host \$host;
  proxy_ssl_verify off;
  location = /directory { proxy_pass https://127.0.0.1:14000/dir; }
  location / { proxy_pass https://127.0.0.1:14000; }
}
NGINX
nginx -t 2>/dev/null
nginx

# "Internet" bagi komputer pembaca (bekas ini): nama contoh -> VM, dan akar sijil yang Pebble keluarkan dipercayai.
echo "$VM_IP $CA_NAMA_VM" >> /etc/hosts
curl -fsSk https://127.0.0.1:15000/roots/0 > /usr/local/share/ca-certificates/pebble-akar.crt
update-ca-certificates >/dev/null 2>&1

ssh_vm() { ssh -i /vm/kunci -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
  -o ConnectTimeout=5 -o BatchMode=yes "$VM_PENGGUNA@$VM_IP" "$@"; }
ssh_vm "echo '$VM_IP_PELANCAR $CA_HOS_ACME' | sudo tee -a /etc/hosts >/dev/null"
ssh_vm 'sudo tee /usr/local/share/ca-certificates/uji-acme.crt >/dev/null && sudo update-ca-certificates >/dev/null 2>&1' < ca.pem
ssh_vm "curl -fsS https://${CA_HOS_ACME%% *}/directory" | grep newNonce >/dev/null
echo "ca: sedia (nama contoh -> VM; ${CA_HOS_ACME%% *} -> Pebble, disemak dari VM)"
