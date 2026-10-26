# Pasang ejen AI sendiri di VPS

[English](README.md)

Panduan langkah demi langkah untuk menjalankan ejen AI anda sendiri, seperti Hermes Agent atau OpenClaw, di pelayan
Linux yang anda sewa dan kawal, dengan bot Telegram sebagai cara anda bercakap dengannya. Setiap arahan dalam panduan ini
dijalankan dalam mesin Ubuntu {{config:ubuntu.versi}} bersih sebelum diterbitkan, dan rekod larian itu disimpan dalam
repo ini.

**Jawapan ringkas:** sewa VPS Ubuntu {{config:ubuntu.versi}} kecil dengan sekurang-kurangnya {{config:vps.ram_gb}} GB RAM,
kunci SSH supaya hanya menerima kunci, hidupkan firewall dan kemas kini keselamatan automatik, pasang Docker, dan jalankan
ejen sebagai bekas yang hanya mendengar pada pelayan itu sendiri. Simpan kunci API model dalam fail yang hanya boleh
dibaca root, bercakap dengan ejen melalui bot Telegram, dan buat backup data dengan cara yang pernah anda pulihkan
sekurang-kurangnya sekali. Bab di bawah menerangkan setiap langkah itu mengikut urutan.

## Untuk siapa

- Anda mahu ejen AI yang berjalan sepanjang hari di pelayan anda sendiri, bukan di komputer riba.
- Anda selesa menyalin arahan ke terminal, tetapi pengurusan pelayan bukan kerja harian anda.
- Anda mahu setiap langkah diterangkan: apa ia buat, cara memastikan ia berjaya, dan cara membatalkannya.

## Bab

Baca bab dikongsi mengikut urutan, kemudian bab untuk ejen anda. Bab ejen memaut kembali ke bab dikongsi, tidak
mengulangnya. Lajur "Diuji pada" diisi daripada rekod ujian setiap bab, bukan ditaip dengan tangan.

{{kandungan}}

Versi ejen yang diuji: Hermes Agent {{ejen:hermes-agent.ejen.versi}}, OpenClaw {{ejen:openclaw.ejen.versi}}.

## Cara panduan ini diuji

Arahan disimpan dalam fail langkah di bawah `langkah/`. Alat ujian memulakan bekas Ubuntu baharu, atau mesin maya penuh
untuk bab yang menyentuh SSH, firewall atau systemd, dan menjalankan setiap blok mengikut urutan. Ia menulis rekod ke
`bukti/`: imej Ubuntu dan digestnya, tarikh, cincangan fail langkah dan kod keluar setiap blok. Bab dalam `en/` dan `ms/`
dijana daripada fail langkah yang sama, jadi arahan yang anda salin ialah arahan yang telah diuji. Bab yang fail
langkahnya berubah selepas ujian terakhir menggagalkan binaan sehingga ia diuji semula.

Ujian memakai pengganti penyedia model dan pengganti pelayan Telegram, jadi tiada kunci API atau token bot sebenar terlibat.
Semakan firewall dan SSH dibuat dari luar mesin maya, seperti yang dilihat oleh penyerang di internet.

## Apa yang tidak diliputi

- Harga atau cadangan penyedia VPS tertentu. Bab 1 menyenaraikan apa yang perlu dicari dan cara menyemaknya sendiri.
- Menjalankan ejen di komputer anda sendiri atau di platform terurus.
- Memilih penyedia model. Bab ejen menyambung ke mana-mana penyedia dengan API serasi OpenAI; dokumentasi ejen itu
  sendiri menerangkan penyedia lain.

## Sumbangan dan keselamatan

Pembaikan dan bab ejen baharu dialu-alukan: lihat [CONTRIBUTING.ms.md](CONTRIBUTING.ms.md). Jika anda menemui langkah
yang mendedahkan pelayan, sila laporkan secara peribadi seperti dalam [SECURITY.ms.md](SECURITY.ms.md). Perubahan
disenaraikan dalam [CHANGELOG.md](CHANGELOG.md).

## Lesen

Teks panduan: CC BY 4.0 ([LICENSE-CONTENT](LICENSE-CONTENT)). Skrip dan alat: MIT ([LICENSE](LICENSE)).

## Bekerja dengan Sasa Teguh

[![Bekerja dengan Sasa Teguh: tempah panggilan](https://raw.githubusercontent.com/sasateguh/.github/main/assets/work-with-sasa-teguh.png)](https://sasateguh.com/book)

Projek ini dibina dan diselenggara oleh [Sasa Teguh](https://sasateguh.com), sebuah studio di Malaysia. Kami membina laman web yang ditemui di Google dan dalam jawapan AI, dan kami memasang sistem seperti ini untuk perniagaan.

[Tempah panggilan](https://sasateguh.com/book) · hello@sasateguh.com · [Lagi dari Sasa Teguh](https://github.com/sasateguh)
