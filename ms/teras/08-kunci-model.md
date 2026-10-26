<!-- generated from kandungan/ms/teras/08-kunci-model.md by alat/bina.py: edit the template, not this file -->
# 8. Menyembunyikan kunci API model

**Jawapan ringkas:** tampal kunci API dari penyedia model anda ke dalam fail khas root, dan berikan kepada bekas sebagai
`secret` Compose (fail yang dipasang di `/run/secrets/`), bukan sebagai pemboleh ubah persekitaran pada baris arahan atau
dalam `compose.yaml`. Pemboleh ubah persekitaran yang ditetapkan dengan `-e` atau `environment:` boleh dilihat oleh
sesiapa yang boleh menjalankan `docker inspect`. Langkah di bawah menunjukkan perkara itu, kemudian menyemak bahawa cara
fail menjauhkan kunci dari `docker inspect` dan log, dan memutar kunci.

Diuji pada: `ubuntu:24.04` (VM), 2026-10-26.

Jalankan langkah ini sebagai pengguna dari bab 2, pada pelayan yang ada Docker dari bab 4. Larian ujian memakai
pengganti penyedia model dan kunci rekaan.

## 1. Dapatkan kunci

Cipta kunci API dalam papan pemuka penyedia model anda. Kebanyakan penyedia membenarkan anda mengehadkan kunci: beri had
belanja dan, jika ada, akses kepada model yang diperlukan ejen sahaja. Guna satu kunci bagi setiap pelayan supaya anda
boleh membatalkannya tanpa merosakkan perkara lain.

## 2. Pasang alat

```bash
sudo apt-get update
sudo apt-get install -y curl jq
```

## 3. Simpan kunci dalam fail khas root

Arahan terakhir menunggu anda menampal kunci dan menekan Enter. Ia tidak memaparkan kunci dan tidak menyimpannya dalam
sejarah shell anda.

```bash
sudo install -d -m 700 /etc/agent
sudo install -m 600 /dev/null /etc/agent/model.key
sudo bash -c 'read -rsp "Paste the API key, then press Enter: " k; echo; printf "%s" "$k" > /etc/agent/model.key'
```

## 4. Semak kunci berfungsi

Ini menyenaraikan model yang boleh dipakai kunci itu. Kunci dihantar kepada `curl` melalui input standard, jadi ia tidak
pernah muncul dalam senarai proses. `OPENAI_BASE_URL` ialah alamat API yang serasi OpenAI; jika penyedia anda memberi
alamat lain, tetapkan dahulu, contohnya `export OPENAI_BASE_URL=https://your-provider.example/v1`.

```bash
sudo test -s /etc/agent/model.key
sudo stat -c '%a %U %n' /etc/agent/model.key
sudo sh -c 'printf "header = \"Authorization: Bearer %s\"\n" "$(cat /etc/agent/model.key)"' \
  | curl -fsS -K - "${OPENAI_BASE_URL:-https://api.openai.com/v1}/models" | jq -r '.data[:5][].id'
```

## 5. Lihat masalahnya: pemboleh ubah persekitaran boleh dilihat

Banyak arahan ejen menyebut `docker run -e OPENAI_API_KEY=...`. Ini memulakan bekas dengan cara itu memakai kunci
palsu dan menunjukkan di mana ia berakhir. Kiraan pada baris terakhir ialah bilangan baris output `docker inspect` yang
mengandungi kunci itu:

```bash
sudo docker run -d --name env-check -e OPENAI_API_KEY=example-not-a-real-key alpine:3.20 sleep 300 >/dev/null
sudo docker inspect env-check --format '{{json .Config.Env}}'
sudo docker inspect env-check | grep -c example-not-a-real-key
sudo docker rm -f env-check
```

Perkara sama berlaku pada `environment:` dalam `compose.yaml`, dan pada fail itu sendiri jika anda mengkomitnya ke git.

## 6. Berikan kunci kepada bekas sebagai fail

Compose memasang fail kunci di `/run/secrets/model_key` dalam bekas. Arahan bekas membacanya ke dalam persekitaran
prosesnya sendiri sahaja. Contoh ini mencetak panjang kunci, bukan kunci itu.

```bash
sudo install -d /srv/key-check
sudo tee /srv/key-check/compose.yaml >/dev/null <<'EOF'
services:
  key-check:
    image: alpine:3.20
    restart: unless-stopped
    # The key arrives as a file and is read into the environment of this process only.
    command: ["sh", "-c", "export OPENAI_API_KEY=\"$$(cat /run/secrets/model_key)\"; echo \"key loaded: $${#OPENAI_API_KEY} characters\"; exec sleep infinity"]
    secrets:
      - model_key
secrets:
  model_key:
    file: /etc/agent/model.key
EOF
cd /srv/key-check
sudo docker compose up -d --wait
sudo docker compose logs --no-log-prefix
```

Bab ejen memakai blok `secrets:` yang sama. Sesetengah ejen membaca fail itu terus (cari tetapan yang berakhir dengan
`_FILE`); yang lain memerlukan baris `export` seperti di sini.

## 7. Semak kunci tidak bocor

Arahan ini mencari kunci itu sendiri dalam seluruh output `docker inspect` dan log bekas. Kedua-dua kiraan mesti sifar.

```bash
cd /srv/key-check
id="$(sudo docker compose ps -q key-check)"
sudo docker inspect "$id" --format '{{json .Config.Env}}'
test "$(sudo docker inspect "$id" | sudo grep -c -F -f /etc/agent/model.key)" = 0
test "$(sudo docker compose logs | sudo grep -c -F -f /etc/agent/model.key)" = 0
echo "the key is not in docker inspect or in the logs"
```

## 8. Putar kunci

Putar kunci bila seseorang yang ada akses pergi, bila kunci mungkin bocor, atau mengikut jadual. Cipta kunci baharu di
penyedia dahulu, kemudian tampal di sini.

```bash
sudo bash -c 'read -rsp "Paste the NEW API key, then press Enter: " k; echo; printf "%s" "$k" > /etc/agent/model.key'
```

Bekas yang sedang berjalan memegang kunci lama sehingga ia dicipta semula. `--force-recreate` melakukannya; baris log
menunjukkan panjang kunci baharu, dan senarai model membuktikan kunci baharu berfungsi.

```bash
cd /srv/key-check
sudo docker compose up -d --wait --force-recreate
sudo docker compose logs --no-log-prefix
test "$(sudo docker compose logs --no-log-prefix | tail -n 1)" = "key loaded: $(sudo stat -c %s /etc/agent/model.key) characters"
sudo sh -c 'printf "header = \"Authorization: Bearer %s\"\n" "$(cat /etc/agent/model.key)"' \
  | curl -fsS -K - "${OPENAI_BASE_URL:-https://api.openai.com/v1}/models" | jq -r '.data[:5][].id'
```

Sekarang batalkan kunci lama dalam papan pemuka penyedia.

## 9. Kemas

Buang projek dan imej ujian. Fail kunci kekal untuk bab ejen.

```bash
cd /srv/key-check
sudo docker compose down
cd /
sudo rm -r /srv/key-check
sudo docker image rm alpine:3.20
```
