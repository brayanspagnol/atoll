#!/usr/bin/env bash
# Maintainer tool: uploads this package to the AUR. Needs an AUR account with ~/.ssh/aur.pub registered.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
until ssh -o BatchMode=yes -o ConnectTimeout=10 aur@aur.archlinux.org help >/dev/null 2>&1; do
    echo
    echo "The AUR does not accept your key yet. In https://aur.archlinux.org, log in (or register),"
    echo "open My Account and paste this line into \"SSH Public Key\", then save:"
    echo
    cat ~/.ssh/aur.pub
    echo
    read -r -p "Press Enter to try again, or Ctrl+C to stop. " _
done
dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT
git clone -q ssh://aur@aur.archlinux.org/atoll.git "$dir"
cp "$here"/{PKGBUILD,.SRCINFO,atoll.install} "$dir/"
cd "$dir"
git config user.name "Brayan Spagnol"
git config user.email "121728908+brayanspagnol@users.noreply.github.com"
git add PKGBUILD .SRCINFO atoll.install
git commit -q -m "Initial upload: atoll $(sed -nE 's/^pkgver=//p' PKGBUILD)"
git push -q origin HEAD:master
echo "AUR: published at https://aur.archlinux.org/packages/atoll"
