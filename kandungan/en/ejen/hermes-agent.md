# Hermes Agent on your server

**Short answer:** run the official Hermes Agent Docker image, pinned to one tested version, with Docker Compose. Give it
your model API key and Telegram bot token as Compose secret files from chapters 7 and 8, point it at an
OpenAI-compatible model provider, and talk to it from your phone through your own Telegram bot. Back up its data with
its own backup command plus restic, and update by changing one line.

Tested on: {{diuji:ejen/hermes-agent}}, with Hermes Agent {{ejen:hermes-agent.ejen.versi}} (released
{{ejen:hermes-agent.ejen.tarikh_keluaran}}).

Hermes Agent is an open source AI agent by Nous Research ({{ejen:hermes-agent.ejen.lesen}} licence, source at
{{ejen:hermes-agent.ejen.repo}}, documentation at {{ejen:hermes-agent.ejen.dokumen}}). It keeps a memory and skills
between conversations and answers you on chat platforms such as Telegram. This chapter follows the project's own Docker
documentation for the version above.

Run these steps as the user from chapter 2, on a server that has been through chapters 3 (firewall), 4 (Docker),
6 (backup), 7 (Telegram bot) and 8 (model API key). The test run used a stand-in model provider and a stand-in Telegram
API, made-up keys, and a test message in place of one typed on a phone.

## 1. Download the tested version

The image name ends with a tag (`{{ejen:hermes-agent.imej.tag}}`) and a digest (`sha256:...`). The tag is the version
name; the digest is a fingerprint of the exact image that was tested, so Docker refuses anything else, even if someone
moves the tag later. The image is about 1 GB to download and about 4 GB on disk.

{{langkah:ejen/hermes-agent/tarik}}

## 2. Write the settings file

Hermes keeps everything it learns in one data folder, here `/srv/hermes/data`. The settings file tells it to use an
OpenAI-compatible provider at `OPENAI_BASE_URL` (the same address as chapter 8; set it first if your provider gave you
one) and to read the key from the variable `MODEL_API_KEY`. The key itself is not in this file.

The `if` block only adds a line when the Telegram address saved in chapter 7 is not Telegram's own, for example if you
run a local Bot API server. With the normal address it adds nothing.

{{langkah:ejen/hermes-agent/config}}

## 3. Choose the model

This lists the models your key can use, then waits for you to type one of the names and press Enter.

{{langkah:ejen/hermes-agent/model}}

## 4. Start Hermes with Docker Compose

The Compose file gives the container the two files from chapters 7 and 8 under `/run/secrets/`. The `entrypoint` lines
read them into the environment of the agent's own processes and then start the image as usual, so the key and token
never appear in `docker inspect` (chapter 8 shows why that matters). `TELEGRAM_ALLOWED_USERS` is set to your chat ID
from chapter 7: the bot ignores everyone else.

`network_mode: host` is what the project's own Compose file uses. No port is published, so Docker adds no firewall
rules of its own (chapter 4), and the firewall from chapter 3 still applies to anything Hermes listens on.

{{langkah:ejen/hermes-agent/compose}}

`restart: unless-stopped` starts Hermes again after a crash or a reboot. Inside the container, a supervisor restarts the
agent within seconds if it stops.

## 5. Wait for the Telegram connection

The first start takes a minute or two while Hermes prepares its data folder. This waits for the log line that says it
has connected to Telegram.

{{langkah:ejen/hermes-agent/sedia}}

## 6. Send your first message

Send any message to your bot from your phone. This command waits until Hermes has sent its answer, then shows the
log lines for the conversation. The answer arrives in Telegram.

{{langkah:ejen/hermes-agent/mesej}}

## 7. Check the key and the token do not leak

This writes the key and the token to a root-only file for a moment, counts how many lines of `docker inspect`, the
container log and the files in the data folder contain either of them, then deletes the file. All three counts must be
zero.

{{langkah:ejen/hermes-agent/semak-bocor}}

## 8. Check nothing is open to the internet

Hermes talks to Telegram and to your model provider by making outgoing connections, so it needs no open port and no
web address. It does listen on two ports, its local API and one internal port, and both are bound to `127.0.0.1`:

{{langkah:ejen/hermes-agent/port}}

Run this on your own computer to confirm the API port cannot be reached from outside:

{{langkah:ejen/hermes-agent/port-luar}}

You do not need the Caddy site from chapter 5 for Hermes. Hermes also has an optional web dashboard and an API server
that can control the agent and read its keys. Keep them on `127.0.0.1` and reach them through an SSH tunnel; do not
publish them on a port or behind a public web address.

## 9. Add Hermes to the daily backup

Copying a database while the agent writes to it can produce a broken copy. `hermes backup` makes a consistent zip file
of the whole data folder, including conversations, memory, skills and settings. This adds it to the daily backup script
from chapter 6, before restic runs, and backs up the zip and the Compose file. It then runs the backup once and lists
what restic stored.

{{langkah:ejen/hermes-agent/backup}}

## 10. Practise a restore

This deletes the data folder, restores the zip and the Compose file with restic, imports the zip with `hermes import`
while the agent is stopped, and starts it again. The conversation from step 6 is back in the session list. `</dev/null`
keeps the one-off import container from reading the commands you paste after it.

{{langkah:ejen/hermes-agent/pulih}}

## 11. Update, and go back if needed

Updating means changing the `image:` line to a newer tag and digest, then recreating the container. Your data folder
stays, and Hermes migrates its settings file on start, keeping a copy of the old one in `data/backups/config/`. Run the
backup from step 9 before you update.

To practise both directions, switch to the previous release ({{ejen:hermes-agent.imej_undur.tag}}), which is what you
would do if a new version misbehaves:

{{langkah:ejen/hermes-agent/undur}}

Then update back to the tested version:

{{langkah:ejen/hermes-agent/kemas-kini}}

Send your bot another message from your phone, then check the agent answered after the update:

{{langkah:ejen/hermes-agent/mesej-selepas}}

For a real update, read the release notes on the project's releases page first, then take the new tag and its digest
from the image's page on Docker Hub.

## 12. Uninstall

This stops and removes the container and both images, takes Hermes out of the backup script, and deletes `/srv/hermes`
with all conversations and memory. Skip the `rm` line if you want to keep the data. The key files in `/etc/agent` and
the restic snapshots stay; remove them separately if you no longer need them.

{{langkah:ejen/hermes-agent/nyahpasang}}

---

Stuck on a step? Sasa Teguh Academy runs guided setup sessions: https://academy.sasateguh.com
