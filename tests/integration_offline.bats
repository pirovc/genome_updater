#!./test/libs/bats/bin/bats

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'

setup_file() {
    # Get tests dir
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
   
    # Export local_dir to use local files instead of ncbi ftp when testing
    local_dir="$DIR/files/"
    export local_dir

    # Setup output folder for tests
    outprefix="$DIR/results/"
    rm -rf $outprefix
    mkdir -p $outprefix
    export outprefix
}

get_values_as() { # $1 assembly_summary file, $2 col
    grep -v "^#" ${1} | cut -f $2
}

count_lines_file(){ # $1 file
    sed '/^\s*$/d' ${1:-} | wc -l | cut -f1 -d' '
}

count_files() { # $1 outdir, $2 label
    ls_files ${outdir} ${label} | wc -l | cut -f1 -d' '
}

ls_files() { # $1 outdir, $2 label
    ls -1 ${1}${2}/files/*
}

sanity_check() { # $1 outdir, $2 label
    #
    # Check if run was successful and if default files were created
    #
    # Ran successfully
    assert_success
    # Created assembly_summary file 
    assert_file_exist ${1}${2}/assembly_summary.txt
    # Created link to current version of assembly_summary
    assert_link_exist ${1}assembly_summary.txt
    # Created log file
    assert_file_exist ${1}${2}/*.log
    # Created files folder
    assert_dir_exist ${1}${2}/files
    # Check file count based on assembly_summary
    assert_equal $(count_files ${1} ${2}) $(count_lines_file ${1}assembly_summary.txt)
    # Check files in folder (if any)
    for file in $(ls_files ${outdir} ${label}); do
        assert_file_not_empty $file
    done

}

@test "Run genome_updater.sh and show help" {
    run ./genome_updater.sh -h
    assert_success
}

@test "DB refseq" {
    outdir=${outprefix}db-refseq/
    label="test"
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # Check filenames
    for file in $(ls_files ${outdir} ${label}); do
        [[ "$(basename $file)" = GCF* ]] # filename starts with GCF_
    done
}

@test "DB genbank" {
    outdir=${outprefix}db-genbank/
    label="test"
    run ./genome_updater.sh -d genbank -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
    
    # Check filenames
    for file in $(ls_files ${outdir} ${label}); do
        [[ "$(basename $file)" = GCA* ]] # filename starts with GCA_
    done
}

@test "DB refseq and genbank" {
    outdir=${outprefix}db-refseq-genbank/
    label="test"
    run ./genome_updater.sh -d refseq,genbank -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
}

@test "Organism group archaea" {
    outdir=${outprefix}og-archaea/
    label="test"
    run ./genome_updater.sh -o archaea -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
}

@test "Organism group archaea and fungi" {
    outdir=${outprefix}og-archaea-fungi/
    label="test"
    run ./genome_updater.sh -o archaea,fungi -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
}

@test "Species taxids" {
    outdir=${outprefix}species-taxids/
    label="test"
    # Get all possible taxids from base assembly_summary
    txids=( $(get_values_as ${local_dir}genomes/refseq/assembly_summary_refseq.txt 7 ) )

    # Use third
    run ./genome_updater.sh -S "${txids[2]}" -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # Check if output contains only used taxids
    txids_ret=( $(get_values_as ${outdir}assembly_summary.txt 7 ) )

    # Used taxid should be the only one 
    assert_equal ${#txids_ret[@]} 1 #length
    assert_equal ${txids[2]} ${txids_ret[0]} #same taxid 
}




