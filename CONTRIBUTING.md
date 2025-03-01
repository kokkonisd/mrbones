# Contributing to `mrbones`

Thank you for taking the time to contribute to `mrbones`!

Before setting out to contribute new features or bug fixes, please make sure to:

1. Read the instructions detailed below;
2. Create an issue in the [issue tracker](https://github.com/kokkonisd/mrbones/issues);
3. Read [tests/README.md](./tests/README.md) to understand how the testuite works.

## A few words on the scope of `mrbones`

The main "philosophy" behind `mrbones` is to have a static site generator that's as compact,
dependency-free and config-free as possible! At the same time, we want to protect against bugs, so
some extra code will be tolerated for that use case :)

- Example of an out-of-scope contribution: adding a SCSS/Sass parser
- Example of an in-scope contribution: fix vulnerability caused by how `mrbones` deals with
  permalinks

## Setting up the development environment

First of all, you should set up an adequate development environment. This means that you need:

- **A relatively recent version of Bash**. At the time of writing, I'm using version
  `5.2.21(1)-release`, but anything more recent than version `5` should probably be okay.
- [GNU sed](https://www.gnu.org/software/sed/)
- realpath (from [GNU coreutils](https://www.gnu.org/software/coreutils/))
- find (from [GNU findutils](https://www.gnu.org/software/findutils/))
- [pre-commit](https://pre-commit.com/)
- [GNU Make](https://www.gnu.org/software/make/) (optionally, if you wish to use the Makefile)

Once you have installed all of the dependencies, you should go ahead and fork, then clone the
repository:

```console
$ git clone https://github.com/kokkonisd/mrbones.git
```

You should then `cd` into the repository and run the following command:

```console
$ pre-commit install
```

This should set up the pre-commit hooks. You need to run this command **once per clone**. If you do
not use a different clone of the repository, you won't have to run them again.

Once you are happy with your change, you should also check by running the testsuite:

```console
$ make tests  # or `bash run-tests.sh` if you do not wish to use the Makefile
```

All tests should pass. If you are adding new functionality or fixing a bug, please consider adding a
new test case to cover it.

Once the pre-commit checks pass, you can create a pull request; do not forget to **cite the
corresponding issue**.
