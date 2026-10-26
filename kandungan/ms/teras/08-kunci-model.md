# 8. Menyembunyikan kunci API model

**Jawapan ringkas:** tampal kunci API dari penyedia model anda ke dalam fail khas root, dan berikan kepada bekas sebagai
`secret` Compose (fail yang dipasang di `/run/secrets/`), bukan sebagai pemboleh ubah persekitaran pada baris arahan atau
dalam `compose.yaml`. Pemboleh ubah persekitaran yang ditetapkan dengan `-e` atau `environment:` boleh dilihat oleh
sesiapa yang boleh menjalankan `docker inspect`. Langkah di bawah menunjukkan perkara itu, kemudian menyemak bahawa cara
fail menjauhkan kunci dari `docker inspect` dan log, dan memutar kunci.

Diuji pada: {{diuji:teras/08-kunci-model}}.

Jalankan langkah ini sebagai pengguna dari bab 2, pada pelayan yang ada Docker dari bab 4. Larian ujian memakai
pengganti penyedia model dan kunci rekaan.

## 1. Dapatkan kunci

Cipta kunci API dalam papan pemuka penyedia model anda. Kebanyakan penyedia membenarkan anda mengehadkan kunci: beri had
belanja dan, jika ada, akses kepada model yang diperlukan ejen sahaja. Guna satu kunci bagi setiap pelayan supaya anda
boleh membatalkannya tanpa merosakkan perkara lain.

## 2. Pasang alat

{{langkah:teras/08-kunci-model/alat}}

## 3. Simpan kunci dalam fail khas root

Arahan terakhir menunggu anda menampal kunci dan menekan Enter. Ia tidak memaparkan kunci dan tidak menyimpannya dalam
sejarah shell anda.

{{langkah:teras/08-kunci-model/simpan-kunci}}

## 4. Semak kunci berfungsi

Ini menyenaraikan model yang boleh dipakai kunci itu. Kunci dihantar kepada `curl` melalui input standard, jadi ia tidak
pernah muncul dalam senarai proses. `OPENAI_BASE_URL` ialah alamat API yang serasi OpenAI; jika penyedia anda memberi
alamat lain, tetapkan dahulu, contohnya `export OPENAI_BASE_URL=https://your-provider.example/v1`.

{{langkah:teras/08-kunci-model/uji-kunci}}

## 5. Lihat masalahnya: pemboleh ubah persekitaran boleh dilihat

Banyak arahan ejen menyebut `docker run -e OPENAI_API_KEY=...`. Ini memulakan bekas dengan cara itu memakai kunci
palsu dan menunjukkan di mana ia berakhir. Kiraan pada baris terakhir ialah bilangan baris output `docker inspect` yang
mengandungi kunci itu:

{{langkah:teras/08-kunci-model/env-kelihatan}}

Perkara sama berlaku pada `environment:` dalam `compose.yaml`, dan pada fail itu sendiri jika anda mengkomitnya ke git.

## 6. Berikan kunci kepada bekas sebagai fail

Compose memasang fail kunci di `/run/secrets/model_key` dalam bekas. Arahan bekas membacanya ke dalam persekitaran
prosesnya sendiri sahaja. Contoh ini mencetak panjang kunci, bukan kunci itu.

{{langkah:teras/08-kunci-model/compose-rahsia}}

Bab ejen memakai blok `secrets:` yang sama. Sesetengah ejen membaca fail itu terus (cari tetapan yang berakhir dengan
`_FILE`); yang lain memerlukan baris `export` seperti di sini.

## 7. Semak kunci tidak bocor

Arahan ini mencari kunci itu sendiri dalam seluruh output `docker inspect` dan log bekas. Kedua-dua kiraan mesti sifar.

{{langkah:teras/08-kunci-model/semak-bocor}}

## 8. Putar kunci

Putar kunci bila seseorang yang ada akses pergi, bila kunci mungkin bocor, atau mengikut jadual. Cipta kunci baharu di
penyedia dahulu, kemudian tampal di sini.

{{langkah:teras/08-kunci-model/putar}}

Bekas yang sedang berjalan memegang kunci lama sehingga ia dicipta semula. `--force-recreate` melakukannya; baris log
menunjukkan panjang kunci baharu, dan senarai model membuktikan kunci baharu berfungsi.

{{langkah:teras/08-kunci-model/guna-kunci-baharu}}

Sekarang batalkan kunci lama dalam papan pemuka penyedia.

## 9. Kemas

Buang projek dan imej ujian. Fail kunci kekal untuk bab ejen.

{{langkah:teras/08-kunci-model/kemas}}
