# RuboCop Spinel [![ci](https://github.com/gurgeous/rubocop_spinel/actions/workflows/ci.yml/badge.svg)](https://github.com/gurgeous/rubocop_spinel/actions/workflows/ci.yml)

Custom cops for [Spinel](https://github.com/matz/spinel), so a CRuby codebase can stay Spinel-ready without running the Spinel compiler.

| Cop                  | Flags                                                                                     |
| -------------------- | ----------------------------------------------------------------------------------------- |
| `Spinel/Unsupported` | Ruby that Spinel refuses to compile, or compiles into a `NoMethodError` / `NameError`      |
| `Spinel/Divergence`  | Ruby that Spinel compiles, but that behaves differently from CRuby at runtime             |

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
require "date"

class Stack < Array
  def method_missing(name, *args) = super
end

buf = ""
buf << "x"
```

```
sample.rb:1:1: C: Spinel/Unsupported: Spinel does not provide `require "date"`.
sample.rb:3:15: C: Spinel/Unsupported: Spinel does not support subclassing `Array`; wrap it in an instance variable.
sample.rb:4:3: C: Spinel/Divergence: Spinel never calls `method_missing`; an undefined method raises NoMethodError.
sample.rb:8:5: C: Spinel/Divergence: Spinel freezes string literals; start from `+""` or `String.new`.
```

## What gets flagged

**Spinel/Unsupported**

- string `eval` / `instance_eval`, and string `class_eval` on an explicit receiver (the block forms are fine)
- `remove_method`, `undef_method`, `remove_const`, `singleton_method`, `define_method` with a runtime name
- `extend` / `def obj.m` / `class << obj` on an object Spinel can't trace to one `Klass.new`
- changing a class from outside its body (`Klass.include M`, `Klass.attr_accessor :x`)
- subclassing builtins (`Array`, `Hash`, `String`, ...), non-constant superclasses and mixins
- `binding`, `ObjectSpace`, `TracePoint`, refinements, `callcc`, `fork`, `load`, `IO.popen`, flip-flops
- reflection with runtime names (`instance_variable_get(name)`, `alias_method name, ...`)
- `require` of stdlib that Spinel does not ship (`date`, `yaml`, `timeout`, ... see `UnsupportedRequires`), and `DidYouMean`, which CRuby loads without one
- `private_methods` / `protected_methods`, and receiverless `methods` / `respond_to?` at the top level
- `Time.parse`, `Time.iso8601`, `Time.strptime` and friends, which compile after `require "time"` but are missing
- a Method of a native package function, like `&Base64.method(:strict_decode64)` (autocorrected)
- `slice_before` / `slice_after` with a Proc (autocorrected)
- assigning a constant in a condition (`if (CONFIG = load)`) (autocorrected)

`rubocop -a` rewrites those three where the result behaves the same on CRuby: `{ Base64.strict_decode64(it) }` for a single-value iterator (`_1` below Ruby 3.4), a brace block for a lambda without `return` / `break`, and the assignment moved ahead of an `if` that is its own statement.

**Spinel/Divergence**

- `method_missing` / `respond_to_missing?`, and the `inherited` / `method_added` / `const_missing` / `prepended` hooks
- mutating a string literal (unless the file has `# frozen_string_literal: true`)
- `defined?(super)`, `caller` / `backtrace`, non-UTF-8 encodings, `grapheme_clusters`, aliased regexp globals
- `__dir__` and `__FILE__` used as paths, which Spinel resolves at compile time rather than to the executable
- `rescue Interrupt` / `SignalException` without a `Signal.trap("INT")`, since Ctrl-C kills a Spinel program outright

**Spinel/SystemLibrary** (disabled by default)

- `require "openssl"`, which links the system's libssl dynamically, so the executable only runs where that library is installed

Code that a `RUBY_ENGINE` check rules out under Spinel is skipped, the same way Spinel drops it:

```rb
if RUBY_ENGINE == "spinel"
  fast_path
else
  eval(code) # not flagged
end
```

## Configuration

`Spinel/Unsupported` takes an `UnsupportedRequires` list of stdlib names, if Spinel starts shipping one before this gem catches up, and an `AllowedRequires` list of features your project provides itself, eg. as spin packages. `Spinel/Divergence` takes an `InterruptRequires` list of features that trap SIGINT to raise `Interrupt`.

```yml
Spinel/Unsupported:
  AllowedRequires: [did_you_mean, shellwords, yaml] # spin packages of our own
Spinel/Divergence:
  InterruptRequires: [sigint_interrupt]
```

## Changelog

#### 0.3.0 (Oct '26)

- resynced with Spinel `2026.09.12+5918`
- allow threads, `send` / `public_send`, `const_get`, `prepend`, `class << self`, `extend`, `module_function :name` and block `class_eval`
- flag compile-time refusals: builtin subclasses, `binding`, `ObjectSpace`, refinements, unsupported `require`s, and more
- new `Spinel/Divergence` cop for code that compiles but behaves differently
- skip code ruled out by a `RUBY_ENGINE` check
- flag code that compiles but raises when reached: `private_methods`, `DidYouMean`, `Time.parse` and friends
- flag constant assignment in conditions and Methods of native package functions
- flag `__dir__` / `__FILE__` paths and `Interrupt` rescues without an INT trap
- `AllowedRequires` and `InterruptRequires` settings for features a project provides itself
- new `Spinel/SystemLibrary` cop (disabled by default) for `require "openssl"`
- autocorrect native Method objects, Proc patterns and constant assignment in conditions

#### 0.2.0 (May '26)

- allow `recv.instance_eval { ... }` ([Spinel #15](https://github.com/matz/spinel/pull/15))
- allow `def m(&block); instance_eval(&block); end` ([Spinel #124](https://github.com/matz/spinel/pull/124))
- allow static `define_method(:name) { ... }` ([Spinel 26e6aae](https://github.com/matz/spinel/commit/26e6aae))
- allow no-argument `module_function` in module bodies ([Spinel #295](https://github.com/matz/spinel/pull/295))
- allow module singleton accessors ([Spinel #126](https://github.com/matz/spinel/issues/126))

#### 0.1.0 (Apr '26)

- first release
