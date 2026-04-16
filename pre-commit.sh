#!/usr/bin/env bash
# conda install go-shfmt shellcheck ruby
# gem install bashcov codecov

echo "formatting code with shfmt"
shfmt --binary-next-line --func-next-line --indent 4 --write genome_updater.sh
shfmt --binary-next-line --func-next-line --language-dialect bats --indent 4 --write tests/*.bats

if shellcheck genome_updater.sh
then
    echo "shellcheck found no issues!"
fi

# Generate local html coverage reports
echo -e "SimpleCov.start do\n  add_filter 'tests/'\nend" > .simplecov
bashcov --skip-uncovered tests/libs/bats/bin/bats tests/integration_offline.bats
