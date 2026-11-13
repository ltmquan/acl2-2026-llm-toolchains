#!/bin/bash
# How the release bundles were built (Ubuntu 24.04, SBCL 2.2.9 from apt, 4 cores).
# Everything comes from the public ACL2 repository, https://github.com/acl2/acl2.
set -euo pipefail
J=$(nproc)
apt-get install -y -qq sbcl zstd

build() {  # build <dir> <git ref>
  git clone -q https://github.com/acl2/acl2.git "/opt/$1" && git -C "/opt/$1" checkout -q "$2"
  cp -a "/opt/$1" "/opt/${1/acl2/acl2r}"
  (cd "/opt/$1" && make LISP=sbcl) &
  (cd "/opt/${1/acl2/acl2r}" && make LISP=sbcl ACL2_REAL=r) &
  wait
}

certify() {  # certify <acl2 dir>
  local A="/opt/$1" R="/opt/${1/acl2/acl2r}"
  (cd "$A/books" && build/cert.pl -j "$J" --acl2 "$A/saved_acl2" \
     std/top.lisp arithmetic/top-with-meta.lisp arithmetic-5/top.lisp ihs/ihs-lemmas.lisp misc/records.lisp \
     projects/groups/groups.lisp projects/linear/*.lisp projects/numbers/fermat.lisp \
     centaur/fty/top.lisp kestrel/fty/top.lisp std/omaps/top.lisp kestrel/crypto/aes/aes-spec.lisp \
     centaur/gl/gl.lisp centaur/bitops/top.lisp kestrel/bv/top.lisp std/util/top.lisp projects/rac/lisp/*.lisp)
  (cd "$R/books" && build/cert.pl -j "$J" --acl2 "$R/saved_acl2r" \
     arithmetic-5/top.lisp arithmetic/factorial.lisp nonstd/nsa/*.lisp nonstd/integrals/*.lisp \
     nonstd/circles/*.lisp $(find nonstd -name '*.lisp' -path '*reid-gamboa-differentiator*'))
}

build acl2 8.7;                    certify acl2
build acl2-master 1d2b39a424;      certify acl2-master
(cd /opt/acl2-master/books && build/cert.pl -j "$J" projects/set-theory/top.lisp)

cd /opt
tar --exclude=.git --exclude='workxxx.*' -cf - acl2 acl2r | zstd -T"$J" -10 -o acl2-8.7.tar.zst
tar --exclude=.git --exclude='workxxx.*' -cf - acl2-master acl2r-master | zstd -T"$J" -10 -o acl2-master-1d2b39a424.tar.zst
sha256sum acl2-*.tar.zst
