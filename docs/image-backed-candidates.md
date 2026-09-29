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
separate operation. `verify-runtime-closure.sh` and
`verify-target-runtime-coverage.sh` validate the report through
`materialize_image_references.py` before treating referenced files as providers.
The expected manifest digest comes from `IMAGE_OWNERSHIP_MANIFEST_SHA256` in the
selected platform lock. Report hashes, exact owner requirements, canonical paths,
remaining payload contents and actual image-file metadata must all match.
Verified files are copied only into disposable audit roots; the IPKs and base
image remain untouched. Original ELF dependency, RPATH and unique-provider checks
then run over these audit roots.

```sh
bash scripts/verify-runtime-closure.sh --platform tdvp-k230-r1 \
  --base-root "$MATCHING_IMAGE_ROOT" "$NEW_CANDIDATE_DIRECTORY"
bash scripts/verify-target-runtime-coverage.sh --platform tdvp-k230-r1 \
  --base-root "$MATCHING_IMAGE_ROOT" "$NEW_CANDIDATE_DIRECTORY"
```

Run the filesystem and composition tests with Python 3.12 or newer:

```sh
python3 tests/image-backed-payload.py
python3 tests/image-reference-audit.py
TDVP_TEST_OPKG=/path/to/patched/native/opkg python3 tests/image-backed-compose.py
```

The native test uses isolated offline roots and inert package files. It verifies
installation, removal, exact owner constraints and base protection. It does not
execute RISC-V applications or replace real device validation. The portable CI
job runs archive and metadata tests; the native transaction case requires the
explicit binary above and otherwise reports a skip.

## Final candidate entry point

`scripts/finalize-image-backed-feed.sh` combines input index verification,
composition, output index verification, reference-aware runtime closure and
coverage, and the released SDK's ELF policy for every delivered payload. It
requires a previously verified matching SDK and a raw indexed candidate:

```sh
TDVP_SDK_ROOT="$MATCHING_SDK" bash scripts/finalize-image-backed-feed.sh \
  --platform tdvp-k230-r1 --base-root "$MATCHING_IMAGE_ROOT" \
  --source "$RAW_INDEXED_CANDIDATE" --output "$NEW_FINAL_DIRECTORY"
```

The destination must not exist. Intermediate artifacts remain in a temporary
sibling directory until all checks pass; a failing check removes that temporary
directory. The raw source IPKs remain unchanged and must be retained for future
incremental composition. This entry point does not sign, promote or deploy a
feed. Maintenance-image and device acceptance remain separate release gates.
