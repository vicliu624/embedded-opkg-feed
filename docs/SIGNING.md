# Signing and publication policy

[中文](SIGNING.zh-CN.md) | English (current)

## Key roles

| Key | Location | Purpose |
| --- | --- | --- |
| Private release key | Offline signing host, HSM, or protected self-hosted runner | Signs `Packages.gz` |
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
Packages.gz
Packages.gz.asc
```

`offline-sign-gpg-index.sh` is intentionally for a protected signing host. It
does not generate a key and refuses to run without an explicit key fingerprint.

The exact target opkg configuration is deliberately not written here: the
currently installed target build reports that GPG signature checking is not
supported. Add `check_signature` and the backend-specific configuration only
after the new firmware's integration test has validated its expected suffix,
keyring location, and rejection behaviour.

## Immutable releases

Never overwrite an already published feed directory. A new ABI or firmware
contract gets a new `PLATFORM_ID`. An application-only release may add packages
or higher versions to the same feed only after its signed index and all files
have passed review.

The `release` branch must require review. Publishing directly from `main`
would allow a build change to become a device update without a release gate.

Community pull requests never publish a feed. They can only become public
downloads after package review, matching-platform validation, a protected
release-branch change, and offline signing.
