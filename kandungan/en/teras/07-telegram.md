# 7. A Telegram bot for your server

**Short answer:** create a bot with Telegram's @BotFather, paste its token into a file only root can read, send the bot
one message from your phone, then look up your chat ID and send a test message back. The agent chapters and the
monitoring in chapter 9 use this bot and this file.

Tested on: {{diuji:teras/07-telegram}}.

Run these steps as the user from chapter 2. The test run talks to a stand-in for the Telegram API, so no real bot was
used.

## 1. Create the bot (on your phone)

1. In Telegram, open a chat with **@BotFather** (check for the blue verified tick; copies exist).
2. Send `/newbot`, then a display name, then a username that ends in `bot`.
3. BotFather replies with a token that looks like `123456789:AA...`. Anyone holding it controls the bot. Do not paste it
   into a chat, a screenshot or a file you commit.
4. Open a chat with your new bot and send it any message, for example `/start`. A bot cannot write to you first, and
   step 4 below finds your chat ID from this message.

## 2. Install the tools

{{langkah:teras/07-telegram/alat}}

## 3. Store the token in a root-only file

The commands create `/etc/agent`, readable by root only, and a file inside it with mode `600`. The last command waits for
you to paste the token and press Enter. It reads the token without showing it, so it never appears on screen, in your
shell history, or in the list of running processes. `TELEGRAM_API_URL` is the address of the Telegram API; leave it as
it is.

{{langkah:teras/07-telegram/simpan-token}}

## 4. Check the token

This asks Telegram who the bot is and prints its username. The token is passed to `curl` through its standard input,
not on the command line, so other users on the server cannot see it in the process list.

{{langkah:teras/07-telegram/semak-bot}}

If you see `401 Unauthorized`, the token was pasted wrong. Run step 3 again.

## 5. Find your chat ID

The bot lists the messages waiting for it. You should see your `/start` message with a number in front: that number is
your chat ID. The last line saves it to the same file.

{{langkah:teras/07-telegram/id-sembang}}

If the list is empty, send the bot another message from your phone and run this step again.

## 6. Send a test message

The message arrives on your phone and the command prints its text.

{{langkah:teras/07-telegram/hantar}}

## 7. Check the file

The file must be mode `600` and owned by root. The last command shows the setting names with the values hidden.

{{langkah:teras/07-telegram/kebenaran}}

If the token ever leaks, open @BotFather, send `/revoke`, pick the bot, and repeat step 3 with the new token.
