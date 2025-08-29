# mrbones

A bare-bones static site generator in the form of a **single Bash script**.

## Installation

### Dependencies

Currently, `mrbones` is only supported on Linux systems. It has the following dependencies:

- [GNU Bash](https://www.gnu.org/software/bash/) 4.4+
- `realpath` and `sort` (from [GNU coreutils](https://www.gnu.org/software/coreutils/))
- `find` (from [GNU findutils](https://www.gnu.org/software/findutils/))
- [GNU Make](https://www.gnu.org/software/make/) (optionally, if you wish to use the Makefile)
- [pre-commit](https://pre-commit.com/) (optionally, if you wish to run local tests or develop)

You can use the [Makefile](./Makefile) to install/uninstall `mrbones`:

```console
$ sudo make install    # you can also use DESTDIR to specify *where* to install
$ sudo make uninstall  # use same DESTDIR as for `make install`
```

## Use

See the [documentation](https://kokkonisd.github.io/mrbones).

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md).

## License

`mrbones` by Dimitri Kokkonis is licensed under a
[Creative Commons Attribution-ShareAlike 4.0 International License](https://creativecommons.org/licenses/by-sa/4.0/).
