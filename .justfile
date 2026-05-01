default: test

#
# hygiene
#

check: lint test
  just banner "✓ check ✓"

ci: check

fmt:
  bundle exec rubocop -a

lint:
  bundle exec rubocop

pry:
  pry -I lib -r rubocop_spinel.rb

test:
  rake test

test-spinel:
  bundle exec rubocop -c test/test_spinel.yml -r ./lib/rubocop_spinel --only Spinel/Unsupported \
    ../spinel/test ../spinel/benchmark/bm_send_bmethod.rb ../spinel/spinel_codegen.rb

test-watch *ARGS:
  watchexec --stop-timeout=0 --clear clear just test "{{ARGS}}"

#
# gem stuff
#

gemver := `cat lib/rubocop/spinel/version.rb | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+"`
gemout := "tmp/rubocop_spinel-" + gemver + ".gem"

check-git-status:
  if [ ! -z "$(git status --porcelain)" ]; then echo "git status is dirty, bailing."; exit 1; fi

gem-build: check
  mkdir -p tmp
  rm -f tmp/*.gem
  gem build --output {{gemout}}
  just banner "✓ gem-build ✓"

gem-install: gem-build
  gem install {{gemout}}
  just banner "✓ gem-install ✓"

gem-push: check-git-status gem-build
  just banner "tagging..." && git tag -a "v{{gemver}}" -m "Tagging {{gemver}}" && git push --tags
  just banner "pushing..." && gem push {{gemout}}
  just banner "✓ gem-push ✓"

#
# util
#

set quiet

banner +ARGS:  (_banner '\e[48;2;064;160;043m' ARGS)
warning +ARGS: (_banner '\e[48;2;251;100;011m' ARGS)
fatal +ARGS:   (_banner '\e[48;2;210;015;057m' ARGS)
  exit 1
_banner BG +ARGS:
  printf '\e[38;5;231m{{BOLD+BG}}[%s] %-72s {{NORMAL}}\n' "$(date +%H:%M:%S)" "{{ARGS}}"
