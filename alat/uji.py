#!/usr/bin/env python3
"""Alat ujian bab (PRD K4–K6): jalankan setiap blok `# @langkah` satu fail langkah dalam bekas Ubuntu BAHARU, tulis bukti.

Tiada arahan panduan dijalankan atas mesin yang melancar alat ini: setiap bab dapat bekas `ubuntu:<versi config>` sendiri
(dan bekas pelayan palsu bila perlu) atas rangkaian docker sendiri, semuanya dibuang di hujung walaupun langkah gagal.

    python3 alat/uji.py teras/00-contoh [--tapis <fail regex>]   langkah/teras/00-contoh.sh -> bukti/teras/00-contoh.json
    python3 alat/uji.py --semak                                    setiap fail langkah ada bukti yang sah dan terkini

Format fail langkah + arahan `# @…`: alat/fail_langkah.py.
--tapis = fail regex (satu baris satu corak) yang tidak boleh muncul dalam log bukti; padanan diganti `[ditapis]`.
Kod keluar: 0 lulus · 1 langkah gagal atau bukti tidak sah · 2 ralat guna atau docker.
"""
from __future__ import annotations

import argparse
import datetime as dt
import importlib.util
import json
import re
import secrets
import shlex
import subprocess
import sys
import time
import tomllib
from pathlib import Path

AKAR = Path(__file__).resolve().parent.parent
LABEL = "uji.panduan=1"


def _muat(nama: str):
    spec = importlib.util.spec_from_file_location(nama, Path(__file__).resolve().parent / f"{nama}.py")
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


_fl = _muat("fail_langkah")
(RalatGuna, urai, arahan_blok, tampalan, Tampal, prasyarat, basi, sha256, RE_LANGKAH, RE_TAMPAL, RE_MESEJ,
 KEPERLUAN) = (_fl.RalatGuna, _fl.urai, _fl.arahan_blok, _fl.tampalan, _fl.Tampal, _fl.prasyarat, _fl.basi, _fl.sha256,
               _fl.RE_LANGKAH, _fl.RE_TAMPAL, _fl.RE_MESEJ, _fl.KEPERLUAN)


class LangkahGagal(Exception):
    pass


def muat_config(akar: Path = AKAR) -> dict:
    with open(akar / "config" / "panduan.toml", "rb") as fh:
        return tomllib.load(fh)


def muat_tapis(fail: Path | None) -> list[re.Pattern]:
    corak = [re.escape(str(Path.home())), re.escape(str(AKAR))]   # laluan mesin pelancar tidak pernah masuk bukti
    if fail:
        corak += [b.strip() for b in fail.read_text(encoding="utf-8").splitlines()
                  if b.strip() and not b.strip().startswith("#")]
    return [re.compile(c, re.I) for c in corak]


def tapis_log(teks: str, corak: list[re.Pattern], ekor: int, lebar: int) -> list[str]:
    baris = [b.rstrip() for b in teks.replace("\r", "\n").splitlines() if b.strip()][-ekor:]
    keluar = []
    for b in baris:
        for c in corak:
            b = c.sub("[ditapis]", b)
        keluar.append(b if len(b) <= lebar else b[:lebar] + "...")
    return keluar


def env_langkah(cfg: dict, perlu: set[str]) -> dict[str, str]:
    env = {k: str(v) for k, v in cfg["uji"].get("env", {}).items()}
    if "palsu" in perlu:
        p = cfg["palsu"]
        env.update({k: str(v).format(hos=p["hos"], port=p["port"]) for k, v in p["env"].items()})
    return env


DOCKER = "docker"


def docker(*a: str, masuk: str | None = None, masa: float | None = None, semak: bool = True):
    return subprocess.run([DOCKER, *a], input=masuk, capture_output=True, text=True, timeout=masa, check=semak)


def tunggu(nama: str, penanda: str, saat: float) -> str:
    """Tunggu baris log bermula `penanda` dari bekas `nama`; bekas berhenti atau tamat masa = RalatGuna dengan ekor log."""
    hujung = time.monotonic() + saat
    while time.monotonic() < hujung:
        log = docker("logs", nama, semak=False)
        teks = log.stdout + log.stderr
        if b := next((b for b in teks.splitlines() if b.startswith(penanda)), None):
            return b
        jalan = docker("inspect", "--format", "{{.State.Running}}", nama, semak=False)
        if log.returncode != 0 or jalan.stdout.strip() != "true":   # pelancar VM tanpa --rm: berhenti tetapi masih wujud
            raise RalatGuna(f"bekas {nama} berhenti: {teks.strip()[-400:]}")
        time.sleep(2)
    raise RalatGuna(f"bekas {nama} tidak sedia dalam {saat:.0f} s")


def env_vm(cfg: dict, besar: bool = False) -> dict[str, str]:
    """Env bekas pelancar VM (uji/vm/mula-vm.sh) dari config [vm] + [ubuntu] + [contoh]; `besar` = nilai [vm.besar]."""
    v, u = {**cfg["vm"], **(cfg["vm"]["besar"] if besar else {})}, cfg["ubuntu"]
    return {"VM_URL_IMEJ": v["url_imej"].format(**u), "VM_URL_SHA": v["url_sha"].format(**u),
            "VM_IP": cfg["contoh"]["ip_vps"], "VM_IP_PELANCAR": v["ip_pelancar"], "VM_PENGGUNA": v["pengguna_uji"],
            "VM_NAMA_HOS": cfg["uji"]["hostname"], "VM_MEMORI_MB": str(v["memori_mb"]), "VM_CPU": str(v["cpu"]),
            "VM_CAKERA": v["cakera"], "VM_MASA_SEDIA_S": str(v["masa_sedia_s"])}


def env_ca(cfg: dict) -> dict[str, str]:
    """Env CA ujian (uji/vm/ca-palsu.sh) dari config [ca] + nama contoh yang perlu menghala ke VM."""
    c, k = cfg["ca"], cfg["contoh"]
    return {"CA_URL": c["url"].format(**c), "CA_SHA256": c["sha256"], "CA_HOS_ACME": " ".join(c["hos_acme"]),
            "CA_NAMA_VM": " ".join([k["domain"], k["subdomain_ejen"]])}


def arahan_langkah(cfg: dict, nama: str, perlu: set[str], tempat: str, env: dict[str, str], kod: str) -> list[str]:
    """Hujah docker untuk satu langkah: dalam bekas ujian (tahap A), dalam VM melalui SSH, atau dalam pelancar (luar).
    Kod blok = hujah `bash -c`, BUKAN stdin: stdin hanya membawa input pembaca (`# @tampal`), seperti papan kekunci. Dulu
    kod melalui stdin (`bash -s`), dan arahan yang membaca stdin (`docker compose run`, `ssh`) menelan baki blok: bash
    keluar 0 tanpa menjalankan baris selepasnya, dan langkah "lulus" (D11)."""
    if "vm" not in perlu or tempat == "luar":
        return ["exec", "-i", *[x for k, v in env.items() for x in ("-e", f"{k}={v}")], nama,
                "bash", "-euo", "pipefail", "-c", kod]
    jauh = " ".join(["sudo", "-n", "env", *[shlex.quote(f"{k}={v}") for k, v in env.items()],
                     "bash", "-euo", "pipefail", "-c", shlex.quote(kod)])
    return ["exec", "-i", nama, "ssh", "-i", "/vm/kunci", "-o", "StrictHostKeyChecking=no", "-o",
            "UserKnownHostsFile=/dev/null", "-o", "LogLevel=ERROR", "-o", "BatchMode=yes",
            f"{cfg['vm']['pengguna_uji']}@{cfg['contoh']['ip_vps']}", jauh]


def mula_bekas(cfg: dict, nama: str, imej: str, perlu: set[str], akar: Path) -> None:
    docker("network", "create", "--label", LABEL, nama)
    if "palsu" in perlu:
        p = cfg["palsu"]
        arahan = ("apt-get update -qq && apt-get install -y -qq --no-install-recommends python3 >/dev/null"
                  f" && exec python3 -u /palsu/pelayan.py --port {p['port']}"
                  + (f" --mesej-awal {shlex.quote(p['mesej_awal'])}" if p.get("mesej_awal") else ""))
        docker("run", "-d", "--rm", "--name", f"{nama}-palsu", "--label", LABEL, "--network", nama,
               "--network-alias", p["hos"], "--tmpfs", "/tmp", "-e", "DEBIAN_FRONTEND=noninteractive",
               "-v", f"{akar / 'uji' / 'palsu'}:/palsu:ro", imej, "bash", "-c", arahan)
    if "vm" in perlu:   # pelancar: KVM + tap (NET_ADMIN dalam ruang nama rangkaian bekas sahaja), fail VM dalam tmpfs
        ev = {"DEBIAN_FRONTEND": "noninteractive", **env_vm(cfg, "besar" in perlu)}
        if "palsu" in perlu:
            ev["VM_PALSU_HOS"] = cfg["palsu"]["hos"]
        if "ca" in perlu:
            ev.update(env_ca(cfg))
        env = [x for k, v in ev.items() for x in ("-e", f"{k}={v}")]
        docker("run", "-d", "--name", nama, "--label", LABEL, "--network", nama, "--hostname", "luar",   # tanpa --rm: log kekal bila gagal
               "--device", "/dev/kvm", "--device", "/dev/net/tun", "--cap-add", "NET_ADMIN",
               *(["-v", "/vm"] if "besar" in perlu else ["--tmpfs", f"/vm:size={cfg['vm']['tmpfs_mb']}m,exec"]),
               "--tmpfs", "/tmp", *env,
               "-v", f"{akar / 'uji' / 'vm'}:/uji-vm:ro", imej, "bash", "/uji-vm/mula-vm.sh")
    else:
        docker("run", "-d", "--rm", "--name", nama, "--label", LABEL, "--network", nama, "--hostname",
               cfg["uji"]["hostname"], "--tmpfs", "/tmp", imej, "sleep", "infinity")
    if "palsu" in perlu:
        tunggu(f"{nama}-palsu", "palsu: sedia", cfg["uji"]["masa_sedia_s"])
    if "vm" in perlu:
        tunggu(nama, "vm: sedia", cfg["vm"]["masa_sedia_s"] + cfg["vm"]["masa_muat_s"])


def buang_bekas(nama: str) -> None:
    docker("rm", "-fv", nama, f"{nama}-palsu", semak=False)
    docker("network", "rm", nama, semak=False)


def rekod_palsu(nama: str, cfg: dict, corak: list[re.Pattern]) -> dict:
    url = f"http://127.0.0.1:{cfg['palsu']['port']}/_palsu/rekod"
    r = docker("exec", f"{nama}-palsu", "python3", "-c",
               f"import urllib.request;print(urllib.request.urlopen('{url}').read().decode())", semak=False)
    if r.returncode != 0:
        return {"ralat": "rekod palsu tidak dapat dibaca"}
    data = json.loads(r.stdout)
    teks = [m["text"] for m in data.get("dihantar", [])]
    return {"kiraan": data.get("kiraan", {}), "dihantar": tapis_log("\n".join(teks), corak, 10, cfg["uji"]["log_lebar"])}


def hantar_mesej(nama: str, cfg: dict, teks: str) -> None:
    """Pembaca menaip `teks` kepada bot: satu mesej masuk ke baris gilir getUpdates Telegram palsu."""
    url = f"http://127.0.0.1:{cfg['palsu']['port']}/_palsu/masuk"
    kod = ("import json,sys,urllib.request;urllib.request.urlopen(urllib.request.Request(sys.argv[1],"
           "data=json.dumps({'text':sys.argv[2]}).encode(),headers={'Content-Type':'application/json'}))")
    docker("exec", f"{nama}-palsu", "python3", "-c", kod, url, teks)


KOD_TAMPAL_SISA = 97


def balut_tampal(kod: str) -> str:
    """Blok `# @tampal`: kod dalam subshell (stdin sama), kemudian input yang masih tersisa = gagal. Kod dulu melalui stdin
    dan nilai yang tidak dibaca dijalankan bash sebagai arahan (D10); sejak kod = `bash -c` (D11) nilai itu dibuang senyap
    dan langkah yang tidak membaca input lulus. Subshell: `exit 0` awal dalam blok tidak melangkau semakan ini."""
    return (f"(\n{kod}\n)\n"
            'if IFS= read -r sisa || [ -n "$sisa" ]; then echo "input tampalan tidak dibaca oleh blok ini" >&2; '
            f"exit {KOD_TAMPAL_SISA}; fi\n")


def jalan_satu(cfg: dict, nama: str, perlu: set[str], tempat: str, env: dict[str, str], kod: str,
               tampal: str = "", mesej: list[str] | None = None) -> tuple[int, str, float]:
    for teks in mesej or []:
        hantar_mesej(nama, cfg, teks)
    if tampal:
        kod = balut_tampal(kod)
    t0, had = time.monotonic(), cfg["uji"]["masa_langkah_s"]
    try:   # stderr ke dalam stdout: log bukti dalam urutan sebenar (bukan semua stderr selepas semua stdout)
        r = subprocess.run([DOCKER, *arahan_langkah(cfg, nama, perlu, tempat, env, kod)], input=tampal, text=True,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=had)
        rc, out = r.returncode, r.stdout
    except subprocess.TimeoutExpired as e:
        sisa = e.stdout.decode(errors="replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
        rc, out = 124, f"{sisa}\n(dihentikan selepas {had} s)"
    return rc, out, round(time.monotonic() - t0, 1)


def jalankan(bab: str, akar: Path = AKAR, tapis: Path | None = None) -> tuple[int, dict]:
    cfg = muat_config(akar)
    fail = akar / "langkah" / f"{bab}.sh"
    if not fail.is_file():
        raise RalatGuna(f"fail langkah tiada: langkah/{bab}.sh")
    perlu, langkah, selepas = urai(fail.read_text(encoding="utf-8"))
    pras = prasyarat(akar, bab, perlu, selepas)
    imej, u, corak = f"ubuntu:{cfg['ubuntu']['versi']}", cfg["uji"], muat_tapis(tapis)
    if docker("image", "inspect", imej, semak=False).returncode != 0:
        docker("pull", "-q", imej)
    digest = json.loads(docker("image", "inspect", imej, "--format", "{{json .RepoDigests}}").stdout or "[]")
    nama = "uji-" + re.sub(r"[^a-z0-9]+", "-", bab.lower()).strip("-") + "-" + secrets.token_hex(3)
    env, tp = env_langkah(cfg, perlu), Tampal(cfg)
    bukti = {"bab": bab, "tahap": "B" if "vm" in perlu else "A", "imej": imej, "digest": digest[0] if digest else None,
             "tarikh_utc": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
             "fail_langkah": f"langkah/{bab}.sh", "sha256": sha256(fail), "lulus": False, "langkah": []}
    try:
        mula_bekas(cfg, nama, imej, perlu, akar)
        if "vm" in perlu:
            log = docker("logs", nama, semak=False).stdout
            bukti["vm"] = tapis_log("\n".join(b for b in log.splitlines() if b.startswith("vm: ")), corak, 10, u["log_lebar"])
        if "ca" in perlu:
            log = docker("logs", nama, semak=False).stdout
            bukti["ca"] = tapis_log("\n".join(b for b in log.splitlines() if b.startswith("ca: ")), corak, 10, u["log_lebar"])
        if pras:
            bukti["prasyarat"] = []
        for p, fp, lp in pras:   # bab sebelumnya dalam mesin yang sama; log hanya disimpan untuk langkah yang gagal
            rek, tpp = {"bab": p, "sha256": sha256(fp), "langkah": []}, tampalan(fp.read_text(encoding="utf-8"))
            msp = arahan_blok(fp.read_text(encoding="utf-8"), RE_MESEJ)
            bukti["prasyarat"].append(rek)
            for id_, kod, tempat in lp:
                rc, out, t = jalan_satu(cfg, nama, perlu, tempat, env, kod, tp.input(tpp.get(id_, [])), msp.get(id_))
                rek["langkah"].append({"id": id_, "kod": rc, "tempoh_s": t,
                                       **({} if rc == 0 else {"log": tapis_log(out, corak, u["log_ekor"], u["log_lebar"])})})
                print(f"  {'ok ' if rc == 0 else 'GAGAL'} [{p}] {id_} (kod {rc}, {t} s)")
                if rc != 0:
                    raise LangkahGagal
        tpb, msb = tampalan(fail.read_text(encoding="utf-8")), arahan_blok(fail.read_text(encoding="utf-8"), RE_MESEJ)
        for id_, kod, tempat in langkah:
            rc, out, t = jalan_satu(cfg, nama, perlu, tempat, env, kod, tp.input(tpb.get(id_, [])), msb.get(id_))
            bukti["langkah"].append({"id": id_, **({"tempat": tempat} if tempat else {}), "kod": rc, "tempoh_s": t,
                                     "log": tapis_log(out, corak, u["log_ekor"], u["log_lebar"])})
            print(f"  {'ok ' if rc == 0 else 'GAGAL'} {id_} (kod {rc}, {t} s)")
            if rc != 0:
                break
        if "palsu" in perlu:
            bukti["palsu"] = rekod_palsu(nama, cfg, corak)
    except LangkahGagal:
        pass
    finally:
        buang_bekas(nama)
    bukti["lulus"] = (len(bukti["langkah"]) == len(langkah) and all(x["kod"] == 0 for x in bukti["langkah"])
                      and all(x["kod"] == 0 for p in bukti.get("prasyarat", []) for x in p["langkah"]))
    keluar = akar / "bukti" / f"{bab}.json"
    keluar.parent.mkdir(parents=True, exist_ok=True)
    keluar.write_text(json.dumps(bukti, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return (0 if bukti["lulus"] else 1), bukti


def semak(akar: Path = AKAR) -> list[str]:
    """Setiap fail langkah ada bukti: cincangan sama, imej = config, semua langkah dijalankan dengan kod 0."""
    cfg, masalah = muat_config(akar), []
    imej = f"ubuntu:{cfg['ubuntu']['versi']}"
    langkah_dir, bukti_dir = akar / "langkah", akar / "bukti"
    bab_langkah = {str(f.relative_to(langkah_dir))[:-3] for f in langkah_dir.rglob("*.sh")} if langkah_dir.is_dir() else set()
    bab_bukti = {str(f.relative_to(bukti_dir))[:-5] for f in bukti_dir.rglob("*.json")} if bukti_dir.is_dir() else set()
    for bab in sorted(bab_bukti - bab_langkah):
        masalah.append(f"{bab}: bukti tanpa fail langkah")
    for bab in sorted(bab_langkah):
        fail, fb = langkah_dir / f"{bab}.sh", bukti_dir / f"{bab}.json"
        if not fb.is_file():
            masalah.append(f"{bab}: tiada bukti (jalankan alat/uji.py {bab})")
            continue
        b = json.loads(fb.read_text(encoding="utf-8"))
        try:
            ids = [i for i, _, _ in urai(fail.read_text(encoding="utf-8"))[1]]
        except RalatGuna as e:
            masalah.append(f"{bab}: fail langkah rosak: {e}")
            continue
        for m in basi(akar, bab, b):
            masalah.append(f"{bab}: bukti basi ({m})")
        if b.get("imej") != imej:
            masalah.append(f"{bab}: bukti untuk {b.get('imej')}, config = {imej}")
        dijalan = [x.get("id") for x in b.get("langkah", [])]
        if dijalan != ids:
            masalah.append(f"{bab}: langkah dalam bukti {dijalan} != fail {ids}")
        gagal = [x["id"] for x in b.get("langkah", []) if x.get("kod") != 0]
        if gagal or not b.get("lulus"):
            masalah.append(f"{bab}: langkah gagal {gagal or '(lulus = false)'}")
    return masalah


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("bab", nargs="?", help="laluan bab di bawah langkah/, tanpa .sh (cth teras/00-contoh)")
    ap.add_argument("--tapis", type=Path, help="fail regex yang ditapis dari log bukti")
    ap.add_argument("--semak", action="store_true", help="semak semua bukti tanpa menjalankan bekas")
    a = ap.parse_args(argv)
    try:
        if a.semak:
            masalah = semak()
            for m in masalah:
                print(f"bukti: {m}")
            print(f"uji --semak: {len(masalah)} masalah")
            return 1 if masalah else 0
        if not a.bab:
            ap.error("beri nama bab atau --semak")
        print(f"uji {a.bab}:")
        rc, bukti = jalankan(a.bab, tapis=a.tapis)
        print(f"uji {a.bab}: {'LULUS' if rc == 0 else 'GAGAL'} -> bukti/{a.bab}.json")
        return rc
    except RalatGuna as e:
        print(f"uji: {e}", file=sys.stderr)
        return 2
    except subprocess.CalledProcessError as e:
        print(f"uji: docker gagal: {' '.join(e.cmd[:3])}: {(e.stderr or '').strip()[-300:]}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
