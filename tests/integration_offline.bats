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

    # Export local_dir to use local files offline instead of ncbi ftp online when testing
    local_dir="$DIR/files/"
    export local_dir

    # Setup output folder for tests
    outprefix="$DIR/results/integration_offline/"
    rm -rf $outprefix
    mkdir -p $outprefix
    export outprefix
}

@test "Run genome_updater.sh without args" {
    run ./genome_updater.sh
    assert_failure
}

@test "Run genome_updater.sh and show help" {
    run ./genome_updater.sh -h
    assert_success
}

@test "Run genome_updater.sh and show debug info" {
    run ./genome_updater.sh -Z
    assert_success
    assert_output --partial "GNU bash" # Loop for GNU --version info
}

@test "Database -d refseq" {
    outdir=${outprefix}d-refseq/
    label="refseq"
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
    assert [ $(count_files ${outdir} ${label}) -gt 0 ] # contains files
    for file in $(find_files ${outdir} ${label}); do
        [[ "$(basename $file)" = GCF* ]] # filename starts with GCF_
    done
}

@test "Database -d genbank" {
    outdir=${outprefix}d-genbank/
    label="genbank"
    run ./genome_updater.sh -d genbank -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
    assert [ $(count_files ${outdir} ${label}) -gt 0 ] # contains files
    for file in $(find_files ${outdir} ${label}); do
        [[ "$(basename $file)" = GCA* ]] # filename starts with GCA_
    done
}

@test "Database -d refseq,genbank" {
    outdir=${outprefix}d-refseq-genbank/
    
    label="refseq"
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
    files_refseq=$(count_files ${outdir} ${label})
    assert [ ${files_refseq} -gt 0 ] # contains files
    for file in $(find_files ${outdir} ${label}); do
        [[ "$(basename $file)" = GCF* ]] # filename starts with GCF_
    done

    label="genbank"
    run ./genome_updater.sh -d genbank -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
    files_genbank=$(count_files ${outdir} ${label})
    assert [ ${files_genbank} -gt 0 ] # contains files
    for file in $(find_files ${outdir} ${label}); do
        [[ "$(basename $file)" = GCA* ]] # filename starts with GCA_
    done

    label="refseq-genbank"
    run ./genome_updater.sh -d refseq,genbank -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
    assert [ $(count_files ${outdir} ${label}) -eq $((files_refseq+files_genbank)) ]
}

@test "Organism group -g archaea" {
    outdir=${outprefix}g-archaea/
    label="test"
    run ./genome_updater.sh -d refseq -g archaea -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
    assert [ $(count_files ${outdir} ${label}) -gt 0 ] # contains files
}

@test "Organism group -g fungi" {
    outdir=${outprefix}g-fungi/
    label="test"
    run ./genome_updater.sh -d refseq -g fungi -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
    assert [ $(count_files ${outdir} ${label}) -gt 0 ] # contains files
}

@test "Organism group -g archaea,fungi" {
    outdir=${outprefix}g-archaea-fungi/

    label="archaea"
    run ./genome_updater.sh -d refseq -g archaea -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
    files_arc=$(count_files ${outdir} ${label})
    assert [ ${files_arc} -gt 0 ] # contains files

    label="fungi"
    run ./genome_updater.sh -d refseq -g fungi -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
    files_fun=$(count_files ${outdir} ${label})
    assert [ ${files_fun} -gt 0 ] # contains files

    label="archaea-fungi"
    run ./genome_updater.sh -d refseq -g archaea,fungi -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
    assert [ $(count_files ${outdir} ${label}) -eq $((files_arc+files_fun)) ]
}

@test "Taxids leaves ncbi" {
    # taxids on lower levels need the complete taxonomy to work properly (tested online)

    outdir=${outprefix}taxids-leaves-ncbi/
    label="test"
    # Get all possible taxids from base assembly_summary
    txids=( $(get_values_as ${local_dir}genomes/refseq/assembly_summary_refseq.txt 7 ) )
    #echo ${txids[@]} >&3

    # Use third
    run ./genome_updater.sh -d refseq -T "${txids[2]}" -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # Check if output contains only used taxids
    txids_ret=( $(get_values_as ${outdir}assembly_summary.txt 7 ) )
    #echo ${txids_ret[@]} >&3

    # Used taxid should be the only one 
    assert_equal ${#txids_ret[@]} 1 #length
    assert_equal ${txids[2]} ${txids_ret[0]} #same taxid 
}

@test "Taxids leaves gtdb" {
    # taxids on lower levels need the complete taxonomy to work properly (tested online)

    outdir=${outprefix}taxids-leaves-gtdb/
    label="test"
    # Use fixed one
    run ./genome_updater.sh -d refseq,genbank -T 's__MWBV01 sp002069705' -b ${label} -o ${outdir} -g archaea -M gtdb
    sanity_check ${outdir} ${label}
    assert [ $(count_files ${outdir} ${label}) -eq 1 ]
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

@test "Top 1 leaves ncbi" {
    outdir=${outprefix}top-leaves-ncbi/
    label="test"
    # Keep only top 1 for selected species
    run ./genome_updater.sh -d refseq,genbank -A 1 -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # Get counts of species taxids on output
    txids_ret=$(get_values_as ${outdir}assembly_summary.txt 6 )
    ret_occ=( $( echo ${txids_ret}  | tr ' ' '\n' | sort | uniq -c | awk '{print $1}' ) )
   
    # Should have one assembly for each species taxid
    for occ in ${ret_occ[@]}; do
        assert_equal ${occ} 1
    done
}

@test "Top 1 species ncbi" {
    outdir=${outprefix}top-species-ncbi/
    label="test"
    # Keep only top 1 for selected species
    run ./genome_updater.sh -d refseq,genbank -A species:1 -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # Get counts of species taxids on output
    txids_ret=$(get_values_as ${outdir}assembly_summary.txt 7 )
    ret_occ=( $( echo ${txids_ret}  | tr ' ' '\n' | sort | uniq -c | awk '{print $1}' ) )
   
    # Should have one assembly for each species taxid
    for occ in ${ret_occ[@]}; do
        assert_equal ${occ} 1
    done
}

@test "Top 1 superkingdom ncbi" {
    outdir=${outprefix}top-superkingdom-ncbi/
    label="test"
    # Keep only top 1 for superkingdom
    run ./genome_updater.sh -d refseq -g archaea,fungi -A superkingdom:1 -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # Check if output contains one file for archaea and one for fungi
    assert [ $(count_files ${outdir} ${label}) -eq 2 ]
}

@test "Top gtdb" {
    outdir=${outprefix}top-gtdb/
    label_none="none"
    # no top
    run ./genome_updater.sh -M gtdb -d refseq,genbank -g archaea -b ${label_none} -o ${outdir}
    sanity_check ${outdir} ${label_none}

    # Keep only top 1 for species
    label_species="top-species"
    run ./genome_updater.sh -M gtdb -d refseq,genbank -g archaea -A species:1 -b ${label_species} -o ${outdir}
    sanity_check ${outdir} ${label_species}
    # Check if reduce number of files with filter
    assert [ $(count_files ${outdir} ${label_none}) -gt $(count_files ${outdir} ${label_species}) ]

    # Keep only top 1 for species
    label_genus="top-genus"
    run ./genome_updater.sh -M gtdb -d refseq,genbank -g archaea -A genus:1 -b ${label_genus} -o ${outdir}
    sanity_check ${outdir} ${label_genus}
    assert [ $(count_files ${outdir} ${label_species}) -gt $(count_files ${outdir} ${label_genus}) ]

    # Keep only top 1 for species
    label_phylum="top-phylum"
    run ./genome_updater.sh -M gtdb -d refseq,genbank -g archaea -A phylum:1 -b ${label_phylum} -o ${outdir}
    sanity_check ${outdir} ${label_phylum}
    assert [ $(count_files ${outdir} ${label_genus}) -gt $(count_files ${outdir} ${label_phylum}) ]

    # Check if not 0
    assert [ $(count_files ${outdir} ${label_phylum}) -gt 0 ]
}

@test "Top assemblies order" {

    outdir=${outprefix}top-assemblies-order-refseq-category/

    # Selection order
    # col5["reference genome"]=1;
    # col5["representative genome"]=2;
    # col5["na"]=3;
    # should always pick the correct refseq category for top superkingdom (just one)

    label="3"
    rscat="reference genome,representative genome,na"
    run ./genome_updater.sh -d refseq -g archaea -c "${rscat}" -A superkingdom:1 -b ${label} -o ${outdir}    
    sanity_check ${outdir} ${label}
    # --- no reference genome in example files ---
    assert_equal "representative genome" "$(get_values_as ${outdir}assembly_summary.txt 5)"

    label="2"
    rscat="representative genome,na"
    run ./genome_updater.sh -d refseq -g archaea -c "${rscat}" -A superkingdom:1 -b ${label} -o ${outdir}    
    sanity_check ${outdir} ${label}
    assert_equal "representative genome" "$(get_values_as ${outdir}assembly_summary.txt 5)"

    label="1"
    rscat="na"
    run ./genome_updater.sh -d refseq -g archaea -c "${rscat}" -A superkingdom:1 -b ${label} -o ${outdir}    
    sanity_check ${outdir} ${label}
    assert_equal "na" "$(get_values_as ${outdir}assembly_summary.txt 5)"


    outdir=${outprefix}top-assemblies-order-assembly-level/

    # Selection order
    # col12["Complete Genome"]=1;
    # col12["Chromosome"]=2;
    # col12["Scaffold"]=3;
    # col12["Contig"]=4;

    # should always pick the correct assembly level for top superkingdom (just one)

    label="4"
    aslvl="complete genome,chromosome,scaffold,contig"
    run ./genome_updater.sh -d refseq -g archaea -l "${aslvl}" -A superkingdom:1 -b ${label} -o ${outdir}    
    sanity_check ${outdir} ${label}
    assert_equal "Complete Genome" "$(get_values_as ${outdir}assembly_summary.txt 12)"

    label="3"
    aslvl="chromosome,scaffold,contig"
    run ./genome_updater.sh -d refseq -g archaea -l "${aslvl}" -A superkingdom:1 -b ${label} -o ${outdir}    
    sanity_check ${outdir} ${label}
    assert_equal "Chromosome" "$(get_values_as ${outdir}assembly_summary.txt 12)"

    label="2"
    aslvl="scaffold,contig"
    run ./genome_updater.sh -d refseq -g archaea -l "${aslvl}" -A superkingdom:1 -b ${label} -o ${outdir}    
    sanity_check ${outdir} ${label}
    assert_equal "Scaffold" "$(get_values_as ${outdir}assembly_summary.txt 12)"

    label="1"
    aslvl="contig"
    run ./genome_updater.sh -d refseq -g archaea -l "${aslvl}" -A superkingdom:1 -b ${label} -o ${outdir}    
    sanity_check ${outdir} ${label}
    assert_equal "Contig" "$(get_values_as ${outdir}assembly_summary.txt 12)"


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
    assert_file_exist ${outdir}${label}/*_assembly_accession.txt
    assert_file_not_empty ${outdir}${label}/*_assembly_accession.txt
    assert_equal $(count_lines_file ${outdir}${label}/*_assembly_accession.txt) $(count_lines_file ${outdir}assembly_summary.txt)
}

@test "Report sequence accession" {
    outdir=${outprefix}report-sequence-accession/
    label="test"
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -r
    sanity_check ${outdir} ${label}

    # Check if report was printed
    assert_file_exist ${outdir}${label}/*_sequence_accession.txt
    assert_file_not_empty ${outdir}${label}/*_sequence_accession.txt
}

@test "Report sequence accession with ncbi folder structure" {
    outdir=${outprefix}report-sequence-accession-ncbi-folders/
    label="test"
    run ./genome_updater.sh -N -d refseq -b ${label} -o ${outdir} -r
    sanity_check ${outdir} ${label}

    # Check if report was printed
    assert_file_exist ${outdir}${label}/*_sequence_accession.txt
    assert_file_not_empty ${outdir}${label}/*_sequence_accession.txt
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
    run ./genome_updater.sh -b ${label} -o ${outdir} -e ${local_dir}genomes/refseq/assembly_summary_refseq.txt
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
    run ./genome_updater.sh -b ${label2} -o ${outdir} -d refseq,genbank
    sanity_check ${outdir} ${label2}

    # Third version with same entries (nothing to download)
    label3="v3"
    run ./genome_updater.sh -b ${label3} -o ${outdir} -d refseq,genbank
    sanity_check ${outdir} ${label3}

    # Check log for no updates
    grep "0 updated, 0 removed, 0 new entries" ${outdir}${label3}/*.log # >&3
    assert_success

    # Fourth version with the same as second but rolling back from first, re-download files
    label4="v4"
    run ./genome_updater.sh -b ${label4} -o ${outdir} -d refseq,genbank -B v1
    sanity_check ${outdir} ${label4}

    # Check log for updates
    grep "0 updated, 0 removed, [1-9][0-9]* new entries" ${outdir}${label4}/*.log # >&3
    assert_success
}

@test "Rollback label auto update" {
    outdir=${outprefix}rollback-label-auto-update/
    
    # Base version with only refseq
    label1="v1"
    run ./genome_updater.sh -d refseq -b ${label1} -o ${outdir}
    sanity_check ${outdir} ${label1}

    # Second version with more entries (refseq,genbank)
    label2="v2"
    run ./genome_updater.sh -b ${label2} -o ${outdir} -d refseq,genbank
    sanity_check ${outdir} ${label2}

    # Third version with same entries (nothing to download)
    label3="v3"
    run ./genome_updater.sh -b ${label3} -o ${outdir}
    sanity_check ${outdir} ${label3}

    # Check log for no updates
    grep "0 updated, 0 removed, 0 new entries" ${outdir}${label3}/*.log # >&3
    assert_success

    # Fourth version with the same as second but rolling back from first
    label4="v4"
    run ./genome_updater.sh -b ${label4} -o ${outdir} -B v1 -d refseq,genbank
    sanity_check ${outdir} ${label4}

    # Check log for updates
    grep "0 updated, 0 removed, [1-9][0-9]* new entries" ${outdir}${label4}/*.log # >&3
    assert_success

    # Continue the update from v4 (without rolling back to v1) 
    label5="v5"
    run ./genome_updater.sh -b ${label5} -o ${outdir} -B ""
    sanity_check ${outdir} ${label5}

    # Check log for updates
    grep "0 updated, 0 removed, 0 new entries" ${outdir}${label5}/*.log # >&3
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
    rm -rf ${outdir}${label}/files/*

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

@test "Mode UPDATE ncbi folders" {
    outdir=${outprefix}mode-update-ncbi-folders/
    label="test"

    # Dry-run NEW
    run ./genome_updater.sh -N -d refseq -b ${label} -o ${outdir} -k
    assert_success
    assert_dir_not_exist ${outdir}

    # Real run NEW
    run ./genome_updater.sh -N -d refseq -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # Dry-run UPDATE (use another organism group to simulate change)
    label="update"
    run ./genome_updater.sh -N -d refseq -g archaea,fungi -b ${label} -o ${outdir} -k
    assert_success

    # Real run FIX
    run ./genome_updater.sh -N -d refseq -g archaea,fungi -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}
}

@test "Mode auto UPDATE" {
    outdir=${outprefix}mode-auto-update/
    label="test"

    # Dry-run NEW
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -g archaea -k
    assert_success
    assert_dir_not_exist ${outdir}

    # Real run NEW
    run ./genome_updater.sh -d refseq -b ${label} -o ${outdir} -g archaea
    sanity_check ${outdir} ${label}

    # Dry-run UPDATE (use same parameters)
    label="update"
    run ./genome_updater.sh -o ${outdir} -b ${label} -k
    assert_success

    # Real run (nothing to update, but carry parameters)
    run ./genome_updater.sh -o ${outdir} -b ${label}
    sanity_check ${outdir} ${label}

    # Dry-run UPDATE
    label="update2"
    run ./genome_updater.sh -o ${outdir} -b ${label} -g "" -d refseq,genbank -u -k
    assert_success

    # Real run FIX, remove org (get all), add database, add bool report
    run ./genome_updater.sh -o ${outdir} -b ${label} -g "" -d refseq,genbank -u
    sanity_check ${outdir} ${label}

    assert_file_exist ${outdir}${label}/*_assembly_accession.txt

    # Check log for updates
    grep "0 updated, [1-9][0-9]* removed, [1-9][0-9]* new entries" ${outdir}${label}/*.log # >&3
    assert_success
}

@test "Mode auto UPDATE ncbi folders" {
    outdir=${outprefix}mode-auto-update-ncbi-folders/
    label="test"

    # Dry-run NEW
    run ./genome_updater.sh -N -d refseq -b ${label} -o ${outdir} -g archaea -k
    assert_success
    assert_dir_not_exist ${outdir}

    # Real run NEW
    run ./genome_updater.sh -N -d refseq -b ${label} -o ${outdir} -g archaea
    sanity_check ${outdir} ${label}

    # Dry-run UPDATE (use same parameters)
    label="update"
    run ./genome_updater.sh -N -o ${outdir} -b ${label} -k
    assert_success

    # Real run (nothing to update, but carry parameters)
    run ./genome_updater.sh -N -o ${outdir} -b ${label}
    sanity_check ${outdir} ${label}

    # Dry-run UPDATE
    label="update2"
    run ./genome_updater.sh -N -o ${outdir} -b ${label} -g "" -d refseq,genbank -u -k
    assert_success

    # Real run FIX, remove org (get all), add database, add bool report
    run ./genome_updater.sh -N -o ${outdir} -b ${label} -g "" -d refseq,genbank -u
    sanity_check ${outdir} ${label}

    assert_file_exist ${outdir}${label}/*_assembly_accession.txt

    # Check log for updates
    grep "0 updated, [1-9][0-9]* removed, [1-9][0-9]* new entries" ${outdir}${label}/*.log # >&3
    assert_success
}

@test "Tax. Mode GTDB" {
    outdir=${outprefix}tax-gtdb/
    label="test"
    run ./genome_updater.sh -d refseq,genbank -g archaea -b ${label} -o ${outdir} -M gtdb
    sanity_check ${outdir} ${label}
    
    # Check log for filer with GTDB
    grep "[1-9][0-9]* assemblies removed not in GTDB" ${outdir}${label}/*.log # >&3
    assert_success
}

@test "Invalid assembly_summary.txt" {
    outdir=${outprefix}invalid-as/
    label="cols"
    run ./genome_updater.sh -o ${outdir} -b ${label} -e ${files_dir}simulated/assembly_summary_invalid_cols.txt
    assert_failure
    label="headermiddle"
    run ./genome_updater.sh -o ${outdir} -b ${label} -e ${files_dir}simulated/assembly_summary_invalid_headermiddle.txt
    assert_failure
    label="justheader"
    run ./genome_updater.sh -o ${outdir} -b ${label} -e ${files_dir}simulated/assembly_summary_invalid_justheader.txt
    assert_failure
    label="xCF"
    run ./genome_updater.sh -o ${outdir} -b ${label} -e ${files_dir}simulated/assembly_summary_invalid_xCF.txt
    assert_failure
}

@test "NCBI folders" {
    outdir=${outprefix}ncbi-folders/
    label="1-refseq"
    run ./genome_updater.sh -N -d refseq -g archaea -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # refseq base folder is created, no genbank
    assert_dir_exist "${outdir}${label}/files/GCF/"
    assert_dir_not_exist "${outdir}${label}/files/GCA/"

    # Add genbank
    label="2-refseq-genbank"
    run ./genome_updater.sh -N -d refseq,genbank -g archaea -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # refseq and genbank base folders are created
    assert_dir_exist "${outdir}${label}/files/GCF/"
    assert_dir_exist "${outdir}${label}/files/GCA/"
   
    # Remove refseq
    label="3-genbank"
    run ./genome_updater.sh -N -d genbank -g archaea -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    assert_dir_not_exist "${outdir}${label}/files/GCF/"
    assert_dir_exist "${outdir}${label}/files/GCA/"

    # no empty folders
    assert_equal $(find "${outdir}${label}/files/" -type d -empty | wc -l | cut -f1 -d' ') 0
    
    # Update without -N, do not consider folder structute and download again to base files folde
    # Remove refseq
    label="4-no-ncbi-folders"
    run ./genome_updater.sh -d genbank -g archaea -b ${label} -o ${outdir}
    sanity_check ${outdir} ${label}

    # refseq and genbank are no longer
    assert_dir_not_exist "${outdir}${label}/files/GCF/"
    assert_dir_not_exist "${outdir}${label}/files/GCA/"
}