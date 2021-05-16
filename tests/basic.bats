#!./test/libs/bats/bin/bats

load 'libs/bats-support/load'
load 'libs/bats-assert/load'

# Export local_dir to get local files when testing
local_dir="tests/files/"
export local_dir

outprefix="tests/results/"
mkdir -p $outprefix

@test "Basic refseq" {
    ./genome_updater.sh -d refseq -o ${outprefix}basic-refseq
    assert_success
}

@test "Basic genbank" {
    ./genome_updater.sh -d genbank -o ${outprefix}basic-genbank
    assert_success
}

@test "Basic refseq,genbank" {
    ./genome_updater.sh -d refseq,genbank -o ${outprefix}basic-refseq-genbank
    assert_success
}
