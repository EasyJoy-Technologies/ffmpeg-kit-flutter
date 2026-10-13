#!/usr/bin/env python3
"""Assembles the NiceNote AAR: every entry of the published 2.2.1 AAR except jni/, plus the new
native libraries. Writes <artifact>-<version>.aar and .pom into a Maven repository directory."""
import argparse, hashlib, os, re, shutil, sys, zipfile

STAMP = (1980, 2, 1, 0, 0, 0)  # same fixed timestamp AGP uses: byte-identical output for identical input


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--base-aar', required=True)
    ap.add_argument('--base-sha256', required=True)
    ap.add_argument('--libs', required=True)
    ap.add_argument('--abis', nargs='+', required=True)
    ap.add_argument('--group', required=True)
    ap.add_argument('--artifact', required=True)
    ap.add_argument('--version', required=True)
    ap.add_argument('--out', required=True)
    a = ap.parse_args()
    if sha256(a.base_aar) != a.base_sha256:
        sys.exit(f'base AAR sha256 mismatch: {a.base_aar}')
    if os.path.isdir(a.out):
        shutil.rmtree(a.out)
    os.makedirs(a.out)
    name = f'{a.artifact}-{a.version}'
    aar = os.path.join(a.out, name + '.aar')
    with zipfile.ZipFile(a.base_aar) as base, zipfile.ZipFile(aar, 'w', zipfile.ZIP_DEFLATED) as out:
        for info in base.infolist():
            if info.filename.startswith('jni/'):
                continue
            data = base.read(info.filename)
            info.date_time, info.compress_type = STAMP, zipfile.ZIP_DEFLATED  # keeps permissions
            out.writestr(info, data)
        for abi in a.abis:
            for so in sorted(f for f in os.listdir(os.path.join(a.libs, abi)) if f.endswith('.so')):
                path = os.path.join(a.libs, abi, so)
                entry = zipfile.ZipInfo.from_file(path, f'jni/{abi}/{so}')
                entry.date_time, entry.compress_type = STAMP, zipfile.ZIP_DEFLATED
                with open(path, 'rb') as f:
                    out.writestr(entry, f.read())
    with open(a.base_aar[:-4] + '.pom', encoding='utf-8') as f:
        pom = f.read()
    pom = re.sub(r'<groupId>[^<]*</groupId>', f'<groupId>{a.group}</groupId>', pom, count=1)
    pom = re.sub(r'<artifactId>[^<]*</artifactId>', f'<artifactId>{a.artifact}</artifactId>', pom, count=1)
    pom = re.sub(r'<version>[^<]*</version>', f'<version>{a.version}</version>', pom, count=1)
    desc = f'FFmpeg {a.version.split("-")[0]} for NiceNote (audio-trimmed, LGPL v3); Java layer from com.antonkarpenko:ffmpeg-kit-min:2.2.1'
    pom = re.sub(r'<name>[^<]*</name>', f'<name>{desc}</name>', pom, count=1)
    pom = re.sub(r'<description>[^<]*</description>', f'<description>{desc}</description>', pom, count=1)
    pom = re.sub(r'<url>[^<]*</url>', '<url>https://github.com/EasyJoy-Technologies/ffmpeg-kit-flutter</url>', pom, count=1)
    # No Gradle module metadata is published, so the "prefer .module" marker must go.
    pom = re.sub(r'\s*<!-- [^\n]*-->', '', pom)
    with open(os.path.join(a.out, name + '.pom'), 'w', encoding='utf-8') as f:
        f.write(pom)
    print(f'{aar}: {os.path.getsize(aar):,} bytes, sha256 {sha256(aar)}')


if __name__ == '__main__':
    main()
