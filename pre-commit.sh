#!/usr/bin/env bash

if shellcheck genome_updater.sh
then
    echo "shellcheck found no issues!"
fi

echo -e "SimpleCov.start do\n  add_filter 'tests/'\nend" > .simplecov
bashcov --skip-uncovered tests/libs/bats/bin/bats tests/integration_offline.bats
