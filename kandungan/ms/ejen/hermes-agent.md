# Hermes Agent di pelayan anda

**Jawapan ringkas:** jalankan imej Docker rasmi Hermes Agent, dipin pada satu versi yang diuji, dengan Docker Compose.
Beri kunci API model dan token bot Telegram anda sebagai fail Compose `secrets` dari bab 7 dan 8, halakan ia ke
penyedia model serasi OpenAI, dan bercakap dengannya dari telefon melalui bot Telegram anda sendiri. Backup datanya
dengan arahan backup Hermes sendiri ditambah restic, dan kemas kini dengan menukar satu baris.

Diuji pada: {{diuji:ejen/hermes-agent}}, dengan Hermes Agent {{ejen:hermes-agent.ejen.versi}} (dikeluarkan
{{ejen:hermes-agent.ejen.tarikh_keluaran}}).

Hermes Agent ialah ejen AI sumber terbuka oleh Nous Research (lesen {{ejen:hermes-agent.ejen.lesen}}, kod sumber di
{{ejen:hermes-agent.ejen.repo}}, dokumentasi di {{ejen:hermes-agent.ejen.dokumen}}). Ia menyimpan memori dan kemahiran
antara perbualan dan menjawab anda di platform sembang seperti Telegram. Bab ini mengikut dokumentasi Docker projek itu
sendiri untuk versi di atas.

Jalankan langkah ini sebagai pengguna dari bab 2, di pelayan yang sudah melalui bab 3 (firewall), 4 (Docker), 6 (backup),
7 (bot Telegram) dan 8 (kunci API model). Larian ujian memakai pengganti penyedia model dan pengganti API Telegram, kunci
rekaan, dan mesej ujian sebagai ganti mesej yang ditaip di telefon.

## 1. Muat turun versi yang diuji

Nama imej berakhir dengan tag (`{{ejen:hermes-agent.imej.tag}}`) dan digest (`sha256:...`). Tag ialah nama versi; digest
ialah cap jari imej tepat yang diuji, jadi Docker menolak imej lain walaupun seseorang memindahkan tag itu kemudian. Imej
ini kira-kira 1 GB untuk dimuat turun dan kira-kira 4 GB di cakera.

{{langkah:ejen/hermes-agent/tarik}}

## 2. Tulis fail tetapan

Hermes menyimpan semua yang dipelajarinya dalam satu folder data, di sini `/srv/hermes/data`. Fail tetapan memberitahunya
supaya memakai penyedia serasi OpenAI di `OPENAI_BASE_URL` (alamat yang sama seperti bab 8; tetapkan dahulu jika penyedia
anda memberi alamat lain) dan membaca kunci dari pemboleh ubah `MODEL_API_KEY`. Kunci itu sendiri tiada dalam fail ini.

Blok `if` hanya menambah baris bila alamat Telegram yang disimpan dalam bab 7 bukan alamat Telegram sendiri, contohnya
jika anda menjalankan pelayan Bot API tempatan. Dengan alamat biasa, ia tidak menambah apa-apa.

{{langkah:ejen/hermes-agent/config}}

## 3. Pilih model

Arahan ini menyenaraikan model yang boleh dipakai oleh kunci anda, kemudian menunggu anda menaip salah satu nama itu dan
menekan Enter.

{{langkah:ejen/hermes-agent/model}}

## 4. Mulakan Hermes dengan Docker Compose

Fail Compose memberi bekas dua fail dari bab 7 dan 8 di bawah `/run/secrets/`. Baris `entrypoint` membaca kedua-duanya
ke dalam persekitaran proses ejen sahaja, kemudian memulakan imej seperti biasa, jadi kunci dan token tidak pernah muncul
dalam `docker inspect` (bab 8 menunjukkan mengapa itu penting). `TELEGRAM_ALLOWED_USERS` ditetapkan kepada ID sembang anda
dari bab 7: bot mengabaikan orang lain.

`network_mode: host` ialah apa yang dipakai fail Compose projek itu sendiri. Tiada port diterbitkan, jadi Docker tidak
menambah peraturan firewall sendiri (bab 4), dan firewall dari bab 3 masih terpakai pada apa-apa yang Hermes dengar.

{{langkah:ejen/hermes-agent/compose}}

`restart: unless-stopped` memulakan Hermes semula selepas ranap atau but semula. Di dalam bekas, satu penyelia
memulakan semula ejen dalam beberapa saat jika ia berhenti.

## 5. Tunggu sambungan Telegram

Permulaan pertama mengambil masa satu atau dua minit sementara Hermes menyediakan folder datanya. Arahan ini menunggu
baris log yang menyatakan ia sudah bersambung ke Telegram.

{{langkah:ejen/hermes-agent/sedia}}

## 6. Hantar mesej pertama anda

Hantar apa-apa mesej kepada bot anda dari telefon. Arahan ini menunggu sehingga Hermes menghantar jawapannya, kemudian
memaparkan baris log untuk perbualan itu. Jawapannya sampai di Telegram.

{{langkah:ejen/hermes-agent/mesej}}

## 7. Semak kunci dan token tidak bocor

Arahan ini menulis kunci dan token ke fail khas root buat seketika, mengira berapa baris dalam `docker inspect`, log bekas
dan fail dalam folder data yang mengandungi salah satu daripadanya, kemudian memadam fail itu. Ketiga-tiga kiraan mesti
sifar.

{{langkah:ejen/hermes-agent/semak-bocor}}

## 8. Semak tiada yang terbuka ke internet

Hermes bercakap dengan Telegram dan penyedia model anda melalui sambungan keluar, jadi ia tidak memerlukan port terbuka
atau alamat web. Ia mendengar pada dua port, iaitu API tempatannya dan satu port dalaman, dan kedua-duanya terikat pada
`127.0.0.1`:

{{langkah:ejen/hermes-agent/port}}

Jalankan ini di komputer anda sendiri untuk mengesahkan port API tidak boleh dicapai dari luar:

{{langkah:ejen/hermes-agent/port-luar}}

Hermes tidak memerlukan laman Caddy dari bab 5. Hermes juga ada papan pemuka web pilihan dan pelayan API yang boleh
mengawal ejen dan membaca kuncinya. Kekalkan kedua-duanya pada `127.0.0.1` dan capai melalui terowong SSH; jangan
terbitkan pada port atau di belakang alamat web awam.

## 9. Tambah Hermes ke backup harian

Menyalin pangkalan data semasa ejen menulis kepadanya boleh menghasilkan salinan rosak. `hermes backup` membuat satu fail
zip yang konsisten bagi seluruh folder data, termasuk perbualan, memori, kemahiran dan tetapan. Arahan ini menambahnya ke
skrip backup harian dari bab 6, sebelum restic berjalan, dan membackup fail zip itu serta fail Compose. Kemudian ia
menjalankan backup sekali dan menyenaraikan apa yang disimpan restic.

{{langkah:ejen/hermes-agent/backup}}

## 10. Berlatih memulihkan

Arahan ini memadam folder data, memulihkan fail zip dan fail Compose dengan restic, mengimport zip itu dengan
`hermes import` semasa ejen berhenti, dan memulakannya semula. Perbualan dari langkah 6 kembali dalam senarai sesi.
`</dev/null` menghalang bekas import sekali guna itu daripada membaca arahan yang anda tampal selepasnya.

{{langkah:ejen/hermes-agent/pulih}}

## 11. Kemas kini, dan undur bila perlu

Mengemas kini bermaksud menukar baris `image:` kepada tag dan digest yang lebih baharu, kemudian mencipta bekas semula.
Folder data anda kekal, dan Hermes memindahkan fail tetapannya ke format baharu semasa bermula, sambil menyimpan salinan
yang lama dalam `data/backups/config/`. Jalankan backup dari langkah 9 sebelum mengemas kini.

Untuk berlatih kedua-dua arah, tukar ke keluaran sebelumnya ({{ejen:hermes-agent.imej_undur.tag}}), iaitu apa yang anda
lakukan jika versi baharu bermasalah:

{{langkah:ejen/hermes-agent/undur}}

Kemudian kemas kini kembali ke versi yang diuji:

{{langkah:ejen/hermes-agent/kemas-kini}}

Hantar satu lagi mesej kepada bot anda dari telefon, kemudian semak ejen menjawab selepas kemas kini:

{{langkah:ejen/hermes-agent/mesej-selepas}}

Untuk kemas kini sebenar, baca nota keluaran di halaman keluaran projek dahulu, kemudian ambil tag baharu dan digestnya
dari halaman imej itu di Docker Hub.

## 12. Nyahpasang

Arahan ini menghentikan dan membuang bekas serta kedua-dua imej, mengeluarkan Hermes dari skrip backup, dan memadam
`/srv/hermes` bersama semua perbualan dan memori. Langkau baris `rm` jika anda mahu menyimpan data. Fail kunci dalam
`/etc/agent` dan snapshot restic kekal; buang secara berasingan jika anda tidak memerlukannya lagi.

{{langkah:ejen/hermes-agent/nyahpasang}}

---

Tersekat pada satu langkah? Sasa Teguh Academy menjalankan sesi pemasangan berpandu: https://academy.sasateguh.com
