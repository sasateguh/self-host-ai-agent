# OpenClaw on your server

**Short answer:** run the official OpenClaw Docker image, pinned to one tested version, with Docker Compose. OpenClaw
reads your model API key, your Telegram bot token and its own gateway token from files (chapters 7 and 8), talks to an
OpenAI-compatible model provider, and answers only your own Telegram account. Back it up with its own backup command
plus restic, and update by changing one line.

Tested on: {{diuji:ejen/openclaw}}, with OpenClaw {{ejen:openclaw.ejen.versi}} (released
{{ejen:openclaw.ejen.tarikh_keluaran}}).

OpenClaw is an open source personal AI assistant ({{ejen:openclaw.ejen.lesen}} licence, source at
{{ejen:openclaw.ejen.repo}}, documentation at {{ejen:openclaw.ejen.dokumen}}). A long-running process called the
gateway connects it to chat apps such as Telegram and to your model provider. This chapter follows the project's own
Docker, Telegram, provider, secrets and backup documentation for the version above.

Run these steps as the user from chapter 2, on a server that has been through chapters 3 (firewall), 4 (Docker),
6 (backup), 7 (Telegram bot) and 8 (model API key). The test run used a stand-in model provider and a stand-in Telegram
API, made-up keys, and a test message in place of one typed on a phone.

Plan for a server with at least 4 GB of memory. In the test the OpenClaw container used about 2 GB after its first
answer, and on a test machine with 2 GB in total every command took minutes.

## 1. Download the previous release first

The image name ends with a tag and a digest (`sha256:...`). The tag is the version name; the digest is a fingerprint of
the exact image that was tested, so Docker refuses anything else, even if someone moves the tag later. The images come
from the GitHub Container Registry, which the project uses for its releases. Each is about 700 MB to download.

This chapter starts on the release before the tested one, {{ejen:openclaw.imej_undur.tag}}, so that step 11 is a real
update to {{ejen:openclaw.imej.tag}} and a real rollback. You finish on {{ejen:openclaw.imej.tag}}. If you would rather
start on the tested version, use its tag and digest from step 11 in steps 1 and 4.

{{langkah:ejen/openclaw/tarik}}

## 2. Write the settings file

OpenClaw keeps its settings, conversations and memory in one state folder, here `/srv/openclaw/data`. The container runs
as a user with ID 1000, so the folder belongs to that ID. A second folder, `/srv/openclaw/backups`, will hold backup
archives (step 9).

The first lines create a gateway token: a random password that protects the gateway's control interface, kept next to
the key from chapter 8 and readable by root only.

The settings file then says:

- `gateway`: listen on `127.0.0.1` only, and require the gateway token.
- `secrets.providers`: two files that hold a single value each, the model key and the gateway token. The settings file
  points at them and never contains the values.
- `models`: an OpenAI-compatible provider at `OPENAI_BASE_URL` (the same address as chapter 8; set it first if your
  provider gave you one), with the key from the file.
- `channels.telegram`: read the bot token from a file, and with `dmPolicy: "allowlist"` answer only the chat ID saved in
  chapter 7. Anyone else who finds the bot gets nothing.

OpenClaw refuses to connect to addresses inside a private network by default, as a guard against requests being
redirected to your own machines. The two `if` checks only relax that when you use one: a model address that starts with
`http://` (for example a model server on your own network) or a Telegram address that is not Telegram's own (a local
Bot API server). With a normal provider and Telegram they add nothing.

{{langkah:ejen/openclaw/config}}

## 3. Choose the model

This lists the models your key can use, then waits for you to type one of the names and press Enter.

{{langkah:ejen/openclaw/model}}

## 4. Start OpenClaw with Docker Compose

The Compose file gives the container the files from chapters 7 and 8 and the gateway token under `/run/secrets/`. Those
copies belong to root, like the originals, and OpenClaw runs as an ordinary user, so the container starts as root for a
moment: the `entrypoint` lines copy the three values into a memory-only folder (`tmpfs`) that only OpenClaw's user can
read, make sure the state and backup folders belong to that user, then switch to it with `setpriv` and start the image
as usual. The image's health check runs through `setpriv` too, so nothing in the state folder is ever created by root.
For the same reason, every `docker exec` in this chapter uses `-u node`. Nothing is written to disk, and the values
never appear in `docker inspect` (chapter 8 shows why that matters).

`network_mode: host` with the gateway bound to `127.0.0.1` means no port is published, so Docker adds no firewall rules
of its own (chapter 4). `cap_drop` and `no-new-privileges` come from the project's own Compose file.

{{langkah:ejen/openclaw/compose}}

`restart: unless-stopped` starts OpenClaw again after a crash or a reboot.

## 5. Wait for the Telegram connection

The first start takes a minute or two: OpenClaw checks and prepares its state folder before the gateway opens. This
waits for the gateway's readiness check, then for the log line that says the Telegram connection has started. If the
gateway is not ready after five minutes, it shows the container status and the last log lines without their decoration,
which usually name the problem.

{{langkah:ejen/openclaw/sedia}}

## 6. Send your first message

Send any message to your bot from your phone. This command waits for the log line that says OpenClaw has sent its
answer, then shows the line for your incoming message. The answer arrives in Telegram.

OpenClaw also runs periodic background checks and may send you a short first note about them; the note says which
setting turns them off. The test run received that note too.

{{langkah:ejen/openclaw/mesej}}

## 7. Check the keys and tokens do not leak

This writes the model key, the bot token and the gateway token to a root-only file for a moment, counts how many lines
of `docker inspect`, the container log and the files in the state folder contain any of them, then deletes the file.
All three counts must be zero.

{{langkah:ejen/openclaw/semak-bocor}}

## 8. Check nothing is open to the internet

OpenClaw talks to Telegram and to your model provider by making outgoing connections, so it needs no open port and no
web address. The gateway listens on port 18789, bound to `127.0.0.1`:

{{langkah:ejen/openclaw/port}}

Run this on your own computer to confirm the port cannot be reached from outside:

{{langkah:ejen/openclaw/port-luar}}

You do not need the Caddy site from chapter 5 for OpenClaw. The gateway also serves a web control panel that can change
settings and run commands. Keep it on `127.0.0.1` and reach it through an SSH tunnel with the gateway token; do not
publish it on a port or behind a public web address.

## 9. Add OpenClaw to the daily backup

Copying a database while the agent writes to it can produce a broken copy. `openclaw backup create` makes a consistent
archive of the state folder, checks it with `--verify`, and does not write the values of keys into it. This adds
it to the daily backup script from chapter 6, before restic runs: it deletes yesterday's archive, writes a new one, and
restic stores the archive and the Compose file. It then runs the backup once and lists what restic stored.

{{langkah:ejen/openclaw/backup}}

If another agent from this guide already changed the `restic backup` line, add the two lines by hand instead.

## 10. Practise a restore

This writes a small restore script, `/usr/local/sbin/restore-openclaw`, and runs it. The script stops OpenClaw, deletes
the state folder, the archive and the Compose file, gets the archive and the Compose file back from restic, and unpacks
the archive with `openclaw backup restore` into an empty folder. OpenClaw never restores over live data, so the script
then copies the restored state folder into place. Before starting the gateway again, a one-off container lists the
conversations in the restored folder: the one from step 6 is back. `</dev/null` keeps the one-off containers from
reading the commands you paste after them.

{{langkah:ejen/openclaw/pulih}}

Keep the script: it is also how you go back after an update that went wrong (step 11).

## 11. Update, and go back if needed

Updating means changing the `image:` line to a newer tag and digest, then recreating the container. On each start the
image checks the state folder and migrates it to the new version's format if needed. A version that has already
migrated the state cannot simply be swapped for the older one: in the test, {{ejen:openclaw.imej_undur.tag}} never
opened its gateway on state that {{ejen:openclaw.imej.tag}} had written, as OpenClaw's own rollback documentation warns.
Going back therefore means the older image together with a backup made before the update.

So every update starts with the backup from step 9. This runs it, then updates to {{ejen:openclaw.imej.tag}}:

{{langkah:ejen/openclaw/kemas-kini}}

If the new version misbehaves, run the restore script. The latest restic snapshot is the one made just before the
update, so it brings back both the old Compose file (with the old `image:` line) and the old state:

{{langkah:ejen/openclaw/undur}}

Then update again, the same way:

{{langkah:ejen/openclaw/kemas-kini-semula}}

Send your bot another message from your phone, then check the agent answered after the update:

{{langkah:ejen/openclaw/mesej-selepas}}

For a real update, read the release notes on the project's releases page first, then take the new tag and its digest
from the image's page on the GitHub Container Registry.

## 12. Uninstall

This stops and removes the container and both images, takes OpenClaw out of the backup script, and deletes
`/srv/openclaw` with all conversations and memory, the gateway token and the restore script. Skip the `rm` line if you want to keep the
data. The key files from chapters 7 and 8 and the restic snapshots stay; remove them separately if you no longer need
them.

{{langkah:ejen/openclaw/nyahpasang}}

---

Stuck on a step? Sasa Teguh Academy runs guided setup sessions: https://academy.sasateguh.com
