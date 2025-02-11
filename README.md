# mrbones
A bare-bones static site generator in the form of a **single bash script**.

## Installation
### Dependencies
Currently, `mrbones` is only supported on Linux systems. It has the following dependencies:
- [GNU sed](https://www.gnu.org/software/sed/)
- realpath (from [GNU coreutils](https://www.gnu.org/software/coreutils/))
- find (from [GNU findutils](https://www.gnu.org/software/findutils/))

You can use the [Makefile](./Makefile) to install/uninstall `mrbones`:
```console
$ sudo make install    # you can also use DESTDIR to specify *where* to install
$ sudo make uninstall  # if you defined an alternative DESTDIR during installation, \
                       # you'll have to specify it here too
```

## Use
TODO

## License
`mrbones` by Dimitri Kokkonis is licensed under a [Creative Commons Attribution-ShareAlike 4.0
International License](https://creativecommons.org/licenses/by-sa/4.0/).
