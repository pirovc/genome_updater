#!/usr/bin/env bash

# apt-get install shellcheck
if shellcheck genome_updater.sh
then
    echo "shellcheck found no issues!"
fi

# mamba install ruby
# gem install bashcov codecov
# To generate local html coverage reports
echo -e "SimpleCov.start do\n  add_filter 'tests/'\nend" > .simplecov
bashcov --skip-uncovered tests/libs/bats/bin/bats tests/integration_offline.bats
