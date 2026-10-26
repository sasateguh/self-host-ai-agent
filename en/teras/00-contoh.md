<!-- generated from kandungan/en/teras/00-contoh.md by alat/bina.py: edit the template, not this file -->
# How each command is tested

**Short answer:** each chapter's commands live in a step file. A test runner runs that file, one step at a time, in a
fresh Ubuntu container (or a virtual machine for SSH and firewall chapters) and records the exit code of every step. The
chapter you read is generated from the same file, so a command that was not tested cannot appear in it.

Tested on: `ubuntu:24.04`, 2026-10-26.

This sample chapter is not part of the setup. It shows the format the other chapters follow.

## 1. Check the operating system

The test machine must be the Ubuntu release this guide targets (24.04).

```bash
. /etc/os-release
echo "$PRETTY_NAME"
test "$ID" = ubuntu
```

## 2. Install a package

```bash
apt-get update -qq
apt-get install -y -qq --no-install-recommends curl ca-certificates >/dev/null
curl --version | sed -n 1p
```

## 3. Talk to a model provider

Tests never use a real model provider or a real key. The runner starts a fake provider that speaks the same API and sets
`OPENAI_BASE_URL` and `OPENAI_API_KEY` to point at it. On your own server, these two values come from your provider.

```bash
curl -fsS "$OPENAI_BASE_URL/chat/completions" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "palsu-model", "messages": [{"role": "user", "content": "hello"}]}' \
  | grep -o '"content": "[^"]*"'
```

## 4. Send a Telegram message

The same applies to Telegram: in tests, `TELEGRAM_API_URL` points at a fake Bot API server, so no message leaves the
test machine.

```bash
curl -fsS "$TELEGRAM_API_URL/bot$TELEGRAM_BOT_TOKEN/getMe" | grep '"ok": true' >/dev/null
curl -fsS "$TELEGRAM_API_URL/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d chat_id=1001 -d text="test message" \
  | grep -o '"text": "[^"]*"'
```
