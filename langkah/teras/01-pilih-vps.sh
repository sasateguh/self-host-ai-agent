#!/usr/bin/env bash
# Bab teras 1: pilih VPS, kemudian semak pelayan yang anda dapat (OS, jenis virtualisasi, sumber).
# Jalankan: python3 alat/uji.py teras/01-pilih-vps
# @perlu vm

# @langkah masuk-pertama luar
ssh -o StrictHostKeyChecking=accept-new root@203.0.113.10 'hostname; uptime'

# @langkah semak-os
. /etc/os-release
echo "$PRETTY_NAME"
test "$ID" = ubuntu

# @langkah semak-virtualisasi
virt="$(systemd-detect-virt)"
echo "virtualization: $virt"
case "$virt" in
  openvz|lxc|lxc-libvirt|systemd-nspawn|docker|podman|wsl)
    echo "This is a container, not a full virtual machine. Docker and the firewall chapter will not work here."
    exit 1 ;;
esac

# @langkah semak-sumber
echo "CPU cores: $(nproc)"
free -h --si | awk '/^Mem:/ {print "RAM: " $2}'
df -h --output=size,avail / | tail -n 1 | awk '{print "Disk: " $1 " total, " $2 " free"}'
