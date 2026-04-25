# RuboCop Spinel [![test](https://github.com/gurgeous/rubocop-spinel/actions/workflows/test.yml/badge.svg)](https://github.com/gurgeous/rubocop-spinel/actions/workflow>)

Custom RuboCop cops for Spinel compatibility.

### Install

```rb
gem "rubocop-spinel"
```

Or:

```sh
gem install rubocop-spinel
```

### Usage

```rb
require "rubocop_spinel"
```

`.rubocop.yml`:

```yml
plugins:
  - rubocop-spinel
```

Current cops:
- `Spinel/Unsupported`: flags user-facing Ruby features Spinel does not support

### Changelog

#### 0.0.1 (unreleased)
