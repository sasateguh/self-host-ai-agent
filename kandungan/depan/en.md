# Self-host an AI agent on a VPS

[Bahasa Melayu](README.ms.md)

A step-by-step guide to running your own AI agent, such as Hermes Agent or OpenClaw, on a Linux server you rent and
control, with a Telegram bot as the way you talk to it. Every command in this guide was run on a clean Ubuntu
{{config:ubuntu.versi}} machine before it was published, and the record of that run is kept in this repository.

**Short answer:** rent a small Ubuntu {{config:ubuntu.versi}} VPS with at least {{config:vps.ram_gb}} GB of RAM, lock
SSH to keys only, turn on the firewall and automatic security updates, install Docker, and run the agent as a container
that only listens on the server itself. Keep the model API key in a file only root can read, talk to the agent through
a Telegram bot, and back up its data in a way you have restored at least once. The chapters below walk through each of
those steps in order.

## Who this is for

- You want an AI agent that runs all day on your own server, not on your laptop.
- You are comfortable copying commands into a terminal, but you do not run servers for a living.
- You want each step explained: what it does, how to check it worked, and how to undo it.

## Chapters

Read the shared chapters in order, then the chapter for your agent. Agent chapters link back to the shared chapters
instead of repeating them. The "Tested on" column is filled in from the test record of each chapter, not typed by hand.

{{kandungan}}

Agent versions tested: Hermes Agent {{ejen:hermes-agent.ejen.versi}}, OpenClaw {{ejen:openclaw.ejen.versi}}.

## How the guide is tested

Commands live in step files under `langkah/`. A test runner starts a fresh Ubuntu container, or a full virtual machine
for chapters that touch SSH, the firewall or systemd, and runs every block in order. It writes a record to `bukti/`: the
Ubuntu image and its digest, the date, a checksum of the step file and the exit code of every block. The chapters in
`en/` and `ms/` are generated from the same step files, so the commands you copy are the commands that were tested.
A chapter whose step file changed after its last test run fails the build until it is tested again.

Tests use a stand-in model provider and a stand-in Telegram server, so no real API key or bot token is ever involved.
Firewall and SSH checks are made from outside the virtual machine, the way an attacker on the internet would see them.

## What this guide does not cover

- Prices or recommendations for a specific VPS provider. Chapter 1 lists what to look for and how to check it yourself.
- Running an agent on your own computer or on a managed platform.
- Choosing a model provider. The agent chapters connect to any provider with an OpenAI-compatible API; the agent's own
  documentation covers the others.

## Contributing and security

Fixes and new agent chapters are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md). If you find a step that leaves a
server exposed, please report it privately as described in [SECURITY.md](SECURITY.md). Changes are listed in
[CHANGELOG.md](CHANGELOG.md).

## License

Guide text: CC BY 4.0 ([LICENSE-CONTENT](LICENSE-CONTENT)). Scripts and tools: MIT ([LICENSE](LICENSE)).

## Work with Sasa Teguh

[![Work with Sasa Teguh: book a call](https://raw.githubusercontent.com/sasateguh/.github/main/assets/work-with-sasa-teguh.png)](https://sasateguh.com/book)

This project is built and maintained by [Sasa Teguh](https://sasateguh.com), a studio in Malaysia. We build websites that are found on Google and in AI answers, and we set up systems like this one for businesses.

[Book a call](https://sasateguh.com/book) · hello@sasateguh.com · [More from Sasa Teguh](https://github.com/sasateguh)
