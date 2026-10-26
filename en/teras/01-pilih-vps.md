<!-- generated from kandungan/en/teras/01-pilih-vps.md by alat/bina.py: edit the template, not this file -->
# 1. Choose a VPS

**Short answer:** rent a small KVM virtual machine running Ubuntu 24.04 LTS, with at least
2 GB of RAM, 20 GB of disk and a public IPv4 address. Add your SSH public key
when you create it. Then log in once and run the checks below: they confirm the operating system, that the server is a
full virtual machine, and how much CPU, memory and disk you actually got.

Tested on: `ubuntu:24.04` (VM), 2026-10-25.

## What to look for

| Criterion | Why it matters for an AI agent |
|---|---|
| KVM (or another full virtualisation) | Docker and the firewall in chapter 3 need their own kernel. Container-based plans (OpenVZ, LXC) often cannot run them. |
| Ubuntu 24.04 LTS image | Every command in this guide is tested on this release. |
| 2 GB RAM or more | The agent, Docker and a reverse proxy run side by side. Less memory leads to processes being killed under load. |
| 20 GB disk or more | Docker images, logs and backups grow over time. |
| 1 vCPU or more | Agents mostly wait on the model provider, so CPU matters less than memory. |
| Public IPv4 address | Telegram webhooks, HTTPS certificates and SSH from most home networks expect IPv4. |
| SSH key at creation | You never need a root password, and chapter 2 turns password logins off entirely. |
| Web console in the provider panel | If a firewall or SSH change locks you out, the console still works. |
| Snapshots or backups | A snapshot before a risky change is the fastest way back. Chapter 6 adds backups you control. |
| Region close to you | Lower delay for SSH. The model provider's location matters more for agent speed. |

Prices change often, so this guide does not quote them. Compare the criteria above on each provider's own page. Some
providers that sell this kind of server, in alphabetical order:

| Provider | Website |
|---|---|
| Akamai (Linode) | https://www.linode.com |
| DigitalOcean | https://www.digitalocean.com |
| Hetzner | https://www.hetzner.com/cloud |
| OVHcloud | https://www.ovhcloud.com |
| Tencent Cloud (Lighthouse) | https://www.tencentcloud.com/products/lighthouse |
| Vultr | https://www.vultr.com |

None of these links pays this project anything. Any provider that meets the criteria works.

## 1. Log in for the first time

The provider shows your server's IP address after creation. This guide uses `203.0.113.10` as the example
address: replace it with your own in every command. The first login is as `root`, using the key you added. SSH asks
you to trust the server's key once and remembers it after that.

```bash
ssh -o StrictHostKeyChecking=accept-new root@203.0.113.10 'hostname; uptime'
```

Then open a session with `ssh root@203.0.113.10` and run the next three checks inside it.

## 2. Check the operating system

```bash
. /etc/os-release
echo "$PRETTY_NAME"
test "$ID" = ubuntu
```

## 3. Check that it is a full virtual machine

`systemd-detect-virt` names the virtualisation. `kvm`, `microsoft`, `vmware` or `xen` are full virtual machines. If it
prints a container type, the check stops with an error: ask the provider for a KVM plan before you go further.

```bash
virt="$(systemd-detect-virt)"
echo "virtualization: $virt"
case "$virt" in
  openvz|lxc|lxc-libvirt|systemd-nspawn|docker|podman|wsl)
    echo "This is a container, not a full virtual machine. Docker and the firewall chapter will not work here."
    exit 1 ;;
esac
```

## 4. Check the resources you got

Compare the output with the plan you paid for. A disk slightly smaller than advertised is normal, because the system
and file system use part of it.

```bash
echo "CPU cores: $(nproc)"
free -h --si | awk '/^Mem:/ {print "RAM: " $2}'
df -h --output=size,avail / | tail -n 1 | awk '{print "Disk: " $1 " total, " $2 " free"}'
```

Next: [2. A user account and SSH keys](02-pengguna-ssh.md).
