"""Format fail langkah (`langkah/**.sh`) untuk alat/uji.py dan alat/bina.py: urai blok, arahan `# @…`, prasyarat, bukti basi.

Fail langkah: `# @langkah <id>` memulakan satu blok (dijalankan dengan `bash -euo pipefail -c`, sebagai root, dalam bekas
yang sama; fail kekal antara langkah, pemboleh ubah shell tidak). `# @perlu palsu` = bab perlukan penyedia model + Telegram
palsu (`uji/palsu/`); env `[palsu.env]` dalam config diberi kepada setiap langkah.
`# @perlu vm` = tahap B: langkah dijalankan dalam VM Ubuntu sebenar (cloud image + KVM, `uji/vm/mula-vm.sh`) melalui SSH,
sebagai root (sudo). `# @langkah <id> luar` (bab vm sahaja) = dijalankan dalam bekas pelancar, iaitu "dari luar" VM: ukur
port terbuka/tertutup, log masuk ditolak. VM memakai alamat `[contoh] ip_vps` pada pautan itu.
`# @perlu vm ca` = rangkaian ujian turut meniru DNS + Let's Encrypt (Pebble, `uji/vm/ca-palsu.sh`): nama contoh menghala
ke VM dan pengeluar sijil ACME lalai dijawab oleh CA ujian, jadi arahan HTTPS dijalankan tanpa diubah.
`# @perlu vm besar` = VM dengan cakera `[vm.besar]` (bab yang menarik imej ejen bersaiz GB): fail VM dalam volume docker
tanpa nama (atas cakera, bukan ingatan), dibuang bersama bekas pelancar (`docker rm -fv`).
`# @selepas <bab> [<bab>…]` = langkah bab-bab itu dijalankan dahulu dalam mesin yang sama (pelayan yang sudah melalui bab
sebelumnya); cincangan fail mereka direkod dalam bukti, jadi mengubah bab prasyarat menjadikan bukti ini basi juga.
`# @tampal <kunci>` dalam satu blok = baris terakhir blok itu meminta pembaca MENAMPAL nilai (token, kunci model); alat
ujian menghantar nilai seterusnya dari `[palsu.tampal] <kunci>` sebagai stdin blok. Input yang masih tersisa selepas kod
blok = langkah gagal (kod 97, `uji.balut_tampal`), jadi langkah yang tidak benar-benar membaca input tidak lulus.
`# @mesej <teks>` dalam satu blok (bab palsu) = sebelum blok itu dijalankan, Telegram palsu menerima `<teks>` daripada
pembaca, seperti pembaca menaip mesej kepada bot dari telefon. Blok itu menunggu jawapan ejen.
"""
from __future__ import annotations

import hashlib
import re
from pathlib import Path

RE_LANGKAH = re.compile(r"^# @langkah ([a-z0-9][a-z0-9-]*)(?: (luar))?\s*$")
KEPERLUAN = {"palsu", "vm", "ca", "besar"}
RE_PERLU = re.compile(r"^# @perlu ([a-z0-9 ]+)$")
RE_SELEPAS = re.compile(r"^# @selepas ([a-z0-9/ -]+)$")
RE_TAMPAL = re.compile(r"^# @tampal ([a-z0-9_]+)$")
RE_MESEJ = re.compile(r"^# @mesej (\S.*)$")
# Langkah dijalankan dengan `pipefail`: pembaca paip yang berhenti awal (`head`, `grep -q`/`-m`) membunuh penulis dengan
# SIGPIPE, dan langkah gagal dengan kod 141 bila output lebih panjang daripada satu tulisan (diukur: bab teras/06
# `list-timers | head`, D11).
RE_PAIP_AWAL = re.compile(r"\|\s*(?:sudo\s+)?(?:head\b|grep(?:\s+-\S+)*?\s+(?:-\w*[qm]\w*|--quiet|--max-count)\b)")


class RalatGuna(Exception):
    pass



def urai(teks: str) -> tuple[set[str], list[tuple[str, str, str]], list[str]]:
    """Fail langkah -> (keperluan, [(id, kod, tempat)], [bab prasyarat]); tempat "" = mesin ujian, "luar" = pelancar VM.
    Kod di luar blok langkah = ralat (ia tidak akan pernah dijalankan)."""
    perlu: set[str] = set()
    selepas: list[str] = []
    mesej = False
    langkah: list[tuple[str, list[str], str]] = []
    for n, baris in enumerate(teks.splitlines(), 1):
        if m := RE_LANGKAH.match(baris):
            if any(i == m[1] for i, _, _ in langkah):
                raise RalatGuna(f"baris {n}: id langkah berulang '{m[1]}'")
            langkah.append((m[1], [], m[2] or ""))
        elif m := RE_PERLU.match(baris):
            perlu.update(m[1].split())
        elif m := RE_SELEPAS.match(baris):
            selepas.extend(m[1].split())
        elif (RE_TAMPAL.match(baris) or RE_MESEJ.match(baris)) and langkah:
            mesej |= bool(RE_MESEJ.match(baris))   # arahan_blok(): bukan sebahagian kod yang dipapar
        elif baris.startswith("# @"):
            raise RalatGuna(f"baris {n}: arahan tidak dikenali: {baris}")
        elif langkah:
            if RE_PAIP_AWAL.search(baris):
                raise RalatGuna(f"baris {n}: paip ke head/grep -q/-m = SIGPIPE 141 di bawah pipefail; guna sed -n / grep >/dev/null")
            langkah[-1][1].append(baris)
        elif baris.strip() and not baris.startswith("#"):
            raise RalatGuna(f"baris {n}: kod sebelum '# @langkah' pertama")
    if not langkah:
        raise RalatGuna("tiada '# @langkah'")
    if perlu - KEPERLUAN:
        raise RalatGuna(f"keperluan tidak dikenali: {sorted(perlu - KEPERLUAN)}")
    if "vm" not in perlu and any(t for _, _, t in langkah):
        raise RalatGuna("langkah 'luar' hanya untuk bab '# @perlu vm'")
    if {"ca", "besar"} & perlu and "vm" not in perlu:
        raise RalatGuna("'ca' dan 'besar' hanya untuk bab '# @perlu vm'")
    if mesej and "palsu" not in perlu:
        raise RalatGuna("'# @mesej' hanya untuk bab '# @perlu palsu'")
    if len(set(selepas)) != len(selepas):
        raise RalatGuna("bab '# @selepas' berulang")
    return perlu, [(i, "\n".join(k).strip() + "\n", t) for i, k, t in langkah], selepas


def arahan_blok(teks: str, corak: re.Pattern = RE_TAMPAL) -> dict[str, list[str]]:
    """Fail langkah -> {id langkah: [nilai arahan `corak`, ikut urutan]}: `# @tampal <kunci>` atau `# @mesej <teks>`."""
    hasil: dict[str, list[str]] = {}
    semasa = None
    for baris in teks.splitlines():
        if m := RE_LANGKAH.match(baris):
            semasa = m[1]
        elif (m := corak.match(baris)) and semasa:
            hasil.setdefault(semasa, []).append(m[1])
    return hasil


def tampalan(teks: str) -> dict[str, list[str]]:
    """{id langkah: [kunci [palsu.tampal]]} untuk blok yang ada `# @tampal`."""
    return arahan_blok(teks, RE_TAMPAL)


class Tampal:
    """Nilai `[palsu.tampal]` diberi ikut urutan sepanjang satu larian (prasyarat dahulu), seperti pembaca menampal."""

    def __init__(self, cfg: dict):
        self.nilai = {k: list(v) for k, v in cfg.get("palsu", {}).get("tampal", {}).items()}

    def input(self, kunci: list[str]) -> str:
        keluar = []
        for k in kunci:
            if not self.nilai.get(k):
                raise RalatGuna(f"[palsu.tampal] {k}: tiada nilai lagi untuk ditampal")
            keluar.append(self.nilai[k].pop(0) + "\n")
        return "".join(keluar)


def prasyarat(akar: Path, bab: str, perlu: set[str], selepas: list[str]) -> list[tuple[str, Path, list]]:
    """Bab '# @selepas' -> [(bab, fail, langkah)]. Prasyarat mesti wujud, tidak memerlukan lebih daripada bab ini (langkahnya
    dijalankan dalam mesin bab ini), dan prasyaratnya sendiri mesti sudah disenaraikan LEBIH AWAL (tiada larian bersarang)."""
    hasil = []
    for i, p in enumerate(selepas):
        fail = akar / "langkah" / f"{p}.sh"
        if p == bab or not fail.is_file():
            raise RalatGuna(f"prasyarat '{p}' tiada fail langkah (atau bab itu sendiri)")
        pp, langkah, ps = urai(fail.read_text(encoding="utf-8"))
        if set(ps) - set(selepas[:i]):
            raise RalatGuna(f"prasyarat '{p}' memerlukan {sorted(set(ps) - set(selepas[:i]))}; senaraikan bab itu lebih awal")
        if pp - perlu:
            raise RalatGuna(f"prasyarat '{p}' memerlukan {sorted(pp - perlu)} yang tiada dalam bab ini")
        hasil.append((p, fail, langkah))
    return hasil


def basi(akar: Path, bab: str, b: dict) -> list[str]:
    """Cincangan bab + setiap prasyaratnya dalam bukti `b` mesti sama dengan fail semasa."""
    fail, masalah = akar / "langkah" / f"{bab}.sh", []
    if b.get("sha256") != sha256(fail):
        masalah.append("fail langkah berubah selepas ujian")
    selepas = urai(fail.read_text(encoding="utf-8"))[2]
    direkod = [x.get("bab") for x in b.get("prasyarat", [])]
    if direkod != selepas:
        masalah.append(f"prasyarat dalam bukti {direkod} != '# @selepas' {selepas}")
    for x in b.get("prasyarat", []):
        fp = akar / "langkah" / f"{x.get('bab')}.sh"
        if not fp.is_file() or x.get("sha256") != sha256(fp):
            masalah.append(f"prasyarat '{x.get('bab')}' berubah selepas ujian")
    return masalah


def sha256(fail: Path) -> str:
    return hashlib.sha256(fail.read_bytes()).hexdigest()
