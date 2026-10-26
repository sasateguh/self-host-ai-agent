# 5. Nama domain dan HTTPS

**Jawapan ringkas:** halakan nama seperti `{{config:contoh.subdomain_ejen}}` ke pelayan anda dengan rekod DNS `A`, buka
port {{config:port.http}} dan {{config:port.https}}, dan letakkan Caddy di hadapan ejen. Caddy mendapatkan sijil Let's
Encrypt percuma sendiri, memperbaharuinya sebelum tamat tempoh, dan meneruskan permintaan kepada ejen di
`127.0.0.1:{{config:port.ejen_dalaman}}`, yang kekal tertutup kepada internet.

Diuji pada: {{diuji:teras/05-domain-https}}.

Cara bab ini diuji: `{{config:contoh.domain}}` ialah nama simpanan yang tiada siapa boleh dapatkan sijil untuknya, jadi
rangkaian ujian memainkan peranan internet. Ia menghalakan `{{config:contoh.subdomain_ejen}}` ke pelayan ujian, dan
menjawab alamat Let's Encrypt dengan Pebble, pihak berkuasa sijil ujian yang diterbitkan oleh Let's Encrypt. Pebble
menyemak pelayan dari luar sebelum mengeluarkan apa-apa, sama seperti Let's Encrypt. Arahan di halaman ini dijalankan
tepat seperti ditulis; pelayan anda berhubung dengan Let's Encrypt yang sebenar.

Jalankan langkah ini sebagai pengguna dari bab 2, pada pelayan yang sudah ada firewall dari bab 3. Gantikan
`{{config:contoh.subdomain_ejen}}`, `{{config:contoh.emel_sijil}}` dan `{{config:contoh.ip_vps}}` dengan nama, alamat
emel dan alamat pelayan anda sendiri.

## 1. Halakan nama ke pelayan anda

Di syarikat tempat anda membeli domain (atau di mana sahaja DNSnya dihoskan), tambah satu rekod:

| Jenis | Nama | Nilai |
|---|---|---|
| `A` | `agent` | `{{config:contoh.ip_vps}}` |

Jika pelayan anda juga ada alamat IPv6, tambah rekod `AAAA` dengannya, atau jangan letak IPv6 langsung: rekod `AAAA`
yang salah menggagalkan sijil. Perubahan boleh mengambil beberapa minit untuk tersebar. Semak dari komputer anda; baris
pertama sepatutnya menunjukkan alamat pelayan anda:

{{langkah:teras/05-domain-https/dns}}

Sesetengah penyedia menyekat balasan ping. Itu tidak mengapa selagi alamatnya betul.

## 2. Mulakan pengganti ejen

Ejen dipasang dalam bab kemudian. Sehingga itu, pelayan web kecil ini memainkan peranannya di
`127.0.0.1:{{config:port.ejen_dalaman}}`.

{{langkah:teras/05-domain-https/ejen-cuba}}

## 3. Pasang Caddy

Ini arahan dari halaman pemasangan Caddy untuk Ubuntu. Ia menambah repositori pakej Caddy, jadi `apt` mengemas kininya
bersama sistem yang lain.

{{langkah:teras/05-domain-https/pasang-caddy}}

## 4. Buka port {{config:port.http}} dan {{config:port.https}}

Let's Encrypt menyemak bahawa anda mengawal nama itu dengan menyambung ke pelayan anda pada port ini, dan pelawat juga
memakainya.

{{langkah:teras/05-domain-https/firewall}}

## 5. Beritahu Caddy nama anda

Seluruh konfigurasi hanya beberapa baris. Alamat emel ialah tempat Let's Encrypt menulis jika ada masalah dengan sijil
anda.

{{langkah:teras/05-domain-https/caddyfile}}

## 6. Tunggu sijil

Caddy meminta sijil sebaik sahaja ia dimuat semula. Biasanya ini mengambil beberapa saat.

{{langkah:teras/05-domain-https/sijil}}

Jika sijil tidak tiba, `sudo journalctl -u caddy --no-pager | tail -n 30` menunjukkan sebabnya. Punca biasa ialah rekod
DNS yang menghala ke tempat lain, atau port {{config:port.http}} dan {{config:port.https}} masih tertutup (semak `ufw`
dan juga firewall dalam panel kawalan penyedia anda).

## 7. Semak dari komputer anda

Halaman tiba melalui HTTPS dengan sijil yang sah, dan HTTP biasa dialihkan ke HTTPS.

{{langkah:teras/05-domain-https/https}}

Port ejen sendiri kekal tertutup. Hanya Caddy, di pelayan yang sama, boleh mencapainya:

{{langkah:teras/05-domain-https/port-dalaman}}

## 8. Hentikan pengganti

{{langkah:teras/05-domain-https/henti-ejen-cuba}}

Sehingga ejen dipasang, alamat itu menjawab dengan halaman ralat (HTTP 502). Bab ejen memberitahu Caddy port yang ejen
pakai, jika berbeza daripada {{config:port.ejen_dalaman}}. Caddy memperbaharui sijil sendiri jauh sebelum tamat
tempoh; tiada apa-apa yang perlu dijadualkan.
