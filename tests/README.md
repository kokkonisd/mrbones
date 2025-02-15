# The `mrbones` testsuite
This is the testsuite that `mrbones` is tested against during CI checks and development.

## Dependencies
- [GNU sed](https://www.gnu.org/software/sed/)
- realpath (from [GNU coreutils](https://www.gnu.org/software/coreutils/))
- [curl](https://curl.se/)
- [Python 3](https://www.python.org/) (for the test HTTP server)

## Structure
Each test is put in its own directory. For example, `./permalinks/` contains a single test (which
in this case tests the permalink functionality).
Each test has two types of sub-tests:
- **Baseline tests**: test the output of `mrbones`
- **Output directory structure tests**: test the structure (contents) of the generated site
- **Curl tests**: test the actual generated site

### Source directory
Each test must provide a `src/` directory, containing all material used for the generation of the
site. Essentially, for each test we will run `mrbones <path to test dir>/src/`.

### Baseline tests
Baseline tests are pretty simple, since `mrbones` only prints output in `stderr`.
A baseline test needs a `baseline.err` file, which will contain the expected output (printed in
`stderr`) of `mrbones`. This is used to either verify that the page was generated following an
expected sequence of actions, or that the generation failed expectedly.

If you need to refer to the test directory in the output, and since it can change depending on the
context, you can use the special string `"$TEST_DIR"`, which will expand to the actual test
directory.

**Important notes**:
- The baseline should contain the _verbose_ output; `mrbones` is invoked with `--verbose`.
- There is no need to worry about colors; `mrbones` is invoked with `--color never`.

### Output directory structure tests
Output directory structure tests essentially run `find . | sort` and describe the generated files
in the `_site/` directory. Such a test needs a `baseline.dir` file, which will contain the expected
output of the file command (essentially, a sorted list of files).

If you need to refer to the test directory in the output, and since it can change depending on the
context, you can use the special string `"$TEST_DIR"`, which will expand to the actual test
directory.

### Curl tests
Curl tests run simple HTTP `GET` requests against a test server, which is serving the generated
site (if one could be created). They work in a similar fashion as baseline tests: we provide an
expected baseline (filename ending in `.curl`) and then the test runs the request and compares the
response with the baseline.

If you want to write baselines for files at the root of the site (e.g., `/example.html`), you can
provide their "full path" relative to the root, and just append `.curl` (e.g.,
`example.html.curl`).

If the path is not at the root (e.g., `/foo/bar/baz.html`), you should use double underscores
(`"__"`) instead of slashes (e.g., `foo__bar__baz.html.curl`). Note that there is no need to
prepend a double underscore for the root slash, as all paths are assumed to be absolute.

Here are a few examples of test endpoints/URIs and corresponding baseline files:
- `/bar.html`: `bar.html.curl`
- `/foo/bar/baz.html`: `foo__bar__baz.html.curl`
- `/foo/bar`, `/foo/bar/`: `foo__bar__.curl`

Finally, it is common to create _symbolic links_ between curl baselines when the output is expected
to be exactly the same. For instance, for a page `/foo/bar.html`, `mrbones` will also generate
`/foo/bar/index.html` which is a copy of the previous page. It is good to add tests for both pages,
but to avoid repetition, a test can be added for the first and then a symbolic link to the first
baseline can be added for the second.
