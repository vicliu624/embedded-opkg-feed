# Signing and publication policy

[中文](SIGNING.zh-CN.md) | English (current)

## Key roles

| Key | Location | Purpose |
| --- | --- | --- |
| Private release key | Offline signing host, HSM, or protected self-hosted runner | Signs the package-index payloads |
| Public release key | `keys/tdvp-repo-public.asc` and next base firmware | Verifies releases |
| GitHub deployment token | Ephemeral GitHub Actions OIDC token | Publishes static, already signed files |

Only the public key may be committed. The private release key must not appear
in Git, GitHub Actions logs, GitHub Actions secrets, the device, or Pages.

The current public release-key fingerprint is:

```text
2B091A2A8E5810954FB9FD64EA9D1CD5EFC81500
```

Verify this full fingerprint before embedding
`keys/tdvp-repo-public.asc` into a firmware image or trusting a copied key.

## GPG index-signing contract

The skeleton uses detached ASCII-armoured GPG signatures as the initial
release contract:

```text
Packages
Packages.asc
Packages.gz
Packages.gz.asc
```

`offline-sign-gpg-index.sh` is intentionally for a protected signing host. It
does not generate a key and refuses to run without an explicit key fingerprint.

The TDVP K230 r1 base image uses this `gpg-asc` contract with
`check_signature 1`, `/etc/opkg/gpg`, and the lazy `/usr/local/sbin/tdvp-opkg`
wrapper. The wrapper imports only the embedded public key immediately before
an operator invokes opkg; it is intentionally not a `greetd` or desktop boot
service. Firmware verification must prove both expected suffixes, the keyring
location, and all signature rejection cases before a release is published.

## Immutable releases

Never overwrite an already published feed directory. A new ABI or firmware
contract gets a new `PLATFORM_ID`. Even when the ABI is unchanged, adding an
application, shared runtime, or index requires a new immutable feed revision,
for example `site/feed/<PLATFORM_ID>/r2/riscv64/`. The published r1 path is
never re-signed or replaced.

The `release` branch must require review. Publishing directly from `main`
would allow a build change to become a device update without a release gate.

Community pull requests never publish a feed. They can only become public
downloads after package review, matching-platform validation, a protected
release-branch change, and offline signing.
