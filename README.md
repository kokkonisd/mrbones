# mrbones

A bare-bones static site generator in the form of a **single Bash script**.

## Installation

### Dependencies

Currently, `mrbones` is only supported on Linux systems. It has the following dependencies:

- [GNU sed](https://www.gnu.org/software/sed/)
- realpath (from [GNU coreutils](https://www.gnu.org/software/coreutils/))
- find (from [GNU findutils](https://www.gnu.org/software/findutils/))
- [GNU Make](https://www.gnu.org/software/make/) (optionally, if you wish to use the Makefile)
- [pre-commit](https://pre-commit.com/) (optionally, if you wish to run local tests or develop)

You can use the [Makefile](./Makefile) to install/uninstall `mrbones`:

```console
$ sudo make install    # you can also use DESTDIR to specify *where* to install
$ sudo make uninstall  # use same DESTDIR as for `make install`
```

## Use

You can invoke `mrbones` like so:

```console
$ mrbones [option(s)] [root_site_dir]
```

If not specified, `[root_site_dir]` defaults to `.` (the current directory). You can see the options
by running `mrbones --help`.

By default, `mrbones` will copy everything in the `root_site_dir` to a new directory called
`_site/`, which will contain the generated static site. However, HTML templates can be used to make
development easier. These can be put under `_templates/` in `root_site_dir`. This directory is
special to `mrbones` and will not be copied verbatim; instead, templates can be put in there, that
may be used by other pages. These enable the following _directives_:

- `@include <FILE>`. The _include_ directive copies a template file verbatim into the file that
  contains it. For example, consider two pages:
  - `_templates/main.html` containing `"hello!"`;
  - `index.html` containing `"@include main.html\ngoodbye!"`. The generated `_site/index.html` page
    will contain `"hello!\ngoodbye!"`, as `_templates/main.html` was included in `index.html`. Note
    that there should be **at most one** include directive **per line**, and the line should not
    contain anything else.
- `@use <FILE>`. The _use_ directive fills in a template with the content of another page. For
  example, consider two pages:
  - `_templates/main.html` containing `"<html>@content</html>"`;
  - `index.html` containing `"@use main.html\nhello!"`. The generated `_site/index.html` page will
    contain `"<html>hello!</html>"`, as `index.html` was used to fill the `_template/main.html`
    template. Note that there should be **at most one** use directive **per line**, and the line
    should not contain anything else. In addition, the template used in the use directive must
    contain **at least one** `@content` directive, to indicate where the page's content should be
    placed. Multiple `@content` directives will lead to the page's content being placed in multiple
    parts of the template.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md).

## License

`mrbones` by Dimitri Kokkonis is licensed under a
[Creative Commons Attribution-ShareAlike 4.0 International License](https://creativecommons.org/licenses/by-sa/4.0/).
