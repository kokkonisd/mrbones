# Release checklist
1. Ensure local `main` is up to date with respect to `origin/main`.
2. Run pre-commit checks:
   ```console
   $ pre-commit run --all-files
   ```
3. Run the testsuite:
   ```console
   $ make tests
   ```
   All tests should pass.
4. Update the `VERSION` field in `mrbones.sh`.
5. Update `CHANGELOG.md`.
6. Install `mrbones` via `make install` (if you wish to not overwrite a locally installed
   `mrbones`, set `DESTDIR` to some temporary test directory). Make sure it succeeded by running
   `which mrbones` (or checking the temporary directory where you installed it). Run
   `mrbones --version` and ensure that the expected version is printed. Uninstall it via `make
   uninstall` and make sure the operation succeeds.
7. Commit the changes and tag the commit with the version. For example, for version `X.Y.Z`, tag
   the commit with `git tag -a X.Y.Z`.
8. Push the commit **without pushing the tags**. Wait for the CI to finish, and continue to the
   next steps only if the CI succeeds.
9. Push the tag with `git push --tags`.
10. Prepare for the next version by bumping the PATCH number and appending `"-dev"` in the version
    (`VERSION`) field in `mrbones.sh`. This means that `"1.2.3"` should become `"1.2.4-dev"`.
