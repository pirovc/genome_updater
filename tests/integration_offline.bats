#!/usr/bin/env bash

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'utils.bash'

setup_file() {
    # Get tests dir
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
   
    # Export local_dir to use local files offline instead of ncbi ftp online when testing
    local_dir="$DIR/files/"
    export local_dir

    # Setup output folder for tests
    outprefix="$DIR/results/integration_offline/"
    rm -rf $outprefix
    mkdir -p $outprefix
    export outprefix
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
    #echo ${txids[@]} >&3

    # Use third
    run ./genome_updater.sh -S "${txids[2]}" -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # Check if output contains only used taxids
    txids_ret=( $(get_values_as ${outdir}assembly_summary.txt 7 ) )
    #echo ${txids_ret[@]} >&3

    # Used taxid should be the only one 
    assert_equal ${#txids_ret[@]} 1 #length
    assert_equal ${txids[2]} ${txids_ret[0]} #same taxid 
}

@test "Refseq category" {
    outdir=${outprefix}refseq-category/
    label="test"
    # Get all possible refseq category values from base assembly_summary
    rscat=( $(get_values_as ${local_dir}genomes/refseq/assembly_summary_refseq.txt 5 ) )
    #echo ${rscat[@]} >&3

    # Use first
    run ./genome_updater.sh -c "${rscat[0]}" -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # Check if output contains only selected refseq category
    rscat_ret=( $(get_values_as ${outdir}assembly_summary.txt 5 ) )
    #echo ${rscat_ret[@]} >&3

    # Should just return same refseq category
    for rsc in ${rscat_ret[@]}; do
        assert_equal ${rsc} ${rscat[0]}
    done
}

@test "Assembly level" {
    outdir=${outprefix}assembly-level/
    label="test"
    # Get all possible assembly level values from base assembly_summary
    aslev=( $(get_values_as ${local_dir}genomes/refseq/assembly_summary_refseq.txt 12 ) )
    #echo ${aslev[@]} >&3

    # Use first
    run ./genome_updater.sh -l "${aslev[0]}" -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # Check if output contains only selected assembly level
    aslev_ret=( $(get_values_as ${outdir}assembly_summary.txt 12 ) )
    #echo ${aslev_ret[@]} >&3

    # Should just return same assembly level
    for asl in ${aslev_ret[@]}; do
        assert_equal ${asl} ${aslev[0]}
    done
}

@test "Custom filter" {
    outdir=${outprefix}custom-filter/
    label="test"

    # Get all possible assembly level values from base assembly_summary
    rscat=( $(get_values_as ${local_dir}genomes/refseq/assembly_summary_refseq.txt 5 ) )
    aslev=( $(get_values_as ${local_dir}genomes/refseq/assembly_summary_refseq.txt 12 ) )

    # Simulate refseq category and assembly level filter using the custom filter
    run ./genome_updater.sh -F "5:${rscat[0]}|12:${aslev[0]}" -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # Check if output contains only selected refseq category
    rscat_ret=( $(get_values_as ${outdir}assembly_summary.txt 5 ) )
    # Should just return same refseq category
    for rsc in ${rscat_ret[@]}; do
        assert_equal ${rsc} ${rscat[0]}
    done

    # Check if output contains only selected assembly level
    aslev_ret=( $(get_values_as ${outdir}assembly_summary.txt 12 ) )
    # Should just return same assembly level
    for asl in ${aslev_ret[@]}; do
        assert_equal ${asl} ${aslev[0]}
    done
}

@test "Top species" {
    outdir=${outprefix}top-species/
    label="test"
    # Keep only top 1 for selected species
    run ./genome_updater.sh -d refseq,genbank -P 1 -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # Get counts of species taxids on output
    txids_ret=$(get_values_as ${outdir}assembly_summary.txt 7 )
    ret_occ=( $( echo ${txids_ret}  | tr ' ' '\n' | sort | uniq -c | awk '{print $1}' ) )
   
    # Should have one assembly for each species taxid
    for occ in ${ret_occ[@]}; do
        assert_equal ${occ} 1
    done
}

@test "Top taxids" {
    outdir=${outprefix}top-taxids/
    label="test"
    # Keep only top 1 for selected leaf
    run ./genome_updater.sh -d refseq,genbank -A 1 -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # Get counts of leaf taxids on output
    txids_ret=$(get_values_as ${outdir}assembly_summary.txt 6 )
    ret_occ=( $( echo ${txids_ret}  | tr ' ' '\n' | sort | uniq -c | awk '{print $1}' ) )
   
    # Should have one assembly for each leaf taxid
    for occ in ${ret_occ[@]}; do
        assert_equal ${occ} 1
    done
}

@test "Report assembly accession" {
    outdir=${outprefix}report-assembly-accession/
    label="test"
    run ./genome_updater.sh -b ${label} -o ${outdir} -u
    sanity_check ${outdir} ${label}

    # Check if report was printed and has all lines reported
    report_file="${outdir}${label}/updated_assembly_accession.txt"
    assert_file_exist "${report_file}"
    assert_equal $(count_lines_file "${report_file}") $(count_lines_file ${outdir}assembly_summary.txt)
}

@test "Report sequence accession" {
    outdir=${outprefix}report-sequence-accession/
    label="test"
    run ./genome_updater.sh -b ${label} -o ${outdir} -r
    sanity_check ${outdir} ${label}

    # Check if report was printed
    report_file="${outdir}${label}/updated_sequence_accession.txt"
    assert_file_exist "${report_file}"
}

@test "Report urls" {
    outdir=${outprefix}report-urls/
    label="test"
    run ./genome_updater.sh -b ${label} -o ${outdir} -p
    sanity_check ${outdir} ${label}

    # Check if report was printed and has all lines reported
    assert_file_exist ${outdir}${label}/*_url_downloaded.txt
    assert_equal $(count_lines_file ${outdir}${label}/*_url_downloaded.txt) $(count_lines_file ${outdir}assembly_summary.txt)

    # Check if url_failed exists/empty
    assert_file_exist ${outdir}${label}/*_url_failed.txt
    assert_file_empty ${outdir}${label}/*_url_failed.txt
}

@test "External assembly summary" {
    outdir=${outprefix}external-assembly-summary/
    label="test"
    # Get assembly_summary from -e (not directly from url)
    run ./genome_updater.sh -b ${label} -o ${outdir} -e ${local_dir}genomes/refseq/assembly_summary_refseq.txt
    sanity_check ${outdir} ${label}
}

@test "Delete extra files" {
    outdir=${outprefix}delete-extra-files/
    label="test"
    run ./genome_updater.sh -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # Create extra files
    touch "${outdir}${label}/files/EXTRA_FILE.txt"
    assert_file_exist "${outdir}${label}/files/EXTRA_FILE.txt"

    # Run to fix and delete
    run ./genome_updater.sh -b ${label} -o ${outdir} -i -x
    sanity_check ${outdir} ${label}

    # File was removed
    assert_not_exist "${outdir}${label}/files/EXTRA_FILE.txt"
}

@test "Threads" {
    outdir=${outprefix}threads/
    label="test"
    run ./genome_updater.sh -b ${label} -o ${outdir} -t 8
    sanity_check ${outdir} ${label}
}

@test "Silent" {
    outdir=${outprefix}silent/
    label="test"
    run ./genome_updater.sh -b ${label} -o ${outdir} -s
    sanity_check ${outdir} ${label}

    # check if printed to STDOUT
    assert_output ""
}

@test "Mode FIX" {
    outdir=${outprefix}mode-fix/
    label="test"

    # Dry-run NEW
    run ./genome_updater.sh -b ${label} -o ${outdir} -k
    assert_success
    assert_dir_not_exist ${outdir}

    # Real run NEW
    run ./genome_updater.sh -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # Remove files to simulate failure
    rm ${outdir}${label}/files/*

    # Dry-run FIX
    run ./genome_updater.sh -b ${label} -o ${outdir} -k -i
    assert_success
    assert_file_empty {outdir}${label}/files/

    # Real run FIX
    run ./genome_updater.sh -b ${label} -o ${outdir} -i
    sanity_check ${outdir} ${label}
}

@test "Mode UPDATE" {
    outdir=${outprefix}mode-update/
    label="test"

    # Dry-run NEW
    run ./genome_updater.sh -b ${label} -o ${outdir} -k
    assert_success
    assert_dir_not_exist ${outdir}

    # Real run NEW
    run ./genome_updater.sh -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # Dry-run UPDATE (use another organism group to simulate change)
    label="update"
    run ./genome_updater.sh -g archaea,fungi -b ${label} -o ${outdir} -k
    assert_success

    # Real run FIX
    run ./genome_updater.sh -g archaea,fungi -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
}
