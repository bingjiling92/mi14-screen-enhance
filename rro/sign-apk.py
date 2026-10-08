#!/usr/bin/env python3
# 给 APK 做 JAR(v1) 签名 —— 纯 Python + openssl，不需要 Java
# Copyright (c) 2026 bingjiling92 | SPDX-License-Identifier: MIT
#
# 为什么要自己签：手机上的 Termux 有 apksigner，但它是 java 程序，
# 而且 Termux 的 JVM 在本机上会被小米的 /system_ext/lib64/libjpeg-hyper.so 带崩。
#
# 为什么 v1 就够：Android 只对 targetSdkVersion >= 30 的包强制要求 v2 签名；
# 本 overlay 用 --target-sdk-version 29 构建，v1 即可被 PackageManager 接受。
# v1 的摘要覆盖的是「解压后内容」，所以先 zipalign 后签名是完全安全的。
#
# 用法: sign-apk.py <in.apk> <out.apk> <key.pem> <cert.pem>
import base64, hashlib, io, os, subprocess, sys, zipfile

def b64(b): return base64.b64encode(b).decode()

def main():
    if len(sys.argv) != 5:
        print(__doc__); return 2
    src, dst, key, cert = sys.argv[1:5]

    zin = zipfile.ZipFile(src, "r")
    names = [n for n in zin.namelist() if not n.startswith("META-INF/") and not n.endswith("/")]
    names.sort()

    # ---- META-INF/MANIFEST.MF ----
    man = io.BytesIO()
    man.write(b"Manifest-Version: 1.0\r\n")
    man.write(b"Created-By: 1.0 (mi14 dimfloor)\r\n")
    man.write(b"\r\n")
    for n in names:
        digest = hashlib.sha256(zin.read(n)).digest()
        man.write(("Name: %s\r\n" % n).encode())
        man.write(("SHA-256-Digest: %s\r\n" % b64(digest)).encode())
        man.write(b"\r\n")
    man_bytes = man.getvalue()

    # ---- META-INF/CERT.SF ----
    sf  = io.BytesIO()
    sf.write(b"Signature-Version: 1.0\r\n")
    sf.write(b"Created-By: 1.0 (mi14 dimfloor)\r\n")
    sf.write(("SHA-256-Digest-Manifest: %s\r\n"
              % b64(hashlib.sha256(man_bytes).digest())).encode())
    sf.write(b"\r\n")
    sf_bytes = sf.getvalue()

    # ---- 用 openssl 生成 PKCS#7/CMS 签名（含签名证书，无 signed attributes）----
    with open("/tmp/_cert_sf.bin", "wb") as f:
        f.write(sf_bytes)
    subprocess.run(["openssl", "smime", "-sign",
                    "-in", "/tmp/_cert_sf.bin",
                    "-signer", cert, "-inkey", key,
                    "-md", "sha256", "-noattr", "-nodetach", "-binary",
                    "-outform", "DER", "-out", "/tmp/_cert_rsa.bin"],
                   check=True, capture_output=True)
    rsa_bytes = open("/tmp/_cert_rsa.bin", "rb").read()

    # ---- 写出签名后的 APK（追加三个 META-INF 条目）----
    if os.path.exists(dst): os.remove(dst)
    zout = zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED)
    for item in zin.infolist():
        if item.filename.startswith("META-INF/"):
            continue
        data = zin.read(item.filename)
        zi = zipfile.ZipInfo(item.filename, date_time=item.date_time)
        zi.compress_type = item.compress_type
        zi.external_attr = item.external_attr
        zout.writestr(zi, data)
    for name, data in (("META-INF/MANIFEST.MF", man_bytes),
                       ("META-INF/CERT.SF", sf_bytes),
                       ("META-INF/CERT.RSA", rsa_bytes)):
        zi = zipfile.ZipInfo(name, date_time=(2009, 1, 1, 0, 0, 0))
        zi.compress_type = zipfile.ZIP_DEFLATED
        zout.writestr(zi, data)
    zout.close(); zin.close()

    for f in ("/tmp/_cert_sf.bin", "/tmp/_cert_rsa.bin"):
        try: os.remove(f)
        except OSError: pass

    print("已签名: %s" % dst)
    print("  条目数: %d（另加 3 个 META-INF）" % len(names))
    print("  MANIFEST.MF %d 字节 / CERT.SF %d 字节 / CERT.RSA %d 字节"
          % (len(man_bytes), len(sf_bytes), len(rsa_bytes)))
    return 0

sys.exit(main())
