# Changelog

# 0.3.0

- Rework `@use` to make it more flexible
- Get rid of the `sed` dependency entirely
- Remove recursive functions to make building considerably faster
- Add documentation

# 0.2.1

- Add missing item in `-h`/`--help`
- Fix a corner-case illegal permalink bug
- Add more thorough testing

# 0.2.0

- Add template page caching ([#3](https://github.com/kokkonisd/mrbones/issues/3))
- Fix escaping ampersand issue ([#1](https://github.com/kokkonisd/mrbones/issues/1))
- Fix subtle backslash (`\`) escaping bug
  ([d4af941](https://github.com/kokkonisd/mrbones/commit/d4af941))
- Clean up and consistent recursive handling of directives (first `@include`s, then `@use`s)
- Add `-dirty` qualifier to build version if appropriate

# 0.1.0

Initial release of `mrbones`.
