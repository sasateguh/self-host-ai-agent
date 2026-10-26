# <Agent name> on your server

**Short answer:** two or three sentences that answer "how do I run this agent on my own server" on their own: which
official image, how the key and bot token reach it, how the reader talks to it, how it is backed up and updated.

Tested on: {{diuji:ejen/<name>}}, with <Agent name> {{ejen:<name>.ejen.versi}} (released
{{ejen:<name>.ejen.tarikh_keluaran}}).

One paragraph on what the agent is, who makes it, its licence ({{ejen:<name>.ejen.lesen}}), source
({{ejen:<name>.ejen.repo}}) and documentation ({{ejen:<name>.ejen.dokumen}}).

Run these steps as the user from chapter 2, on a server that has been through chapters 3 (firewall), 4 (Docker),
6 (backup), 7 (Telegram bot) and 8 (model API key). The test run used a stand-in model provider and a stand-in Telegram
API, made-up keys, and a test message in place of one typed on a phone.

## 1. Download the tested version

{{langkah:ejen/<name>/tarik}}

## 2. Write the settings file

{{langkah:ejen/<name>/config}}

## 3. Choose the model

{{langkah:ejen/<name>/model}}

## 4. Start the agent with Docker Compose

{{langkah:ejen/<name>/compose}}

## 5. Wait for the Telegram connection

{{langkah:ejen/<name>/sedia}}

## 6. Send your first message

{{langkah:ejen/<name>/mesej}}

## 7. Check the key and the token do not leak

{{langkah:ejen/<name>/semak-bocor}}

## 8. Check nothing is open to the internet

{{langkah:ejen/<name>/port-luar}}

## 9. Add the agent to the daily backup

{{langkah:ejen/<name>/backup}}

## 10. Practise a restore

{{langkah:ejen/<name>/pulih}}

## 11. Update, and go back if needed

{{langkah:ejen/<name>/undur}}

{{langkah:ejen/<name>/kemas-kini}}

## 12. Uninstall

{{langkah:ejen/<name>/nyahpasang}}

---

Stuck on a step? Sasa Teguh Academy runs guided setup sessions: https://academy.sasateguh.com
