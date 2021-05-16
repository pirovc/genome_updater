#!./test/libs/bats/bin/bats

load 'libs/bats-support/load'
load 'libs/bats-assert/load'

# Export base_url to get local files
base_url=$(pwd)/files/
export base_url

@test "Run tests with local assembly_summary.txt" {
	./genome_updater.sh -d refseq -k
    #assert_equal $? 0
    assert_success
}
