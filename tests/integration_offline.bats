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

@test "Run genome_updater.sh and show debug info" {
    run ./genome_updater.sh -Z
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
    run ./genome_updater.sh -d refseq -o archaea -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
}

@test "Organism group archaea and fungi" {
    outdir=${outprefix}og-archaea-fungi/
    label="test"
    run ./genome_updater.sh -d refseq -o archaea,fungi -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
}

@test "Species taxids" {
    outdir=${outprefix}species-taxids/
    label="test"
    # Get all possible taxids from base assembly_summary
    txids=( $(get_values_as ${local_dir}genomes/refseq/assembly_summary_refseq.txt 7 ) )
    #echo ${txids[@]} >&3

    # Use third
    run ./genome_updater.sh -d refseq -S "${txids[2]}" -b ${label} -o ${outdir}
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
    run ./genome_updater.sh -d refseq -c "${rscat[0]}" -b ${label} -o ${outdir}
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
    run ./genome_updater.sh -d refseq -l "${aslev[0]}" -b ${label} -o ${outdir}
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
    run ./genome_updater.sh -d refseq -F "5:${rscat[0]}|12:${aslev[0]}" -b ${label} -o ${outdir}
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

@test "Date start filter" {
    outdir=${outprefix}date-start-filter/
    
    # Get all possible dates and sort it
    dates=( $(get_values_as ${local_dir}genomes/refseq/assembly_summary_refseq.txt 15 | sed 's|/||g' | sort) )

    label="test_all"
    # Use first date as start, should return everything
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -D ${dates[0]}
    sanity_check ${outdir} ${label}
    assert_equal $(count_lines_file "${local_dir}genomes/refseq/assembly_summary_refseq.txt") $(count_lines_file ${outdir}assembly_summary.txt)

    label="test_some"
    # Use second date as start, should return less than everything
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -D ${dates[1]}
    sanity_check ${outdir} ${label}
    assert [ $(count_lines_file "${local_dir}genomes/refseq/assembly_summary_refseq.txt") -gt $(count_lines_file ${outdir}assembly_summary.txt) ]
}

@test "Date end filter" {
    outdir=${outprefix}date-end-filter/
    
    # Get all possible dates and sort it
    dates=( $(get_values_as ${local_dir}genomes/refseq/assembly_summary_refseq.txt 15 | sed 's|/||g' | sort) )

    label="test_all"
    # Use last date as end, should return everything
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -E ${dates[-1]}
    sanity_check ${outdir} ${label}
    assert_equal $(count_lines_file "${local_dir}genomes/refseq/assembly_summary_refseq.txt") $(count_lines_file ${outdir}assembly_summary.txt)

    label="test_some"
    # Use second last date as end, should return less than everything
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -E ${dates[-2]}
    sanity_check ${outdir} ${label}
    assert [ $(count_lines_file "${local_dir}genomes/refseq/assembly_summary_refseq.txt") -gt $(count_lines_file ${outdir}assembly_summary.txt) ]
}

@test "Date start-end filter" {
    outdir=${outprefix}date-start-end-filter/
    
    # Get all possible dates and sort it
    dates=( $(get_values_as ${local_dir}genomes/refseq/assembly_summary_refseq.txt 15 | sed 's|/||g' | sort) )

    label="test_all"
    # Use first date as start, last as end, should return everything
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -D ${dates[0]} -E ${dates[-1]}
    sanity_check ${outdir} ${label}
    assert_equal $(count_lines_file "${local_dir}genomes/refseq/assembly_summary_refseq.txt") $(count_lines_file ${outdir}assembly_summary.txt)

    label="test_some"
    # Use second date as start, second to last as end, should return less than everything
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -D ${dates[1]} -E ${dates[-2]}
    sanity_check ${outdir} ${label}
    assert [ $(count_lines_file "${local_dir}genomes/refseq/assembly_summary_refseq.txt") -gt $(count_lines_file ${outdir}assembly_summary.txt) ]
}

@test "Report assembly accession" {
    outdir=${outprefix}report-assembly-accession/
    label="test"
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -u
    sanity_check ${outdir} ${label}

    # Check if report was printed and has all lines reported
    report_file="${outdir}${label}/updated_assembly_accession.txt"
    assert_file_exist "${report_file}"
    assert_equal $(count_lines_file "${report_file}") $(count_lines_file ${outdir}assembly_summary.txt)
}

@test "Report sequence accession" {
    outdir=${outprefix}report-sequence-accession/
    label="test"
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -r
    sanity_check ${outdir} ${label}

    # Check if report was printed
    report_file="${outdir}${label}/updated_sequence_accession.txt"
    assert_file_exist "${report_file}"
}

@test "Report urls" {
    outdir=${outprefix}report-urls/
    label="test"
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -p
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
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -e ${local_dir}genomes/refseq/assembly_summary_refseq.txt
    sanity_check ${outdir} ${label}
}


@test "Rollback label" {
    outdir=${outprefix}rollback-label/
    
    # Base version with only refseq
    label1="v1"
    run ./genome_updater.sh -d refseq -b ${label1} -o ${outdir} -d refseq
    sanity_check ${outdir} ${label1}

    # Second version with more entries (refseq,genbank)
    label2="v2"
    run ./genome_updater.sh -d refseq -b ${label2} -o ${outdir} -d refseq,genbank
    sanity_check ${outdir} ${label2}

    # Third version with same entries (nothing to download)
    label3="v3"
    run ./genome_updater.sh -d refseq -b ${label3} -o ${outdir} -d refseq,genbank
    sanity_check ${outdir} ${label3}

    # Check log for no updates
    grep "0 updated, 0 deleted, 0 new entries" ${outdir}${label3}/*.log # >&3
    assert_success

    # Fourth version with the same as second but rolling back from first, re-download files
    label4="v4"
    run ./genome_updater.sh -d refseq -b ${label4} -o ${outdir} -d refseq,genbank -B v1
    sanity_check ${outdir} ${label4}

    # Check log for updates
    grep "0 updated, 0 deleted, [0-9]* new entries" ${outdir}${label4}/*.log # >&3
    assert_success
}

@test "Delete extra files" {
    outdir=${outprefix}delete-extra-files/
    label="test"
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
    # Create extra files
    touch "${outdir}${label}/files/EXTRA_FILE.txt"
    assert_file_exist "${outdir}${label}/files/EXTRA_FILE.txt"
    # Run to fix and delete
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -i -x
    sanity_check ${outdir} ${label}
    # File was removed
    assert_not_exist "${outdir}${label}/files/EXTRA_FILE.txt"

    # Create extra files
    touch "${outdir}${label}/files/ANOTHER_EXTRA_FILE.txt"
    assert_file_exist "${outdir}${label}/files/ANOTHER_EXTRA_FILE.txt"
    
    # update label
    label="update"
    # Update (should not not carry extra file over to new version)
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    assert_not_exist "${outdir}${label}/files/ANOTHER_EXTRA_FILE.txt"
}


@test "Threads" {
    outdir=${outprefix}threads/
    label="test"
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -t 8
    sanity_check ${outdir} ${label}
}

@test "Silent" {
    outdir=${outprefix}silent/
    label="test"
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -s
    sanity_check ${outdir} ${label}

    # check if printed to STDOUT
    assert_output ""
}

@test "Using curl" {
    outdir=${outprefix}using-curl/
    label="test"
    use_curl=1
    export use_curl
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
}

@test "Mode FIX" {
    outdir=${outprefix}mode-fix/
    label="test"

    # Dry-run NEW
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -k
    assert_success
    assert_dir_not_exist ${outdir}

    # Real run NEW
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # Remove files to simulate failure
    rm ${outdir}${label}/files/*

    # Dry-run FIX
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -k -i
    assert_success
    assert_file_empty {outdir}${label}/files/

    # Real run FIX
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -i
    sanity_check ${outdir} ${label}
}

@test "Mode UPDATE" {
    outdir=${outprefix}mode-update/
    label="test"

    # Dry-run NEW
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -k
    assert_success
    assert_dir_not_exist ${outdir}

    # Real run NEW
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # Dry-run UPDATE (use another organism group to simulate change)
    label="update"
    run ./genome_updater.sh -d refseq -g archaea,fungi -b ${label} -o ${outdir} -k
    assert_success

    # Real run FIX
    run ./genome_updater.sh -d refseq -g archaea,fungi -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
}
