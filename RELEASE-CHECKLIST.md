# Release checklist

01. Ensure local `main` is up to date with respect to `origin/main`.
02. Run pre-commit checks:
    ```console
    $ pre-commit run --all-files
    ```
03. Run the testsuite:
    ```console
    $ make tests
    ```
    All tests should pass.
04. Update the `VERSION` field in `mrbones.sh`.
05. Update `CHANGELOG.md`.
06. Install `mrbones` via `sudo make install` (if you wish to not overwrite a locally installed
    `mrbones`, set `DESTDIR` to some temporary test directory). Make sure it succeeded by running
    `which mrbones` (or checking the temporary directory where you installed it). Run
    `mrbones --version` and ensure that the expected version is printed. Uninstall it via
    `sudo make uninstall` and make sure the operation succeeds.
07. Commit the changes and tag the commit with the version. For example, for version `X.Y.Z`, tag
    the commit with `git tag -a X.Y.Z`.
08. Push the commit **without pushing the tags** via `git push --no-follow-tags`. Wait for the CI to
    finish, and continue to the next steps only if the CI succeeds.
09. Push the tag with `git push --tags`.
10. Prepare for the next version by bumping the PATCH number and appending `"-dev"` in the version
    (`VERSION`) field in `mrbones.sh`. This means that `"1.2.3"` should become `"1.2.4-dev"`.
11. Create the release tarball with the following commands (assume release version is `X.Y.Z`):
    ```console
    $ git checkout X.Y.Z
    $ mkdir -p /tmp/mrbones_X-Y-Z/
    $ make install DESTDIR=/tmp/mrbones_X-Y-Z/
    $ tar -C /tmp/mrbones_X-Y-Z -cJf mrbones.tar.xz mrbones
    ```
    Publish the release using the contents of `CHANGELOG.md` on GitHub and attach the release
    tarball.
