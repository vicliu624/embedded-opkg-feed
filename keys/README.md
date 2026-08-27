# Repository public key

Commit exactly one ASCII-armoured repository public key as:

```text
keys/tdvp-repo-public.asc
```

The current release key fingerprint is:

```text
2B091A2A8E5810954FB9FD64EA9D1CD5EFC81500
```

Before trusting a copied key, compare its full fingerprint rather than its
short key ID:

```sh
gpg --show-keys --with-fingerprint keys/tdvp-repo-public.asc
```

当前发布公钥的完整指纹为：

```text
2B091A2A8E5810954FB9FD64EA9D1CD5EFC81500
```

导入或内置公钥前，请比对完整指纹，而不是短 key ID。

It is safe and required to publish the public key. Do not commit private keys,
revocation certificates, exported secret keyrings, passphrases, or GitHub
tokens.

The Pages workflow refuses to deploy a feed unless this file verifies the
detached `Packages.gz.asc` signature.
