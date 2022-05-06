# genome_updater tests

genome_updater uses the [bats](https://github.com/bats-core/bats-core) testing framework for Bash.

Use the `download_test_set.sh` to re-create a random set of offline files to test. Files will be downloaded to `files/genomes` and filtered taxonomies to `files/pub/taxonomy/new_taxdump` [ncbi] and `releases/latest` [gtdb].
