# Security

Bahasa Melayu: [SECURITY.ms.md](SECURITY.ms.md)

This guide tells people how to put a server on the internet, so a mistake in it can leave real servers open. We treat
reports about the guide itself as security reports.

## What to report

- A step that leaves a port, a service or a file open to the internet when the chapter says it is closed.
- A step that puts an API key, a bot token or a password where other users or containers can read it, or into a log,
  an image or shell history.
- A step that weakens SSH, the firewall or automatic updates set up in an earlier chapter.
- A problem in the test runner (`alat/`, `uji/`) that makes a failing step look like it passed.

Mistakes in the agents themselves (Hermes Agent, OpenClaw) belong to those projects. Please report them there; tell us
too if a chapter needs to change because of it.

## How to report

Use "Report a vulnerability" on the Security tab of this repository, or email hello@sasateguh.com with "security" in the
subject. Please include the chapter, the step id (`# @langkah <id>`) and what you saw. Do not open a public issue for a
problem that leaves servers exposed until a fix is published.

We aim to reply within 7 days. When a fix changes a step, the chapter is tested again and the change is listed in
[CHANGELOG.md](CHANGELOG.md).

## Supported versions

Only the current main branch is maintained. Each chapter states the Ubuntu image and the date its steps last passed,
and each agent chapter states the agent version it was tested with.
