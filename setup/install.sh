#!/bin/bash
# Install a prebuilt ACL2 + ACL2(r) toolchain from this repository's bundles/ directory.
#
#   install.sh --acl2 8.7|master [--apt "pkg ..."] [--pip "pkg ..."] [--remove "books/dir ..."]
#
# --acl2    which bundle to install (see README.md for what each contains)
# --apt     extra Ubuntu packages, e.g. "z3 erlang-nox flex"
# --pip     extra Python packages
# --remove  book directories (relative to the ACL2 root) to delete from both the ACL2 and ACL2(r)
#           trees, together with any certificate or compiled file that refers to them
#
# Installs under /opt (the images contain absolute paths) and links acl2, acl2r and cert.pl into
# /usr/local/bin. Afterwards git is pointed away from GitHub, and a network probe is printed.
set -euo pipefail
RAW="https://raw.githubusercontent.com/ltmquan/acl2-2026-llm-toolchains/${TOOLCHAIN_REF:-main}/bundles"
declare -A TAG=([8.7]="acl2-8.7" [master]="acl2-master-1d2b39a424")
declare -A PARTS=([acl2-8.7]=7 [acl2-master-1d2b39a424]=6)
declare -A DIRS=([8.7]="acl2 acl2r" [master]="acl2-master acl2r-master")
declare -A SUM=(
  [acl2-8.7]="22b52952ed4c31c866b8c3865ae57fab82d44c00f446c98718ccb1225cb43194"
  [acl2-master-1d2b39a424]="99dc78686aa054f6a27a4383cdf6da40d080ee772487921e624dd8e4f2adb73d"
)
WHICH=""; APT=""; PIP=""; REMOVE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --acl2) WHICH="$2"; shift 2;;
    --apt) APT="$2"; shift 2;;
    --pip) PIP="$2"; shift 2;;
    --remove) REMOVE="$2"; shift 2;;
    *) echo "unknown argument $1" >&2; exit 2;;
  esac
done
[ -n "${TAG[$WHICH]:-}" ] || { echo "--acl2 must be 8.7 or master" >&2; exit 2; }
ts() { echo "[setup $(date -u +%H:%M:%S)] $*"; }

ts "apt: sbcl zstd $APT"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq sbcl zstd curl $APT >/dev/null
[ -z "$PIP" ] || { ts "pip: $PIP"; pip install -q $PIP; }

NAME="${TAG[$WHICH]}"; F="/tmp/$NAME.tar.zst"
ts "download $NAME"
: > "$F"
for ((i=0; i<${PARTS[$NAME]}; i++)); do
  curl -fsSL --retry 4 "$RAW/$NAME/$NAME.tar.zst.part-$(printf %02d $i)" >> "$F"
done
echo "${SUM[$NAME]}  $F" | sha256sum -c --quiet
ts "unpack"
tar --use-compress-program=unzstd -xf "$F" -C /opt
rm -f "$F"

read -r A AR <<<"${DIRS[$WHICH]}"
ln -sf "/opt/$A/saved_acl2" /usr/local/bin/acl2
ln -sf "/opt/$AR/saved_acl2r" /usr/local/bin/acl2r
ln -sf "/opt/$A/books/build/cert.pl" /usr/local/bin/cert.pl
mkdir -p /work

for d in $REMOVE; do
  for root in "/opt/$A" "/opt/$AR"; do
    [ -e "$root/$d" ] || continue
    ts "remove $root/$d"
    rm -rf "${root:?}/$d"
    # Certificates and compiled files of other books that mention the removed directory.
    grep -rlF --include='*.cert' --include='*.port' --include='*.out' --include='*.fasl' \
      "${d#books/}" "$root/books" 2>/dev/null | xargs -r rm -f || true
  done
done

ts "redirect GitHub for git"
git config --system url."https://github.invalid/".insteadOf "https://github.com/"
git config --system --add url."https://github.invalid/".insteadOf "git@github.com:"

ts "check images"
echo '(value :q) (sb-ext:exit)' | acl2 >/dev/null 2>&1 && echo "  acl2 ok"
echo '(value :q) (sb-ext:exit)' | acl2r >/dev/null 2>&1 && echo "  acl2r ok"

ts "network probe (what the model can reach)"
for u in https://github.com https://raw.githubusercontent.com/acl2/acl2/master/README.md https://arxiv.org https://example.com https://www.cs.utexas.edu/~moore/acl2/; do
  echo "  $u -> $(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$u" || true)"
done
echo "  git ls-remote github -> $(timeout 20 git ls-remote https://github.com/acl2/acl2.git HEAD >/dev/null 2>&1 && echo reachable || echo blocked)"
ts "done"
