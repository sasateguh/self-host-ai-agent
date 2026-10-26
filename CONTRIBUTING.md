# Contributing

Thank you for helping. This guide has one rule above all others: every command a reader runs has been run first, on a
clean Ubuntu server, by the test runner in this repository, and the result is saved in `bukti/`. A change to a command
without a fresh test run is not accepted.

Bahasa Melayu: [CONTRIBUTING.ms.md](CONTRIBUTING.ms.md)

## How the repository fits together

- `langkah/` holds the commands, one file per chapter, split into named blocks (`# @langkah <id>`).
- `kandungan/en/` and `kandungan/ms/` hold the prose for each chapter in English and Malay. They pull commands in with
  `{{langkah:<chapter>/<id>}}` and never contain typed shell blocks.
- `alat/uji.py <chapter>` runs every block of a chapter in a fresh Ubuntu container or virtual machine and writes
  `bukti/<chapter>.json`: the image digest, the date, a checksum of the commands and the exit code of every block.
- `alat/bina.py` builds `en/` and `ms/` from the prose, the commands and `config/panduan.toml`, and builds `README.md` and
  `README.ms.md` from `kandungan/depan/`, with the "Tested on" column read from `bukti/`. Do not edit `en/`, `ms/` or the
  two README files by hand; `alat/bina.py --semak` fails when they differ from what it would build.
- `ejen/<name>/ejen.toml` pins the tested version of each agent: release, image tag and image digest.

Model providers and Telegram are replaced by a local stand-in server during tests (`uji/palsu/`). Never put a real key
or bot token in a test, a file or a commit.

## Adding an agent

An agent chapter must not change the core chapters (`langkah/teras/`, `kandungan/*/teras/`). If the core needs a fix,
send that fix as its own change first, with fresh test runs for the chapters it touches.

1. Copy the templates in `ejen/_templat/`:
   `ejen.toml` to `ejen/<name>/ejen.toml`, `langkah.sh` to `langkah/ejen/<name>.sh`, `en.md` to
   `kandungan/en/ejen/<name>.md` and `ms.md` to `kandungan/ms/ejen/<name>.md`. Use a short lower-case name with
   hyphens, the same in all four places.
2. Pick the newest stable release and the one before it. Read the project's own documentation at that release tag, not
   the main branch, and list the pages you followed in `ejen.toml`.
3. Pin both images by tag and digest. `docker buildx imagetools inspect <image>:<tag>` prints the digest. The build
   step refuses any image reference in the commands that is not exactly one of the two pinned in `ejen.toml`.
4. Write the blocks. Follow the core chapters: the agent runs in Docker Compose, publishes no port, reads the model key
   and bot token from the files made in chapters 7 and 8 (never from `-e` or the image), only answers the reader's own
   Telegram chat ID, is added to the backup from chapter 6, and has a tested restore, rollback, update and uninstall.
5. Run the chapter: `python3 alat/uji.py ejen/<name>`. Agent images are large, so the template asks for a virtual
   machine with a bigger disk. The run must pass, and the stand-in Telegram server must record the agent's answer.
6. Write the prose in both languages, then run `python3 alat/bina.py` and commit the commands, the prose, `ejen.toml`,
   the new `bukti/` file and the built `en/` and `ms/` files together.

## Rules for command blocks

- Use the example values from `config/panduan.toml` literally: user `ejen`, server `203.0.113.10`, domain
  `example.com`. The build step rejects other names.
- Each block runs as one `bash -c` script under `set -euo pipefail`. Do not pipe into `head` or `grep -q`: they exit
  early and the block fails with code 141. Use `sed -n` or `grep ... >/dev/null`.
- A block that pastes a value (`# @tampal`) must read it with `read`, or the test fails. Commands that read standard
  input inside a longer block need `</dev/null`.
- `# @mesej <text>` stands for a message the reader types to the bot on their phone before the block runs.
- `# @selepas <chapters>` lists the core chapters to run first in the same machine.

## Writing

- English and Malaysian Malay (not Indonesian), written for someone running their first server. Short sentences, no
  marketing words.
- No provider prices, affiliate links, requests for stars, invented numbers or testimonials.
- Every chapter starts with a short answer of two or three sentences.

Content is licensed under CC BY 4.0 (`LICENSE-CONTENT`) and code under MIT (`LICENSE`). By contributing you agree to
license your work the same way.
