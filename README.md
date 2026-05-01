# RuboCop Spinel [![ci](https://github.com/gurgeous/rubocop_spinel/actions/workflows/ci.yml/badge.svg)](https://github.com/gurgeous/rubocop_spinel/actions/workflows/ci.yml)

Custom cop for [Spinel](https://github.com/matz/spinel), warns on Ruby code that is not (yet) supported by Spinel.

## Installation

```rb
# add to Gemfile
gem "rubocop_spinel"
```

```yml
# add to rubocop.yml
plugins:
  - rubocop_spinel
```

## Example Errors

```rb
class Example
  class << self
    def bad
      42
    end
  end
end

Thread.new { puts Example.bad }
```

```
sample.rb:2:3: C: Spinel/Unsupported: Spinel does not support singleton classes.
class << self ...
^^^^^^^^^^^^^
sample.rb:9:1: C: Spinel/Unsupported: Spinel does not support threads or mutexes.
Thread.new { puts Example.bad }
^^^^^^
```

## Changelog

#### 0.0.2 (unreleased)

- allow `recv.instance_eval { ... }` ([Spinel #15](https://github.com/matz/spinel/pull/15))
- allow `def m(&block); instance_eval(&block); end` ([Spinel #124](https://github.com/matz/spinel/pull/124))
- allow static `define_method(:name) { ... }` ([Spinel 26e6aae](https://github.com/matz/spinel/commit/26e6aae))
- allow module singleton accessors ([Spinel #126](https://github.com/matz/spinel/issues/126))

#### 0.0.1 (Apr '26)

- first release
