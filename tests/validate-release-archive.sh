#!/usr/bin/env bash

set -Eeuo pipefail

package_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
archive_checksum="$(
  awk -F "'" '
    /^sha256sums=/ { in_checksums = 1 }
    in_checksums && /[^[:space:]]/ {
      for (field = 2; field <= NF; field += 2) {
        print $field
        exit
      }
    }
  ' "$package_dir/PKGBUILD"
)"

if [[ ! $archive_checksum =~ ^[[:xdigit:]]{64}$ ]]; then
  printf '%s\n' 'The v0.1.0 release archive must use a fixed SHA-256 checksum.' >&2
  exit 1
fi

docker run --rm \
  --volume "$package_dir:/package:ro" \
  archlinux:latest \
  bash -Eeuo pipefail -c '
    pacman -Sy --noconfirm --needed base-devel

    useradd --create-home builder
    install -d -m 0755 -o builder -g builder /work/package
    cp -a /package/PKGBUILD /package/git-setup /work/package/
    chown builder:builder /work/package/PKGBUILD /work/package/git-setup

    su --shell /bin/bash builder --command \
      "cd /work/package && makepkg --verifysource"
  '

printf '%s\n' 'PASS: published release archive checksum validation'
