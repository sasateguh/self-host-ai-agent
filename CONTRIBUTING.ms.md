# Menyumbang

Terima kasih kerana membantu. Panduan ini ada satu peraturan yang mengatasi yang lain: setiap arahan yang dijalankan
pembaca telah dijalankan dahulu, atas pelayan Ubuntu yang bersih, oleh alat ujian dalam repo ini, dan hasilnya disimpan
dalam `bukti/`. Perubahan pada arahan tanpa larian ujian baharu tidak diterima.

English: [CONTRIBUTING.md](CONTRIBUTING.md)

## Susunan repo

- `langkah/` menyimpan arahan, satu fail setiap bab, dipecah kepada blok bernama (`# @langkah <id>`).
- `kandungan/en/` dan `kandungan/ms/` menyimpan prosa setiap bab dalam bahasa Inggeris dan Melayu. Prosa menarik arahan
  dengan `{{langkah:<bab>/<id>}}` dan tidak pernah mengandungi blok shell yang ditaip.
- `alat/uji.py <bab>` menjalankan setiap blok satu bab dalam bekas atau mesin maya Ubuntu baharu dan menulis
  `bukti/<bab>.json`: digest imej, tarikh, cincangan arahan dan kod keluar setiap blok.
- `alat/bina.py` membina `en/` dan `ms/` daripada prosa, arahan dan `config/panduan.toml`, dan membina `README.md` serta
  `README.ms.md` daripada `kandungan/depan/`, dengan lajur "Diuji pada" dibaca dari `bukti/`. Jangan sunting `en/`, `ms/`
  atau dua fail README itu dengan tangan; `alat/bina.py --semak` gagal bila isinya berbeza daripada hasil binaan.
- `ejen/<nama>/ejen.toml` memin versi setiap ejen yang diuji: keluaran, tag imej dan digest imej.

Penyedia model dan Telegram diganti dengan pelayan tiruan tempatan semasa ujian (`uji/palsu/`). Jangan sekali-kali
meletakkan kunci atau token bot sebenar dalam ujian, fail atau komit.

## Menambah ejen

Bab ejen tidak boleh mengubah bab teras (`langkah/teras/`, `kandungan/*/teras/`). Kalau teras perlu dibaiki, hantar
pembaikan itu sebagai perubahan berasingan dahulu, dengan larian ujian baharu untuk bab yang terlibat.

1. Salin templat dalam `ejen/_templat/`:
   `ejen.toml` ke `ejen/<nama>/ejen.toml`, `langkah.sh` ke `langkah/ejen/<nama>.sh`, `en.md` ke
   `kandungan/en/ejen/<nama>.md` dan `ms.md` ke `kandungan/ms/ejen/<nama>.md`. Guna nama pendek huruf kecil dengan
   tanda sempang, sama di keempat-empat tempat.
2. Pilih keluaran stabil terbaharu dan keluaran sebelumnya. Baca dokumentasi projek itu sendiri pada tag keluaran
   tersebut, bukan cawangan utama, dan senaraikan halaman yang diikut dalam `ejen.toml`.
3. Pin kedua-dua imej dengan tag dan digest. `docker buildx imagetools inspect <imej>:<tag>` memaparkan digest. Langkah
   bina menolak sebarang rujukan imej dalam arahan yang bukan tepat salah satu daripada dua imej dalam `ejen.toml`.
4. Tulis blok. Ikut bab teras: ejen berjalan dalam Docker Compose, tidak menerbitkan port, membaca kunci model dan token
   bot daripada fail yang dibuat dalam bab 7 dan 8 (bukan dari `-e` atau imej), hanya menjawab ID sembang Telegram
   pembaca sendiri, dimasukkan ke backup bab 6, dan ada latihan pulih, undur, kemas kini dan nyahpasang yang diuji.
5. Jalankan bab: `python3 alat/uji.py ejen/<nama>`. Imej ejen besar, jadi templat meminta mesin maya dengan cakera
   lebih besar. Larian mesti lulus, dan pelayan Telegram tiruan mesti merekod jawapan ejen.
6. Tulis prosa dalam kedua-dua bahasa, kemudian jalankan `python3 alat/bina.py` dan komit arahan, prosa, `ejen.toml`,
   fail `bukti/` baharu dan fail `en/` serta `ms/` yang dibina, bersama-sama.

## Peraturan blok arahan

- Guna nilai contoh dari `config/panduan.toml` sebagaimana adanya: pengguna `ejen`, pelayan `203.0.113.10`, domain
  `example.com`. Langkah bina menolak nama lain.
- Setiap blok berjalan sebagai satu skrip `bash -c` di bawah `set -euo pipefail`. Jangan paipkan ke `head` atau
  `grep -q`: kedua-duanya keluar awal dan blok gagal dengan kod 141. Guna `sed -n` atau `grep ... >/dev/null`.
- Blok yang meminta pembaca menampal nilai (`# @tampal`) mesti membacanya dengan `read`, atau ujian gagal. Arahan yang
  membaca input standard dalam blok yang lebih panjang perlukan `</dev/null`.
- `# @mesej <teks>` mewakili mesej yang pembaca taip kepada bot dari telefon sebelum blok dijalankan.
- `# @selepas <bab>` menyenaraikan bab teras yang dijalankan dahulu dalam mesin yang sama.

## Penulisan

- Bahasa Inggeris dan Bahasa Melayu Malaysia (bukan Indonesia), ditulis untuk orang yang menjalankan pelayan pertama
  mereka. Ayat pendek, tiada kata-kata pemasaran.
- Tiada harga penyedia, pautan affiliate, permintaan bintang, angka rekaan atau testimoni.
- Setiap bab bermula dengan jawapan ringkas dua atau tiga ayat.

Kandungan berlesen CC BY 4.0 (`LICENSE-CONTENT`) dan kod berlesen MIT (`LICENSE`). Dengan menyumbang, anda bersetuju
melesenkan kerja anda dengan cara yang sama.
