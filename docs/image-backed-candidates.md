# Image-backed candidate composition

Status: local candidate tooling. Public promotion still requires closure,
signature, maintenance-image and device validation; this tool alone does not
establish release readiness.

`scripts/compose_image_backed_feed.py` accepts a previously verified directory
of IPKs, the matching extracted image and the ownership manifest SHA256 from
the platform lock. It produces a new unsigned directory. Existing directories
and input IPKs are never overwritten.

```sh
python3 scripts/compose_image_backed_feed.py \
  --source "$VERIFIED_INPUT_FEED" \
  --image-root "$MATCHING_IMAGE_ROOT" \
  --image-manifest-sha256 "$LOCKED_IMAGE_MANIFEST_SHA256" \
  --output "$NEW_CANDIDATE_DIRECTORY"
```

The composer rechecks image and payload bytes, file permissions, symlinks and
owner records through `image_backed_payload.py`. Matching image files become
exact dependencies on all corresponding `tdvp-image-*` owners. New files remain
in the data archive. Existing image files retain their ownership on installation
and removal. Arbitrary maintainer scripts and unsupported relationship changes
are rejected for explicit review.

Consumers receive updated exact package dependencies. Image-owner alternatives
also receive exact versions, so an older image cannot satisfy them solely by
having the same owner names. This requires the maintenance opkg fix that checks
constraints on held candidates.

Changed packages receive a `+tdvpimg.<digest>` version suffix. Its identity
includes composition format, image manifest and the input IPK hashes in that
package's dependency closure. Adding an unrelated package leaves existing
versions and bytes unchanged. Changes to a dependency's input also invalidate
affected consumer identities. Unaffected IPKs are copied byte-for-byte. New
application payloads are not recompiled during composition.

`image-backed-report.json` records input hashes, generated versions and file
plans. Each changed package carries the image-manifest and plan hashes in its
control metadata; the generated index includes these fields. Signing is a
separate operation. A verifier must validate the report against these hashes
and the locked image before treating image-backed files as runtime providers.

Run the filesystem and composition tests with Python 3.12 or newer:

```sh
python3 tests/image-backed-payload.py
TDVP_TEST_OPKG=/path/to/patched/native/opkg python3 tests/image-backed-compose.py
```

The native test uses isolated offline roots and inert package files. It verifies
installation, removal, exact owner constraints and base protection. It does not
execute RISC-V applications or replace real device validation. The portable CI
job runs archive and metadata tests; the native transaction case requires the
explicit binary above and otherwise reports a skip.
