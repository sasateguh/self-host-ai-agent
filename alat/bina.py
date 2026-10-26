#!/usr/bin/env python3
"""Penjana bab (PRD K1, K2): templat prosa `kandungan/<bahasa>/**.md` + fail langkah + config -> `<bahasa>/**.md`.

Arahan tidak pernah ditaip dalam prosa. Templat memanggil:
    {{langkah:<bab>/<id>}}   blok `bash` = kod blok `# @langkah <id>` dalam langkah/<bab>.sh, bait demi bait
    {{config:<kunci>}}       nilai dari config/panduan.toml (kunci bertitik, cth contoh.domain)
    {{diuji:<bab>}}          imej Ubuntu + tarikh dari bukti/<bab>.json ("diuji pada", tidak ditaip)
    {{ejen:<nama>.<kunci>}}  nilai dari ejen/<nama>/ejen.toml (versi dipin, PRD K10, K12)
    {{kandungan}}            jadual kandungan bahasa itu (hanya dalam fail indeks, config [bina] indeks); dalam halaman
                             depan = jadual bab + "diuji pada" setiap bab dari bukti (config [bina] depan, [bina.label])

    python3 alat/bina.py            jana semula <bahasa>/ (fail yang tidak dijana lagi dibuang)
    python3 alat/bina.py --semak    gerbang: hasil jana == fail dijejak, tiada arahan tulisan tangan, bukti terkini

Ditolak (kedua-dua mod): blok kod shell atau blok tanpa label dalam templat; blok shell dalam hasil yang tidak sama dengan
mana-mana langkah; langkah/kunci/pemegang tempat tidak wujud; bab yang dirujuk tanpa bukti lulus atau dengan bukti basi
(cincangan fail langkah lain daripada bukti); nilai contoh dalam fail langkah (alamat IPv4, pengguna `ssh x@`, `adduser`)
yang tidak sama dengan config [contoh] atau senarai benar [bina] (prosa memakai {{config:...}}, kod memakai literal); rujukan
imej ejen dalam langkah/ejen/<nama>.sh yang bukan `nama:tag@digest` [imej] atau [imej_undur] ejen.toml. Kod keluar: 0 lulus · 1 ada masalah.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import re
import sys
import tomllib
from pathlib import Path

AKAR = Path(__file__).resolve().parent.parent
RE_PEMEGANG = re.compile(r"\{\{\s*([a-z]+)(?::([^}\s]+))?\s*\}\}")
RE_BAB = re.compile(r"^[a-z0-9][a-z0-9-]*(/[a-z0-9][a-z0-9-]*)*$")
RE_IP = re.compile(r"(?<![\d.])(\d{1,3}(?:\.\d{1,3}){3})(?![\d.])")
RE_DOMAIN = re.compile(r"(?<![\w.@-])((?:[a-z0-9-]+\.)*example\.(?:com|net|org))\b")
RE_EMEL = re.compile(r"\b([a-z0-9._-]+@(?:[a-z0-9-]+\.)*example\.(?:com|net|org))\b")
RE_PENGGUNA = [re.compile(r"\b([a-z_][a-z0-9_-]*)@\d{1,3}(?:\.\d{1,3}){3}\b"), re.compile(r"\badduser\b.*\s([a-z_][a-z0-9_-]*)\s*$", re.M)]


def _muat_uji():
    spec = importlib.util.spec_from_file_location("uji_bab", Path(__file__).resolve().parent / "uji.py")
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


uji = _muat_uji()


class Penjana:
    def __init__(self, akar: Path = AKAR):
        self.akar = akar
        self.cfg = uji.muat_config(akar)
        self.b = self.cfg["bina"]
        self.shell = set(self.b["bahasa_shell"])
        self.masalah: list[str] = []
        self._langkah: dict[str, dict[str, str] | None] = {}

    # ---- sumber -------------------------------------------------------------------------------------------------
    def langkah_bab(self, bab: str, asal: str) -> dict[str, str] | None:
        """{id: kod} bab itu, selepas bukti disahkan terkini dan lulus; None (dengan masalah direkod) bila tidak."""
        if bab in self._langkah:
            return self._langkah[bab]
        hasil = None
        fail, fb = self.akar / "langkah" / f"{bab}.sh", self.akar / "bukti" / f"{bab}.json"
        if not RE_BAB.match(bab) or not fail.is_file():
            self.masalah.append(f"{asal}: bab '{bab}' tiada fail langkah")
        else:
            try:
                kod = {i: k for i, k, _ in uji.urai(fail.read_text(encoding="utf-8"))[1]}
                b = json.loads(fb.read_text(encoding="utf-8")) if fb.is_file() else None
                if b is None:
                    self.masalah.append(f"{asal}: bab '{bab}' tiada bukti (jalankan alat/uji.py {bab})")
                elif lama := uji.basi(self.akar, bab, b):
                    self.masalah.append(f"{asal}: bukti '{bab}' basi ({'; '.join(lama)})")
                elif not b.get("lulus") or any(x.get("kod") != 0 for x in b.get("langkah", [])):
                    self.masalah.append(f"{asal}: bukti '{bab}' tidak lulus")
                else:
                    hasil = kod
            except uji.RalatGuna as e:
                self.masalah.append(f"{asal}: fail langkah '{bab}' rosak: {e}")
        self._langkah[bab] = hasil
        return hasil

    def semua_kod_langkah(self) -> set[str]:
        d = self.akar / "langkah"
        kod: set[str] = set()
        for f in sorted(d.rglob("*.sh")) if d.is_dir() else []:
            try:
                kod |= {k for _, k, _ in uji.urai(f.read_text(encoding="utf-8"))[1]}
            except uji.RalatGuna:
                pass   # dilaporkan oleh uji.py --semak dan oleh rujukan bab
        return kod

    def semak_contoh(self) -> None:
        """Literal contoh dalam fail langkah mesti sama dengan config: prosa di sebelahnya dijana dari config, jadi nilai
        berbeza = bab yang bercanggah dengan dirinya (cth pengguna `ejen` dalam arahan, nama lain dalam prosa)."""
        c, d = self.cfg["contoh"], self.akar / "langkah"
        ip = {c["ip_vps"], *self.b.get("ip_benar", [])}
        pengguna = {c["pengguna"], *self.b.get("pengguna_benar", [])}
        for f in sorted(d.rglob("*.sh")) if d.is_dir() else []:
            rel, teks = f.relative_to(self.akar).as_posix(), f.read_text(encoding="utf-8")
            for x in sorted({m[1] for m in RE_IP.finditer(teks)} - ip):
                self.masalah.append(f"{rel}: alamat {x} bukan config contoh.ip_vps (atau [bina] ip_benar)")
            for x in sorted({m[1] for r in RE_PENGGUNA for m in r.finditer(teks)} - pengguna):
                self.masalah.append(f"{rel}: pengguna '{x}' bukan config contoh.pengguna (atau [bina] pengguna_benar)")
            for x in sorted({m[1] for m in RE_DOMAIN.finditer(teks)} - {c["domain"], c["subdomain_ejen"]}):
                self.masalah.append(f"{rel}: nama {x} bukan config contoh.domain / contoh.subdomain_ejen")
            for x in sorted({m[1] for m in RE_EMEL.finditer(teks)} - {c["emel_sijil"]}):
                self.masalah.append(f"{rel}: emel {x} bukan config contoh.emel_sijil")

    def ejen(self) -> dict[str, dict]:
        """{nama: isi ejen/<nama>/ejen.toml} untuk setiap ejen. Folder bermula `_` (ejen/_templat/) bukan ejen."""
        d = self.akar / "ejen"
        return {f.parent.name: tomllib.loads(f.read_text(encoding="utf-8"))
                for f in sorted(d.glob("*/ejen.toml")) if not f.parent.name.startswith("_")} if d.is_dir() else {}

    def semak_ejen(self) -> None:
        """Imej ejen dalam fail langkah = versi dipin ejen.toml (tag + digest), supaya prosa {{ejen:...}} dan arahan sepadan."""
        for nama, e in self.ejen().items():
            rel = f"langkah/ejen/{nama}.sh"
            if not (self.akar / rel).is_file():
                self.masalah.append(f"ejen/{nama}/ejen.toml: fail langkah {rel} tiada")
                continue
            teks = (self.akar / rel).read_text(encoding="utf-8")
            pin = {f"{i['nama']}:{i['tag']}@{i['digest']}" for k in ("imej", "imej_undur") if (i := e.get(k))}
            # Nama sahaja (cth `docker image ls <nama>`) dibenarkan; dengan tag atau digest = mesti tepat versi dipin.
            dipakai = set(re.findall(re.escape(e["imej"]["nama"]) + r"(?::[\w.-]+)?(?:@sha256:[0-9a-f]+)?", teks)) - {e["imej"]["nama"]}
            for x in sorted(dipakai - pin):
                self.masalah.append(f"{rel}: imej {x} bukan [imej]/[imej_undur] ejen/{nama}/ejen.toml (tag@digest)")
            if f"{e['imej']['nama']}:{e['imej']['tag']}@{e['imej']['digest']}" not in dipakai:
                self.masalah.append(f"{rel}: imej dipin ejen/{nama}/ejen.toml [imej] tidak dipakai")

    def nilai_ejen(self, arg: str, asal: str) -> str | None:
        nama, _, kunci = arg.partition(".")
        e = self.ejen()
        if nama not in e:
            self.masalah.append(f"{asal}: ejen '{nama}' tiada (ejen/{nama}/ejen.toml)")
            return None
        return self.nilai_config(kunci, asal, e[nama], f"ejen/{nama}/ejen.toml")

    def nilai_config(self, kunci: str, asal: str, sumber: dict | None = None, label: str = "config") -> str | None:
        v: object = self.cfg if sumber is None else sumber
        for k in kunci.split("."):
            if not isinstance(v, dict) or k not in v:
                self.masalah.append(f"{asal}: kunci {label} '{kunci}' tiada")
                return None
            v = v[k]
        if isinstance(v, (dict, list)):
            self.masalah.append(f"{asal}: kunci {label} '{kunci}' bukan nilai tunggal")
            return None
        return str(v).lower() if isinstance(v, bool) else str(v)

    def diuji(self, bab: str, asal: str) -> str | None:
        if self.langkah_bab(bab, asal) is None:
            return None
        b = json.loads((self.akar / "bukti" / f"{bab}.json").read_text(encoding="utf-8"))
        vm = " (VM)" if b.get("tahap") == "B" else ""
        return f"`{b['imej']}`{vm}, {b['tarikh_utc'][:10]}"

    def jadual_depan(self, bhs: str, bab: list[str], tajuk: dict[str, str], asal: str) -> str:
        """Jadual bab halaman depan: pautan ke <bahasa>/<bab>.md + "diuji pada" + bilangan langkah lulus, semua dari bukti
        (tidak ditaip). Bab tanpa bukti lulus dan terkini = masalah, seperti {{diuji:...}}."""
        lbl = self.b.get("label", {}).get(bhs)
        if not lbl:
            self.masalah.append(f"config [bina.label.{bhs}] tiada (tajuk lajur jadual halaman depan)")
            return ""
        baris = [f"| {lbl['bab']} | {lbl['diuji']} | {lbl['langkah']} |", "|---|---|---|"]
        for f in bab:
            nama = f.removesuffix(".md")
            d = self.diuji(nama, asal)
            if d is None:
                continue
            n = len(json.loads((self.akar / "bukti" / f"{nama}.json").read_text(encoding="utf-8")).get("langkah", []))
            baris.append(f"| [{tajuk[f]}]({bhs}/{f}) | {d} | {n} |")
        return "\n".join(baris)

    # ---- templat ------------------------------------------------------------------------------------------------
    def blok_kod(self, teks: str) -> list[tuple[str, str, int]]:
        """[(label, isi, baris mula)] setiap blok berpagar ```; blok tidak ditutup = masalah pemanggil."""
        blok, buka, isi = [], None, []
        for n, baris in enumerate(teks.splitlines(), 1):
            s = baris.strip()
            if buka is None and s.startswith("```"):
                buka, isi = (s[3:].strip().split() or [""])[0], []
                mula = n
            elif buka is not None and s == "```":
                blok.append((buka, "".join(x + "\n" for x in isi), mula))
                buka = None
            elif buka is not None:
                isi.append(baris)
        if buka is not None:
            blok.append((buka, None, mula))
        return blok

    def semak_blok(self, teks: str, asal: str, benar: set[str] | None) -> None:
        """benar=None (templat): tiada blok shell/tanpa label langsung. benar=set (hasil): blok shell mesti dari langkah."""
        for label, isi, n in self.blok_kod(teks):
            if isi is None:
                self.masalah.append(f"{asal}:{n}: blok kod tidak ditutup")
            elif label == "":
                self.masalah.append(f"{asal}:{n}: blok kod tanpa label bahasa")
            elif label in self.shell and benar is None:
                self.masalah.append(f"{asal}:{n}: arahan ditaip dalam templat (guna {{{{langkah:<bab>/<id>}}}})")
            elif label in self.shell and isi not in benar:
                self.masalah.append(f"{asal}:{n}: blok {label} bukan dari mana-mana fail langkah")

    def ganti(self, teks: str, asal: str, jadual: str | None) -> str:
        def satu(m: re.Match) -> str:
            jenis, arg = m[1], m[2]
            v = None
            if jenis == "langkah" and arg and "/" in arg:
                bab, _, lid = arg.rpartition("/")
                kod = self.langkah_bab(bab, asal)
                if kod is not None and lid not in kod:
                    self.masalah.append(f"{asal}: langkah '{lid}' tiada dalam bab '{bab}'")
                elif kod is not None:
                    v = f"```bash\n{kod[lid]}```"
            elif jenis == "config" and arg:
                v = self.nilai_config(arg, asal)
            elif jenis == "ejen" and arg and "." in arg:
                v = self.nilai_ejen(arg, asal)
            elif jenis == "diuji" and arg:
                v = self.diuji(arg, asal)
            elif jenis == "kandungan" and not arg:
                if jadual is None:
                    self.masalah.append(f"{asal}: {{{{kandungan}}}} hanya dalam fail indeks {self.b['indeks']} atau halaman depan")
                v = jadual
            else:
                self.masalah.append(f"{asal}: pemegang tempat tidak dikenali '{m[0]}'")
            return m[0] if v is None else v
        dalam = False   # "{{" sisa di luar blok kod = pemegang tempat yang salah eja (kod langkah boleh membawa "{{")
        for n, baris in enumerate(teks.splitlines(), 1):
            dalam ^= baris.strip().startswith("```")
            if not dalam and "{{" in RE_PEMEGANG.sub("", baris):
                self.masalah.append(f"{asal}:{n}: '{{{{' tanpa pemegang tempat yang sah")
        return RE_PEMEGANG.sub(satu, teks)

    def tajuk(self, teks: str, asal: str) -> str:
        t = next((b[2:].strip() for b in teks.splitlines() if b.startswith("# ")), None)
        if not t:
            self.masalah.append(f"{asal}: tiada tajuk '# ' (perlu untuk jadual kandungan)")
        return t or "?"

    def jana(self) -> dict[str, str]:
        """{laluan relatif repo: isi} untuk setiap bahasa. Masalah dikumpul dalam self.masalah."""
        hasil: dict[str, str] = {}
        for bhs in self.b["bahasa"]:
            sumber = self.akar / "kandungan" / bhs
            urutan = self.b.get("urutan", [])   # folder bab dalam jadual kandungan: teras dahulu, kemudian ejen
            fail = sorted((p.relative_to(sumber).as_posix() for p in sumber.rglob("*.md")) if sumber.is_dir() else [],
                          key=lambda f: (urutan.index(f.split("/")[0]) if f.split("/")[0] in urutan else len(urutan), f))
            if not fail:
                self.masalah.append(f"kandungan/{bhs}: tiada templat")
                continue
            teks = {f: (sumber / f).read_text(encoding="utf-8") for f in fail}
            bab = [f for f in fail if f != self.b["indeks"]]
            tajuk = {f: self.tajuk(teks[f], f"kandungan/{bhs}/{f}") for f in bab}
            jadual = "\n".join(f"- [{tajuk[f]}]({f})" for f in bab)
            for f in fail:
                asal = f"kandungan/{bhs}/{f}"
                self.semak_blok(teks[f], asal, None)
                kepala = f"<!-- generated from {asal} by alat/bina.py: edit the template, not this file -->\n"
                hasil[f"{bhs}/{f}"] = kepala + self.ganti(teks[f], asal, jadual if f == self.b["indeks"] else None)
            if self.b["indeks"] not in fail:
                self.masalah.append(f"kandungan/{bhs}/{self.b['indeks']}: fail indeks tiada")
            if keluar := self.b.get("depan", {}).get(bhs):   # halaman depan repo (README.md, README.ms.md; PRD K9)
                asal = f"kandungan/depan/{bhs}.md"
                if not (self.akar / asal).is_file():
                    self.masalah.append(f"{asal}: templat halaman depan tiada (config [bina] depan)")
                    continue
                t = (self.akar / asal).read_text(encoding="utf-8")
                self.semak_blok(t, asal, None)
                kepala = f"<!-- generated from {asal} by alat/bina.py: edit the template, not this file -->\n"
                hasil[keluar] = kepala + self.ganti(t, asal, self.jadual_depan(bhs, bab, tajuk, asal))
        self.semak_contoh()
        self.semak_ejen()
        benar = self.semua_kod_langkah()
        for rel, isi in hasil.items():
            self.semak_blok(isi, rel, benar)
        return hasil

    def dijejak(self) -> dict[str, str]:
        keluar = {}
        for bhs in self.b["bahasa"]:
            d = self.akar / bhs
            for p in sorted(d.rglob("*")) if d.is_dir() else []:
                if p.is_file():
                    keluar[p.relative_to(self.akar).as_posix()] = p.read_text(encoding="utf-8", errors="replace")
        for f in self.b.get("depan", {}).values():
            if (self.akar / f).is_file():
                keluar[f] = (self.akar / f).read_text(encoding="utf-8", errors="replace")
        return keluar


def semak(akar: Path = AKAR) -> list[str]:
    p = Penjana(akar)
    hasil, ada = p.jana(), p.dijejak()
    benar = p.semua_kod_langkah()
    for rel in sorted(ada.keys() - hasil.keys()) + [f for f in sorted(ada.keys() & hasil.keys()) if ada[f] != hasil[f]]:
        p.semak_blok(ada[rel], rel, benar)   # fail dijejak yang lain dari hasil: namakan arahan tulisan tangan
    m = list(p.masalah)
    m += [f"{f}: tiada (jalankan alat/bina.py)" for f in sorted(hasil.keys() - ada.keys())]
    m += [f"{f}: bukan hasil jana (dari templat mana?)" for f in sorted(ada.keys() - hasil.keys())]
    m += [f"{f}: berbeza dari hasil jana (disunting dengan tangan? jalankan alat/bina.py)"
          for f in sorted(hasil.keys() & ada.keys()) if hasil[f] != ada[f]]
    return m


def tulis(akar: Path = AKAR) -> list[str]:
    p = Penjana(akar)
    hasil = p.jana()
    if p.masalah:
        return p.masalah   # tiada tulisan separa
    for f in sorted(p.dijejak().keys() - hasil.keys()):
        (akar / f).unlink()
    for f, isi in hasil.items():
        (akar / f).parent.mkdir(parents=True, exist_ok=True)
        (akar / f).write_text(isi, encoding="utf-8")
    for bhs in p.b["bahasa"]:   # folder kosong yang tinggal selepas fail dibuang
        for d in sorted((akar / bhs).rglob("*"), reverse=True):
            if d.is_dir() and not any(d.iterdir()):
                d.rmdir()
    print(f"bina: {len(hasil)} fail dijana")
    return []


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--semak", action="store_true", help="semak tanpa menulis (gerbang)")
    a = ap.parse_args(argv)
    masalah = semak() if a.semak else tulis()
    for x in masalah:
        print(f"bina: {x}")
    if a.semak:
        print(f"bina --semak: {len(masalah)} masalah")
    return 1 if masalah else 0


if __name__ == "__main__":
    sys.exit(main())
