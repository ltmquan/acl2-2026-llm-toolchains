# Prebuilt ACL2 toolchains for cloud sessions

Prebuilt ACL2 and ACL2(r) images with pre-certified community books, so that a short setup script can
install them in a few minutes instead of building them. Everything here is built from the public
[ACL2 repository](https://github.com/acl2/acl2); nothing else is included.

## Bundles (`bundles/`)

| Bundle | Contents | Unpacks to |
|---|---|---|
| `acl2-8.7` | ACL2 8.7 and ACL2(r) 8.7 (SBCL 2.2.9), git history removed | `/opt/acl2`, `/opt/acl2r` |
| `acl2-master-1d2b39a424` | ACL2 and ACL2(r) at master commit `1d2b39a424` (2026-11-12) | `/opt/acl2-master`, `/opt/acl2r-master` |
| `charon-aa29866` | Upstream [Charon](https://github.com/AeneasVerif/charon) at `aa29866` (2026-11-13), with the Rust `nightly-2026-09-17` toolchain it is pinned to (with `rustc-dev`, `rust-src`, `llvm-tools`, `miri`) | `/opt/charon`, `/root/.rustup/toolchains/` |

Both contain certificates for `std`, `arithmetic`, `arithmetic-5`, `ihs`, `misc/records`, `projects/groups`,
`projects/linear`, `projects/numbers/fermat`, FTY (`centaur` and `kestrel`), `std/omaps`, the AES
specification, GL, `bitops`, `kestrel/bv`, `projects/rac/lisp`, and, for ACL2(r), `nonstd`. The master bundle
also has `projects/set-theory` certified. `build/build-bundles.sh` shows exactly how they were made. Each bundle is a `.tar.zst` split into
90 MB parts (GitHub's file limit is 100 MB); `bundles/SHA256SUMS` has the checksum of each whole bundle.

The images contain absolute paths, so they must be unpacked under `/opt`. They need the `sbcl` package from
Ubuntu 24.04 (SBCL 2.2.9).

`inputs/` holds third-party source files that tasks use, unchanged: `aes-0.9.1.crate` is the RustCrypto `aes`
crate 0.9.1 as published on crates.io (MIT/Apache-2.0).

## Use

```bash
curl -fsSL https://raw.githubusercontent.com/ltmquan/acl2-2026-llm-toolchains/main/setup/install.sh | bash -s -- --acl2 8.7 --apt "z3"
```

`setup/install.sh` installs the bundle, links `acl2`, `acl2r` and `cert.pl` into `/usr/local/bin`, can install
extra bundles (`--extra charon`), apt or pip packages and input files, deletes book directories, checks SHA-256
sums, redirects git away from GitHub (except one allowed repository), and prints a network probe.
