# Package recipe template

Copy this directory to `packages/<package-name>/`, rename
`package.env.example` to `package.env`, and add a `root/` directory containing
the installed payload.

For a native program, add an executable `build.sh` that accepts:

```text
--platform <platform-slug> --sdk-root <path>
```

It must use the pinned target SDK, produce the payload under `root/`, and leave
no generated release artifact in the source tree. See [CONTRIBUTING.md](../../CONTRIBUTING.md).
