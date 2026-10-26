# OpenClaw di pelayan anda

**Jawapan ringkas:** jalankan imej Docker rasmi OpenClaw, dipin pada satu versi yang diuji, dengan Docker Compose.
OpenClaw membaca kunci API model, token bot Telegram dan token gateway miliknya daripada fail (bab 7 dan 8), bercakap
dengan penyedia model serasi OpenAI, dan hanya menjawab akaun Telegram anda sendiri. Backup dengan arahan backup
miliknya sendiri serta restic, dan kemas kini dengan menukar satu baris.

Diuji pada: {{diuji:ejen/openclaw}}, dengan OpenClaw {{ejen:openclaw.ejen.versi}} (dikeluarkan
{{ejen:openclaw.ejen.tarikh_keluaran}}).

OpenClaw ialah pembantu AI peribadi sumber terbuka (lesen {{ejen:openclaw.ejen.lesen}}, kod sumber di
{{ejen:openclaw.ejen.repo}}, dokumentasi di {{ejen:openclaw.ejen.dokumen}}). Satu proses yang sentiasa berjalan,
dipanggil gateway, menyambungkannya kepada aplikasi sembang seperti Telegram dan kepada penyedia model anda. Bab ini
mengikut dokumentasi Docker, Telegram, penyedia, kunci dan backup projek itu sendiri untuk versi di atas.

Jalankan langkah ini sebagai pengguna dari bab 2, atas pelayan yang sudah melalui bab 3 (firewall), 4 (Docker),
6 (backup), 7 (bot Telegram) dan 8 (kunci API model). Larian ujian memakai penyedia model tiruan dan API Telegram
tiruan, kunci rekaan, dan mesej ujian sebagai ganti mesej yang ditaip di telefon.

Sediakan pelayan dengan sekurang-kurangnya 4 GB memori. Dalam ujian, bekas OpenClaw memakai lebih kurang 2 GB selepas
jawapan pertamanya, dan pada mesin ujian yang hanya ada 2 GB, setiap arahan mengambil masa beberapa minit.

## 1. Muat turun keluaran sebelumnya dahulu

Nama imej berakhir dengan tag dan digest (`sha256:...`). Tag ialah nama versi; digest ialah cap jari imej tepat yang
diuji, jadi Docker menolak imej lain, walaupun seseorang mengalihkan tag itu kemudian. Imej datang dari GitHub Container
Registry, yang projek ini guna untuk keluarannya. Saiz muat turun setiap satu lebih kurang 700 MB.

Bab ini bermula dengan keluaran sebelum versi yang diuji, {{ejen:openclaw.imej_undur.tag}}, supaya langkah 11 ialah
kemas kini sebenar ke {{ejen:openclaw.imej.tag}} dan undur sebenar. Anda berakhir pada {{ejen:openclaw.imej.tag}}. Kalau
anda mahu bermula terus dengan versi yang diuji, guna tag dan digestnya dari langkah 11 dalam langkah 1 dan 4.

{{langkah:ejen/openclaw/tarik}}

## 2. Tulis fail tetapan

OpenClaw menyimpan tetapan, perbualan dan ingatannya dalam satu folder keadaan, di sini `/srv/openclaw/data`. Bekas
berjalan sebagai pengguna dengan ID 1000, jadi folder itu milik ID tersebut. Folder kedua, `/srv/openclaw/backups`, akan
menyimpan arkib backup (langkah 9).

Baris pertama mencipta token gateway: kata laluan rawak yang melindungi antara muka kawalan gateway, disimpan bersama
kunci dari bab 8 dan hanya boleh dibaca oleh root.

Fail tetapan kemudian menyatakan:

- `gateway`: dengar pada `127.0.0.1` sahaja, dan wajibkan token gateway.
- `secrets.providers`: dua fail yang setiap satunya memegang satu nilai, iaitu kunci model dan token gateway. Fail
  tetapan menunjuk kepada fail itu dan tidak pernah mengandungi nilainya.
- `models`: penyedia serasi OpenAI di `OPENAI_BASE_URL` (alamat sama seperti bab 8; tetapkan dahulu kalau penyedia anda
  memberi alamat), dengan kunci daripada fail.
- `channels.telegram`: baca token bot daripada fail, dan dengan `dmPolicy: "allowlist"` jawab ID sembang yang disimpan
  dalam bab 7 sahaja. Orang lain yang menjumpai bot itu tidak mendapat apa-apa.

Secara lalai OpenClaw enggan menyambung ke alamat dalam rangkaian peribadi, sebagai benteng supaya permintaan tidak
dilencongkan ke mesin anda sendiri. Dua semakan `if` hanya melonggarkannya bila anda memakai alamat sebegitu: alamat
model yang bermula dengan `http://` (contohnya pelayan model dalam rangkaian anda sendiri) atau alamat Telegram yang
bukan milik Telegram (pelayan Bot API tempatan). Dengan penyedia dan Telegram biasa, kedua-duanya tidak menambah
apa-apa.

{{langkah:ejen/openclaw/config}}

## 3. Pilih model

Arahan ini menyenaraikan model yang boleh dipakai dengan kunci anda, kemudian menunggu anda menaip satu nama dan menekan
Enter.

{{langkah:ejen/openclaw/model}}

## 4. Mulakan OpenClaw dengan Docker Compose

Fail Compose memberi bekas itu fail dari bab 7 dan 8 serta token gateway di bawah `/run/secrets/`. Salinan itu milik
root, sama seperti fail asal, dan OpenClaw berjalan sebagai pengguna biasa, jadi bekas bermula sebagai root seketika:
baris `entrypoint` menyalin tiga nilai itu ke folder dalam ingatan sahaja (`tmpfs`) yang hanya boleh dibaca oleh
pengguna OpenClaw, memastikan folder keadaan dan folder backup milik pengguna itu, kemudian bertukar kepadanya dengan
`setpriv` dan memulakan imej seperti biasa. Semakan kesihatan imej juga berjalan melalui `setpriv`, jadi tiada apa dalam
folder keadaan pernah dicipta oleh root. Atas sebab yang sama, setiap `docker exec` dalam bab ini memakai `-u node`.
Tiada apa yang ditulis ke cakera, dan nilainya tidak pernah muncul dalam `docker inspect` (bab 8 menunjukkan sebab ia
penting).

`network_mode: host` dengan gateway terikat pada `127.0.0.1` bermakna tiada port diterbitkan, jadi Docker tidak menambah
peraturan firewall sendiri (bab 4). `cap_drop` dan `no-new-privileges` diambil dari fail Compose projek itu sendiri.

{{langkah:ejen/openclaw/compose}}

`restart: unless-stopped` memulakan semula OpenClaw selepas ranap atau but semula.

## 5. Tunggu sambungan Telegram

Permulaan pertama mengambil masa satu atau dua minit: OpenClaw menyemak dan menyediakan folder keadaannya sebelum
gateway dibuka. Arahan ini menunggu semakan kesediaan gateway, kemudian baris log yang menyatakan sambungan Telegram
sudah bermula. Kalau gateway belum sedia selepas lima minit, ia memaparkan status bekas dan baris log terakhir tanpa
hiasannya, yang biasanya menamakan masalah itu.

{{langkah:ejen/openclaw/sedia}}

## 6. Hantar mesej pertama

Hantar apa-apa mesej kepada bot anda dari telefon. Arahan ini menunggu baris log yang menyatakan OpenClaw sudah menghantar
jawapannya, kemudian memaparkan baris untuk mesej masuk anda. Jawapan sampai dalam Telegram.

OpenClaw juga menjalankan semakan latar berkala dan mungkin menghantar nota pendek pertama tentangnya; nota itu
menyebut tetapan yang mematikannya. Larian ujian juga menerima nota itu.

{{langkah:ejen/openclaw/mesej}}

## 7. Pastikan kunci dan token tidak bocor

Arahan ini menulis kunci model, token bot dan token gateway ke fail yang hanya boleh dibaca root buat seketika, mengira
berapa baris `docker inspect`, log bekas dan fail dalam folder keadaan yang mengandungi mana-mana nilai itu, kemudian
memadam fail tersebut. Ketiga-tiga kiraan mesti sifar.

{{langkah:ejen/openclaw/semak-bocor}}

## 8. Pastikan tiada apa-apa terbuka ke internet

OpenClaw bercakap dengan Telegram dan penyedia model anda melalui sambungan keluar, jadi ia tidak perlukan port terbuka
atau alamat web. Gateway mendengar pada port 18789, terikat pada `127.0.0.1`:

{{langkah:ejen/openclaw/port}}

Jalankan ini di komputer anda sendiri untuk memastikan port itu tidak boleh dicapai dari luar:

{{langkah:ejen/openclaw/port-luar}}

Anda tidak perlukan laman Caddy dari bab 5 untuk OpenClaw. Gateway juga menyediakan panel kawalan web yang boleh menukar
tetapan dan menjalankan arahan. Kekalkan ia pada `127.0.0.1` dan capai melalui terowong SSH dengan token gateway; jangan
terbitkannya pada port atau di belakang alamat web awam.

## 9. Masukkan OpenClaw ke backup harian

Menyalin pangkalan data semasa ejen menulis kepadanya boleh menghasilkan salinan rosak. `openclaw backup create`
membuat arkib folder keadaan yang konsisten, menyemaknya dengan `--verify`, dan tidak menulis nilai kunci ke dalamnya.
Arahan ini menambahnya ke skrip backup harian dari bab 6, sebelum restic berjalan: ia memadam arkib semalam, menulis
yang baharu, dan restic menyimpan arkib serta fail Compose. Kemudian ia menjalankan backup sekali dan menyenaraikan apa
yang disimpan restic.

{{langkah:ejen/openclaw/backup}}

Kalau ejen lain dari panduan ini sudah mengubah baris `restic backup`, tambah dua baris itu dengan tangan.

## 10. Latih pemulihan

Arahan ini menulis skrip pemulihan kecil, `/usr/local/sbin/restore-openclaw`, dan menjalankannya. Skrip itu
menghentikan OpenClaw, memadam folder keadaan, arkib dan fail Compose, mendapatkan semula arkib dan fail Compose dari
restic, dan membuka arkib dengan `openclaw backup restore` ke dalam folder kosong. OpenClaw tidak pernah memulihkan di
atas data yang sedang hidup, jadi skrip itu kemudian menyalin folder keadaan yang dipulihkan ke tempatnya. Sebelum
gateway dimulakan semula, bekas sekali guna menyenaraikan perbualan dalam folder yang dipulihkan: perbualan dari
langkah 6 kembali. `</dev/null` menghalang bekas sekali guna daripada membaca arahan yang anda tampal selepasnya.

{{langkah:ejen/openclaw/pulih}}

Simpan skrip itu: ia juga cara untuk undur selepas kemas kini yang bermasalah (langkah 11).

## 11. Kemas kini, dan undur bila perlu

Kemas kini bermakna menukar baris `image:` kepada tag dan digest yang lebih baharu, kemudian mencipta semula bekas.
Setiap kali bermula, imej menyemak folder keadaan dan memindahkannya ke format versi baharu bila perlu. Versi yang sudah
memindahkan keadaan tidak boleh ditukar begitu sahaja dengan versi lama: dalam ujian, {{ejen:openclaw.imej_undur.tag}}
tidak pernah membuka gateway atas keadaan yang ditulis oleh {{ejen:openclaw.imej.tag}}, seperti amaran dokumentasi undur
OpenClaw sendiri. Jadi undur bermakna imej lama bersama backup yang dibuat sebelum kemas kini.

Oleh itu setiap kemas kini bermula dengan backup dari langkah 9. Arahan ini menjalankannya, kemudian mengemas kini ke
{{ejen:openclaw.imej.tag}}:

{{langkah:ejen/openclaw/kemas-kini}}

Kalau versi baharu bermasalah, jalankan skrip pemulihan. Snapshot restic terkini ialah yang dibuat sejurus sebelum kemas
kini, jadi ia membawa balik fail Compose lama (dengan baris `image:` lama) dan keadaan lama:

{{langkah:ejen/openclaw/undur}}

Kemudian kemas kini semula dengan cara yang sama:

{{langkah:ejen/openclaw/kemas-kini-semula}}

Hantar satu lagi mesej kepada bot anda dari telefon, kemudian pastikan ejen menjawab selepas kemas kini:

{{langkah:ejen/openclaw/mesej-selepas}}

Untuk kemas kini sebenar, baca nota keluaran di halaman keluaran projek dahulu, kemudian ambil tag baharu dan digestnya
dari halaman imej di GitHub Container Registry.

## 12. Nyahpasang

Arahan ini menghentikan dan membuang bekas serta kedua-dua imej, mengeluarkan OpenClaw dari skrip backup, dan memadam
`/srv/openclaw` bersama semua perbualan dan ingatan, token gateway dan skrip pemulihan. Langkau baris `rm` kalau anda mahu menyimpan
data. Fail kunci dari bab 7 dan 8 serta snapshot restic kekal; buang secara berasingan kalau tidak diperlukan lagi.

{{langkah:ejen/openclaw/nyahpasang}}

---

Tersekat pada satu langkah? Sasa Teguh Academy menjalankan sesi pemasangan berpandu: https://academy.sasateguh.com
