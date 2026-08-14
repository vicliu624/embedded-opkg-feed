# Repository public key

Commit exactly one ASCII-armoured repository public key as:

```text
keys/tdvp-repo-public.asc
```

It is safe and required to publish the public key. Do not commit private keys,
revocation certificates, exported secret keyrings, passphrases, or GitHub
tokens.

The Pages workflow refuses to deploy a feed unless this file verifies the
detached `Packages.gz.asc` signature.
