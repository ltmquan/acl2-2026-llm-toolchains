# Prebuilt ACL2 toolchains for cloud sessions

Prebuilt ACL2 and ACL2(r) images with pre-certified community books, so that a short setup script can
install them in a few minutes instead of building them. Everything here is built from the public
[ACL2 repository](https://github.com/acl2/acl2); nothing else is included.

## Bundles (release assets)

| Release | Contents | Unpacks to |
|---|---|---|
| `acl2-8.7` | ACL2 8.7 and ACL2(r) 8.7 (SBCL 2.2.9), git history removed | `/opt/acl2`, `/opt/acl2r` |
| `acl2-master-1d2b39a424` | ACL2 and ACL2(r) at master commit `1d2b39a424` (2026-11-12) | `/opt/acl2-master`, `/opt/acl2r-master` |

Both contain certificates for `std`, `arithmetic`, `arithmetic-5`, `ihs`, `misc/records`, `projects/groups`,
`projects/linear`, `projects/numbers/fermat`, FTY (`centaur` and `kestrel`), `std/omaps`, the AES
specification, GL, `bitops`, `kestrel/bv`, `projects/rac/lisp`, and, for ACL2(r), `nonstd`. The master bundle
also has `projects/set-theory` certified. `build/build-bundles.sh` shows exactly how they were made.

The images contain absolute paths, so they must be unpacked under `/opt`. They need the `sbcl` package from
Ubuntu 24.04 (SBCL 2.2.9).

## Use

```bash
curl -fsSL https://raw.githubusercontent.com/ltmquan/acl2-llm-toolchains/main/setup/install.sh | bash -s -- --acl2 8.7 --apt "z3"
```

`setup/install.sh` installs the bundle, links `acl2`, `acl2r` and `cert.pl` into `/usr/local/bin`, can install
extra apt or pip packages and delete book directories, checks SHA-256 sums, and prints a network probe.
