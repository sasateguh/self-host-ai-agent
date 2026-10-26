# How each command is tested

**Short answer:** each chapter's commands live in a step file. A test runner runs that file, one step at a time, in a
fresh Ubuntu container (or a virtual machine for SSH and firewall chapters) and records the exit code of every step. The
chapter you read is generated from the same file, so a command that was not tested cannot appear in it.

Tested on: {{diuji:teras/00-contoh}}.

This sample chapter is not part of the setup. It shows the format the other chapters follow.

## 1. Check the operating system

The test machine must be the Ubuntu release this guide targets ({{config:ubuntu.versi}}).

{{langkah:teras/00-contoh/semak-os}}

## 2. Install a package

{{langkah:teras/00-contoh/pasang-curl}}

## 3. Talk to a model provider

Tests never use a real model provider or a real key. The runner starts a fake provider that speaks the same API and sets
`OPENAI_BASE_URL` and `OPENAI_API_KEY` to point at it. On your own server, these two values come from your provider.

{{langkah:teras/00-contoh/model-palsu}}

## 4. Send a Telegram message

The same applies to Telegram: in tests, `TELEGRAM_API_URL` points at a fake Bot API server, so no message leaves the
test machine.

{{langkah:teras/00-contoh/telegram-palsu}}
