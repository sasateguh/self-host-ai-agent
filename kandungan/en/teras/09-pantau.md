# 9. Monitoring and updates

**Short answer:** a small script checks the disk, memory, failed services, broken containers and pending reboots every
15 minutes, and sends you a Telegram message when that list changes, including "all clear" once a problem is gone.
Containers are updated by changing a pinned version tag, pulling and recreating; going back is the same steps with the
old tag. The steps below break a service on purpose to see the alert, then update and roll back a container.

Tested on: {{diuji:teras/09-pantau}}.

Run these steps as the user from chapter 2, on a server that has gone through chapter 3 (automatic security updates),
chapter 4 (Docker) and chapter 7 (Telegram bot). The test run sent its messages to a stand-in for the Telegram API.

## 1. The check script

The two limits at the top of the script are percentages; change them to suit your server. `check-server print` only
prints the current list and sends nothing.

{{langkah:teras/09-pantau/skrip}}

The script remembers the last list it sent in `/var/lib/check-server/last`, so a problem that lasts all night gives you
one message, not one every 15 minutes.

## 2. Run it every 15 minutes

{{langkah:teras/09-pantau/jadual}}

## 3. Try an alert

This starts a throwaway service that fails on purpose, then runs the check. A Telegram message lists
`check-demo.service` as failed, and the saved list shows the same.

{{langkah:teras/09-pantau/cuba-amaran}}

## 4. Clear it

Telling systemd to forget the failed service makes the problem go away. The next check sends "all clear".

{{langkah:teras/09-pantau/padam-amaran}}

When a real alert arrives, look at the service with `systemctl status <name>` and `journalctl -u <name> -n 50`.
For a container, use `sudo docker logs --tail 50 <name>`. For "a reboot is needed", run `sudo reboot` at a quiet time.

## 5. Pin container versions

Security updates for Ubuntu install themselves (chapter 3). Containers do not: they only change when you change them.
Write an exact version tag in `compose.yaml` (never `latest`), so you always know what is running and can go back. This
example runs an older Alpine release:

{{langkah:teras/09-pantau/versi-dipin}}

## 6. Update

Read the project's release notes first, then change the tag, pull the new image and recreate the container. The check
afterwards confirms nothing broke.

{{langkah:teras/09-pantau/kemas-kini}}

Take a backup (chapter 6) before updating anything that holds data.

## 7. Roll back

If the new version misbehaves, put the old tag back and recreate. The image is still on the server, so this works
without the internet.

{{langkah:teras/09-pantau/undur}}

## 8. Clean up

Remove the example project and its images. The check script and its timer stay.

{{langkah:teras/09-pantau/kemas}}
