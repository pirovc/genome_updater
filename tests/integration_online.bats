#!/usr/bin/env bash

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'utils.bash'

setup_file() {
    # Get tests dir
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"

    files_dir="$DIR/files/"
    export files_dir

    # Setup output folder for tests
    outprefix="$DIR/results/integration_online/"
    rm -rf $outprefix
    mkdir -p $outprefix
    export outprefix

    # Threads to use
    threads=4
    export threads
}

@test "DB refseq online" {
    outdir=${outprefix}db-refseq-online/
    label="test"

    # Protozoa in refseq is the smallest available assembly_summary at the time of writing this test (01.2022)
    run ./genome_updater.sh -d refseq -g protozoa -b ${label} -t ${threads} -o ${outdir}
    sanity_check ${outdir} ${label}

    # Check filenames
    for file in $(ls_files ${outdir} ${label}); do
        [[ "$(basename $file)" = GCF* ]] # filename starts with GCF_
    done
}

@test "NA URL" {
    outdir=${outprefix}na-url/
    label="test"
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -t ${threads} -e ${files_dir}simulated/assembly_summary_na_url.txt
    sanity_check ${outdir} ${label}
}

@test "All invalid URLs" {
    outdir=${outprefix}all-invalid-url/
    label="test"
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -t ${threads} -e ${files_dir}simulated/assembly_summary_all_invalid_url.txt
    assert_success
    assert_equal $(count_files ${outdir} ${label}) 0
}

@test "Some invalid URLs" {
    outdir=${outprefix}some-invalid-url/
    label="test"
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -t ${threads} -e ${files_dir}simulated/assembly_summary_some_invalid_url.txt
    assert_success
    assert_equal $(count_files ${outdir} ${label}) 2
}


@test "Multiple file types" {
    outdir=${outprefix}multiple-file-types/
    label="test"

    # archaea has a relative small assembly_summary
    # taxid 2180 small archaeal genome (as of 01.2022)
    # Get one assembly for the species (3 file types)
    run ./genome_updater.sh -d refseq -g archaea -S 2180 -P 1 -b ${label} -t ${threads} -o ${outdir} -f "assembly_report.txt,protein.faa.gz,genomic.fna.gz"
    sanity_check ${outdir} ${label} 3
}

@test "Leaf taxids" {
    outdir=${outprefix}leaf-taxids/
    label="test"

    # 5690 Trypanosoma genus - around 6 genomes, get only one per species (01.2022)
    run ./genome_updater.sh -d refseq -g protozoa -T 5690 -P 1 -b ${label} -o ${outdir} -t ${threads} 
    sanity_check ${outdir} ${label}

    # Get counts of species taxids on output
    txids_ret=$(get_values_as ${outdir}assembly_summary.txt 7 )
    ret_occ=( $( echo ${txids_ret}  | tr ' ' '\n' | sort | uniq -c | awk '{print $1}' ) )
   
    # Should have one assembly for each species taxid
    for occ in ${ret_occ[@]}; do
        assert_equal ${occ} 1
    done
}

@test "MD5 verbose log" {
    outdir=${outprefix}md5-verbose-log/
    label="test"

    # 5693 Trypanosoma cruzi
    run ./genome_updater.sh -d refseq -g protozoa -S 5693 -P 1 -b ${label} -o ${outdir} -t ${threads} -m -V
    sanity_check ${outdir} ${label}

    # Check if MD5 is verified
    grep -m 1 "MD5 successfully checked" ${outdir}${label}/*.log
    assert_success
}

@test "GTDB assemblies" {
    outdir=${outprefix}gtdb-assemblies/
    label="test"

    # 5693 Trypanosoma cruzi
    run ./genome_updater.sh -d refseq -e ${files_dir}simulated/assembly_summary_gtdb.txt -b ${label} -o ${outdir} -t ${threads} -z
    sanity_check ${outdir} ${label}

    # 1 out of 2 available on GTDB
    assert_equal $(count_files ${outdir} ${label}) 1
}

@test "Download taxdump" {
    outdir=${outprefix}download-taxdump/
    label="test"

    run ./genome_updater.sh -d refseq -g protozoa -S 5693 -P 1 -b ${label} -o ${outdir} -t ${threads} -a
    sanity_check ${outdir} ${label}

    # Downloaded taxdump
    assert_file_exist ${outdir}${label}/taxdump.tar.gz
}