#!./test/libs/bats/bin/bats

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'

setup_file() {
	# Get tests dir
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
   
    # Export local_dir (expected in genome_updater) to get local files when testing
	local_dir="$DIR/files/"
	export local_dir

	# Setup output folder for tests
	outprefix="$DIR/results/"
	rm -rf $outprefix
	mkdir -p $outprefix
	export outprefix
}

@test "Run genome_updater.sh and show" {
    run ./genome_updater.sh -h
    assert_success
}

@test "Basic refseq" {
	outdir=${outprefix}basic-refseq/
    run ./genome_updater.sh -d refseq -o ${outdir}
    assert_success
    assert_link_exist ${outdir}assembly_summary.txt
}

@test "Basic genbank" {
	outdir=${outprefix}basic-genbank/
    run ./genome_updater.sh -d genbank -o ${outdir}
    assert_success
    assert_link_exist ${outdir}assembly_summary.txt
}

@test "Basic refseq,genbank" {
	outdir=${outprefix}basic-refseq-genbank/
    run ./genome_updater.sh -d refseq,genbank -o ${outdir}
    assert_success
    assert_link_exist ${outdir}assembly_summary.txt
}
