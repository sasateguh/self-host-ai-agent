# 1. Choose a VPS

**Short answer:** rent a small KVM virtual machine running Ubuntu {{config:ubuntu.versi}} LTS, with at least
{{config:vps.ram_gb}} GB of RAM, {{config:vps.cakera_gb}} GB of disk and a public IPv4 address. Add your SSH public key
when you create it. Then log in once and run the checks below: they confirm the operating system, that the server is a
full virtual machine, and how much CPU, memory and disk you actually got.

Tested on: {{diuji:teras/01-pilih-vps}}.

## What to look for

| Criterion | Why it matters for an AI agent |
|---|---|
| KVM (or another full virtualisation) | Docker and the firewall in chapter 3 need their own kernel. Container-based plans (OpenVZ, LXC) often cannot run them. |
| Ubuntu {{config:ubuntu.versi}} LTS image | Every command in this guide is tested on this release. |
| {{config:vps.ram_gb}} GB RAM or more | The agent, Docker and a reverse proxy run side by side. Less memory leads to processes being killed under load. |
| {{config:vps.cakera_gb}} GB disk or more | Docker images, logs and backups grow over time. |
| {{config:vps.cpu}} vCPU or more | Agents mostly wait on the model provider, so CPU matters less than memory. |
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

The provider shows your server's IP address after creation. This guide uses `{{config:contoh.ip_vps}}` as the example
address: replace it with your own in every command. The first login is as `root`, using the key you added. SSH asks
you to trust the server's key once and remembers it after that.

{{langkah:teras/01-pilih-vps/masuk-pertama}}

Then open a session with `ssh root@{{config:contoh.ip_vps}}` and run the next three checks inside it.

## 2. Check the operating system

{{langkah:teras/01-pilih-vps/semak-os}}

## 3. Check that it is a full virtual machine

`systemd-detect-virt` names the virtualisation. `kvm`, `microsoft`, `vmware` or `xen` are full virtual machines. If it
prints a container type, the check stops with an error: ask the provider for a KVM plan before you go further.

{{langkah:teras/01-pilih-vps/semak-virtualisasi}}

## 4. Check the resources you got

Compare the output with the plan you paid for. A disk slightly smaller than advertised is normal, because the system
and file system use part of it.

{{langkah:teras/01-pilih-vps/semak-sumber}}

Next: [2. A user account and SSH keys](02-pengguna-ssh.md).
