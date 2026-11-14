#!/bin/bash
# Install a prebuilt ACL2 + ACL2(r) toolchain from this repository's bundles/ directory.
#
#   install.sh --acl2 8.7|master [--extra "charon"] [--apt "pkg ..."] [--pip "pkg ..."]
#              [--remove "books/dir ..."] [--input "file ..."] [--git-allow "https://github.com/o/r"]
#
# --acl2       which ACL2 bundle to install (see README.md for what each contains)
# --extra      additional bundles: "charon" (upstream Charon with its pinned Rust nightly)
# --apt        extra Ubuntu packages, e.g. "z3 erlang-nox flex"
# --pip        extra Python packages
# --remove     book directories (relative to the ACL2 root) to delete from both the ACL2 and ACL2(r)
#              trees, together with any certificate or compiled file that refers to them
# --input      files from inputs/ to copy into /opt/inputs
# --git-allow  repository URL that stays reachable by git after GitHub is redirected
# --submit     git checkout (path relative to the setup's directory) into which `submit TASK` copies
#              /work as TASK/ and pushes; its remote stays reachable by git
#
# ACL2 bundles go under /opt (the images contain absolute paths); acl2, acl2r and cert.pl are linked
# into /usr/local/bin. Afterwards git is pointed away from GitHub, and a network probe is printed.
set -euo pipefail
BASE="https://raw.githubusercontent.com/ltmquan/acl2-2026-llm-toolchains/${TOOLCHAIN_REF:-main}"
declare -A TAG=([8.7]="acl2-8.7" [master]="acl2-master-1d2b39a424" [charon]="charon-aa29866")
declare -A PARTS=([acl2-8.7]=7 [acl2-master-1d2b39a424]=6 [charon-aa29866]=5)
declare -A DEST=([acl2-8.7]=/opt [acl2-master-1d2b39a424]=/opt [charon-aa29866]=/)
declare -A DIRS=([8.7]="acl2 acl2r" [master]="acl2-master acl2r-master")
declare -A SUM=(
  [acl2-8.7]="22b52952ed4c31c866b8c3865ae57fab82d44c00f446c98718ccb1225cb43194"
  [acl2-master-1d2b39a424]="99dc78686aa054f6a27a4383cdf6da40d080ee772487921e624dd8e4f2adb73d"
  [charon-aa29866]="c0fad67d12dc41dde62aaa10e5bf28dab027e51b8f36e999d7eb85af44be19c4"
  [aes-0.9.1.crate]="f1fc76eaeac4c9164506c466d4ffdd8ec9d0c5bf57ee97177c4d8eceb3a0e138"
)
WHICH=""; EXTRA=""; APT=""; PIP=""; REMOVE=""; INPUT=""; ALLOW=""; SUBMIT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --acl2) WHICH="$2"; shift 2;;
    --extra) EXTRA="$2"; shift 2;;
    --apt) APT="$2"; shift 2;;
    --pip) PIP="$2"; shift 2;;
    --remove) REMOVE="$2"; shift 2;;
    --input) INPUT="$2"; shift 2;;
    --git-allow) ALLOW="$2"; shift 2;;
    --submit) SUBMIT="$2"; shift 2;;
    *) echo "unknown argument $1" >&2; exit 2;;
  esac
done
[ "$WHICH" = 8.7 ] || [ "$WHICH" = master ] || { echo "--acl2 must be 8.7 or master" >&2; exit 2; }
ts() { echo "[setup $(date -u +%H:%M:%S)] $*"; }

ts "apt: sbcl zstd rsync $APT"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq sbcl zstd curl rsync $APT >/dev/null
[ -z "$PIP" ] || { ts "pip: $PIP"; pip install -q $PIP; }

fetch() {  # fetch <bundle name>: download its parts, check the sum, unpack
  local NAME="$1" F="/tmp/$1.tar.zst"
  ts "download $NAME"
  : > "$F"
  for ((i=0; i<${PARTS[$NAME]}; i++)); do
    curl -fsSL --retry 4 "$BASE/bundles/$NAME/$NAME.tar.zst.part-$(printf %02d $i)" >> "$F"
  done
  echo "${SUM[$NAME]}  $F" | sha256sum -c --quiet
  ts "unpack $NAME"
  tar --use-compress-program=unzstd -xf "$F" -C "${DEST[$NAME]}"
  rm -f "$F"
}

fetch "${TAG[$WHICH]}"
for x in $EXTRA; do
  [ -n "${TAG[$x]:-}" ] || { echo "unknown --extra $x" >&2; exit 2; }
  fetch "${TAG[$x]}"
done

read -r A AR <<<"${DIRS[$WHICH]}"
ln -sf "/opt/$A/saved_acl2" /usr/local/bin/acl2
ln -sf "/opt/$AR/saved_acl2r" /usr/local/bin/acl2r
ln -sf "/opt/$A/books/build/cert.pl" /usr/local/bin/cert.pl
[ ! -d /opt/charon/bin ] || ln -sf /opt/charon/bin/charon /opt/charon/bin/charon-driver /usr/local/bin/
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

for f in $INPUT; do
  ts "input $f"
  mkdir -p /opt/inputs
  curl -fsSL --retry 4 -o "/opt/inputs/$f" "$BASE/inputs/$f"
  echo "${SUM[$f]}  /opt/inputs/$f" | sha256sum -c --quiet
done

if [ -n "$SUBMIT" ] && [ ! -d "$SUBMIT/.git" ]; then
  ts "WARNING: $SUBMIT is not a git checkout here; submit not installed"
elif [ -n "$SUBMIT" ]; then
  R="$(cd "$SUBMIT" && pwd)"
  ALLOW="$ALLOW $(git -C "$R" remote get-url origin)"
  ts "submit -> $R"
  cat > /usr/local/bin/submit <<EOS
#!/bin/bash
# submit TASK: copy /work (without build outputs) to $R/TASK, commit, and push.
set -euo pipefail
T="\${1:?usage: submit TASK}"
mkdir -p "$R/\$T"
rsync -a --delete --exclude target/ --exclude '*.cert' --exclude '*.fasl' \\
  --exclude '*.port' --exclude '*.out' --exclude '*.lx64fsl' --exclude '*.cert.out' --exclude '*.time' \\
  --exclude '*@expansion.lsp' --exclude '.sys/' /work/ "$R/\$T/"
cd "$R"
git add -A "\$T"
git -c user.name=model -c user.email=model@invalid commit -q -m "Save \$T" || echo "nothing new to save"
git push -q origin HEAD && echo "saved \$T"
EOS
  chmod +x /usr/local/bin/submit
fi

ts "redirect GitHub for git"
git config --system url."https://github.invalid/".insteadOf "https://github.com/"
git config --system --add url."https://github.invalid/".insteadOf "git@github.com:"
for u in $ALLOW; do  # the longest matching insteadOf wins, so this URL maps to itself
  git config --system --add url."$u".insteadOf "$u"
done

ts "check images"
echo '(value :q) (sb-ext:exit)' | acl2 >/dev/null 2>&1 && echo "  acl2 ok"
echo '(value :q) (sb-ext:exit)' | acl2r >/dev/null 2>&1 && echo "  acl2r ok"
[ ! -x /usr/local/bin/charon ] || echo "  charon $(charon version 2>/dev/null || echo installed)"

ts "network probe (what the model can reach)"
for u in https://github.com https://raw.githubusercontent.com/acl2/acl2/master/README.md https://arxiv.org https://example.com https://www.cs.utexas.edu/~moore/acl2/; do
  echo "  $u -> $(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$u" || true)"
done
echo "  git ls-remote github -> $(timeout 20 git ls-remote https://github.com/acl2/acl2.git HEAD >/dev/null 2>&1 && echo reachable || echo blocked)"
ts "done"
