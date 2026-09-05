# SQLite 3.48.0 command boundary

sqlite3 owns only the interactive /usr/bin/sqlite3 command. It has exact
runtime dependencies on the separately owned libsqlite3-0, libreadline, and
libncursesw packages. It does not contain libsqlite3.so*, headers, static
libraries, a package-config file, firmware files, or a copied database.

The leaf accepts its command only from the private release staging record
created by libsqlite3-0 while Buildroot 2025.02.1 builds the SHA-256-locked
SQLite 3.48.0 source archive. It checks that the staged command is a RISC-V
ELF which dynamically requires libsqlite3.so.0, removes any runtime search
path, and remains subject to the deny base-overlay policy.

Candidate admission is not release promotion. A K230 device must still verify
sqlite3 --version, create/query a temporary database, uninstall, and rollback
before a signed public feed release can include the package.
