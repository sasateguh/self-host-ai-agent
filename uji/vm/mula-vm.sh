#!/usr/bin/env bash
# Bekas PELANCAR tahap B (dijalankan oleh alat/uji.py dalam bekas Ubuntu baharu, BUKAN atas mesin anda):
# muat turun cloud image Ubuntu + semak sha256, cipta cakera salinan-atas-tulis, cloud-init (pengguna ujian + kunci SSH
# sekali guna), lancar VM dengan KVM, tunggu cloud-init selesai, cetak "vm: sedia" dan tidur.
# Semua fail dalam /vm (tmpfs bekas): hilang bersama bekas. Nilai datang dari config/panduan.toml [vm] melalui env VM_*.
# Rangkaian VM: NIC 1 = qemu user-mode (keluar ke internet + pelayan palsu), NIC 2 = tap0 antara bekas ini dan VM
# (laluan "dari luar": SSH alat ujian dan langkah "luar" mengukur port VM sebenar, tanpa proksi qemu di tengah).
set -euo pipefail
: "${VM_URL_IMEJ:?}" "${VM_URL_SHA:?}" "${VM_IP:?}" "${VM_IP_PELANCAR:?}" "${VM_PENGGUNA:?}" "${VM_NAMA_HOS:?}"
: "${VM_MEMORI_MB:?}" "${VM_CPU:?}" "${VM_CAKERA:?}" "${VM_MASA_SEDIA_S:?}"
cd /vm

apt-get update -qq
apt-get install -y -qq --no-install-recommends qemu-system-x86 qemu-utils genisoimage openssh-client \
  curl ca-certificates iproute2 netcat-openbsd iputils-ping rsync >/dev/null
echo "vm: pakej pelancar dipasang"

fail="${VM_URL_IMEJ##*/}"
curl -fsSL -o "$fail" "$VM_URL_IMEJ"
curl -fsSL "$VM_URL_SHA" | grep " \*\?$fail\$" | sed 's/ \*\?/  /' > sha.txt
test -s sha.txt
sha256sum -c sha.txt >/dev/null
echo "vm: imej $fail sha256 $(cut -d' ' -f1 sha.txt)"

qemu-img create -q -f qcow2 -F qcow2 -b "/vm/$fail" cakera.qcow2 "$VM_CAKERA"
ssh-keygen -q -t ed25519 -N '' -C uji -f kunci
# Komputer PEMBACA = bekas ini: kunci lalai root, jadi arahan "dari komputer anda" (langkah luar) berjalan seperti
# ditulis. Kunci ini juga dipasang untuk root dalam VM, seperti penyedia VPS memasang kunci yang anda beri.
install -d -m 700 /root/.ssh
ssh-keygen -q -t ed25519 -N '' -C pembaca -f /root/.ssh/id_ed25519

cat > meta-data <<EOF
instance-id: uji
local-hostname: $VM_NAMA_HOS
EOF
cat > user-data <<EOF
#cloud-config
hostname: $VM_NAMA_HOS
# Lalai VPS baharu yang biasa: root boleh masuk dengan kunci, dan pelayan masih menawarkan log masuk kata laluan.
# Bab SSH panduan mesti menutup kedua-duanya; tanpa ini cloud image sudah tertutup dan ujian bab itu lulus tanpa makna.
disable_root: false
ssh_pwauth: true
users:
  - name: $VM_PENGGUNA
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: true
    ssh_authorized_keys:
      - $(cat kunci.pub)
EOF
cat > network-config <<EOF
version: 2
ethernets:
  nat:
    match: {macaddress: "52:54:00:00:00:01"}
    dhcp4: true
  luar:
    match: {macaddress: "52:54:00:00:00:02"}
    addresses: [$VM_IP/24]
EOF
genisoimage -quiet -output seed.iso -volid cidata -joliet -rock user-data meta-data network-config

ip tuntap add tap0 mode tap
ip addr add "$VM_IP_PELANCAR/24" dev tap0
ip link set tap0 up

qemu-system-x86_64 -enable-kvm -cpu host -m "$VM_MEMORI_MB" -smp "$VM_CPU" \
  -drive if=virtio,file=cakera.qcow2,format=qcow2 \
  -drive if=virtio,file=seed.iso,format=raw,readonly=on \
  -netdev user,id=nat -device virtio-net-pci,netdev=nat,mac=52:54:00:00:00:01 \
  -netdev tap,id=luar,ifname=tap0,script=no,downscript=no -device virtio-net-pci,netdev=luar,mac=52:54:00:00:00:02 \
  -display none -serial file:/vm/konsol.log -daemonize -pidfile /vm/qemu.pid
echo "vm: qemu dimulakan (KVM, ${VM_MEMORI_MB} MB, ${VM_CPU} CPU)"

ssh_vm() { ssh -i /vm/kunci -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
  -o ConnectTimeout=5 -o BatchMode=yes "$VM_PENGGUNA@$VM_IP" "$@"; }
hujung=$((SECONDS + VM_MASA_SEDIA_S))
until ssh_vm true 2>/dev/null; do
  kill -0 "$(cat /vm/qemu.pid)" || { echo "vm: qemu berhenti"; tail -n 20 /vm/konsol.log; exit 1; }
  [ "$SECONDS" -lt "$hujung" ] || { echo "vm: SSH tidak sedia dalam ${VM_MASA_SEDIA_S} s"; tail -n 20 /vm/konsol.log; exit 1; }
  sleep 3
done
ssh_vm sudo cloud-init status --wait >/dev/null || { echo "vm: cloud-init gagal"; ssh_vm sudo cloud-init status --long; exit 1; }
pub_pembaca="$(cat /root/.ssh/id_ed25519.pub)"
ssh_vm "sudo install -d -m 700 /root/.ssh && echo '$pub_pembaca' | sudo tee /root/.ssh/authorized_keys >/dev/null"
echo "vm: kunci pembaca dipasang untuk root (seperti penyedia VPS)"
# Pelayan palsu (bab "@perlu palsu") ada dalam rangkaian docker bekas ini; DNS qemu user-mode tidak nampak nama itu,
# jadi alamatnya ditulis dalam /etc/hosts VM. Trafik tetap melalui qemu user-mode seperti trafik keluar biasa.
if [ -n "${VM_PALSU_HOS:-}" ]; then
  ip_palsu="$(getent hosts "$VM_PALSU_HOS" | awk '{print $1; exit}')"
  test -n "$ip_palsu"
  ssh_vm "echo '$ip_palsu $VM_PALSU_HOS' | sudo tee -a /etc/hosts >/dev/null"
  echo "vm: pelayan palsu '$VM_PALSU_HOS' boleh dicapai dari VM"
fi
# Bab "@perlu ca": DNS + Let's Encrypt ditiru dalam rangkaian ujian (uji/vm/ca-palsu.sh, nilai dari config [ca]).
if [ -n "${CA_URL:-}" ]; then
  bash /uji-vm/ca-palsu.sh
fi
echo "vm: sedia ($(ssh_vm '. /etc/os-release; echo $PRETTY_NAME'), ${SECONDS} s)"
exec sleep infinity
