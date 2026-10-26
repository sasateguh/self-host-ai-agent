#!/usr/bin/env bash
# Bab contoh tahap B: membuktikan aliran VM (Ubuntu cloud image + KVM, systemd sebenar, ukuran port dari luar VM).
# Bukan bab panduan. Jalankan: python3 alat/uji.py teras/00-contoh-vm
# @perlu vm palsu

# @langkah semak-vm
. /etc/os-release
echo "$PRETTY_NAME on $(systemd-detect-virt), PID 1 = $(ps -p 1 -o comm=)"
test "$ID" = ubuntu
test "$(systemd-detect-virt)" = kvm
test "$(ps -p 1 -o comm=)" = systemd

# @langkah servis-systemd
mkdir -p /srv/contoh
echo "hello from the VM" > /srv/contoh/index.html
cat > /etc/systemd/system/contoh-web.service <<'EOF'
[Unit]
Description=Example web server for the test runner
After=network-online.target

[Service]
ExecStart=/usr/bin/python3 -m http.server 8080 --directory /srv/contoh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now contoh-web.service
for _ in $(seq 20); do curl -fsS http://127.0.0.1:8080/ && break; sleep 1; done
systemctl is-active contoh-web.service

# @langkah model-palsu
curl -fsS "$OPENAI_BASE_URL/chat/completions" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "palsu-model", "messages": [{"role": "user", "content": "hello from vm"}]}' \
  | grep -o '"content": "[^"]*"'

# @langkah port-terbuka luar
nc -z -w 5 "$VM_IP" 8080 && echo "port 8080 open from outside"
curl -fsS "http://$VM_IP:8080/"

# @langkah port-tertutup luar
if nc -z -w 5 "$VM_IP" 9; then echo "port 9 should be closed"; exit 1; fi
echo "port 9 closed from outside"
