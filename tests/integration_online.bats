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
    assert [ $(count_files ${outdir} ${label}) -gt 0 ]

    # Check filenames
    for file in $(find_files ${outdir} ${label}); do
        [[ "$(basename $file)" = GCF* ]] # filename starts with GCF_
    done
}

@test "Taxids genus ncbi" {
    outdir=${outprefix}taxids-genus-ncbi/
    mkdir -p "${outdir}"

    # Protozoa in refseq is the smallest available assembly_summary at the time of writing this test (01.2022)
    # 5820 genus Plasmodium
    label_genus="genus"
    run ./genome_updater.sh -N -d refseq -g protozoa -T 5820 -b ${label_genus} -t ${threads} -o ${outdir}
    sanity_check ${outdir} ${label_genus}

    # 5794 phylum Apicomplexa
    label_phylum="phylum"
    run ./genome_updater.sh -N -d refseq -g protozoa -T 5794 -b ${label_phylum} -t ${threads} -o ${outdir}
    sanity_check ${outdir} ${label_phylum}
    
    # More files filtering by phylum than genus
    assert [ $(count_files ${outdir} ${label_phylum}) -gt $(count_files ${outdir} ${label_genus}) ]
    assert [ $(count_files ${outdir} ${label_phylum}) -gt 0 ]

}

@test "Taxids genus gtdb" {
    outdir=${outprefix}taxids-genus-gtdb/
    # p__Undinarchaeota lineage
    #d__Archaea; p__Undinarchaeota; c__Undinarchaeia; o__Undinarchaeales; f__Naiadarchaeaceae; g__Naiadarchaeum; s__Naiadarchaeum limnaeum 
    #d__Archaea; p__Undinarchaeota; c__Undinarchaeia; o__Undinarchaeales; f__Undinarchaeaceae; g__Undinarchaeum; s__Undinarchaeum marinum
    #d__Archaea; p__Undinarchaeota; c__Undinarchaeia; o__Undinarchaeales; f__UBA543; g__UBA543; s__UBA543 sp002502135 

    label_genus="genus"
    run ./genome_updater.sh -d genbank -g archaea -M gtdb -T "g__Naiadarchaeum,g__Undinarchaeum" -b ${label_genus} -t ${threads} -o ${outdir}
    sanity_check ${outdir} ${label_genus}

    label_phylum="phylum"
    run ./genome_updater.sh -d genbank -g archaea -M gtdb -T "p__Undinarchaeota" -b ${label_phylum} -t ${threads} -o ${outdir}
    sanity_check ${outdir} ${label_phylum}
    
    # More files filtering by phylum than genus
    assert [ $(count_files ${outdir} ${label_phylum}) -gt $(count_files ${outdir} ${label_genus}) ]
    assert [ $(count_files ${outdir} ${label_phylum}) -gt 0 ]

}

@test "Curl" {
    outdir=${outprefix}curl/
    label="test"

    # Protozoa in refseq is the smallest available assembly_summary at the time of writing this test (01.2022)
    run ./genome_updater.sh -d refseq -g protozoa -b ${label} -t ${threads} -o ${outdir} -L curl
    sanity_check ${outdir} ${label}
}

@test "NA URL" {
    outdir=${outprefix}na-url/
    label="test"
    run ./genome_updater.sh -b ${label} -o ${outdir} -t ${threads} -e ${files_dir}simulated/assembly_summary_na_url.txt
    sanity_check ${outdir} ${label}
}

@test "All invalid URLs" {
    outdir=${outprefix}all-invalid-url/
    label="test"
    run ./genome_updater.sh -b ${label} -o ${outdir} -t ${threads} -e ${files_dir}simulated/assembly_summary_all_invalid_url.txt
    assert_success
    assert_equal $(count_files ${outdir} ${label}) 0
}

@test "Some invalid URLs" {
    outdir=${outprefix}some-invalid-url/
    label="test"
    run ./genome_updater.sh -b ${label} -o ${outdir} -t ${threads} -e ${files_dir}simulated/assembly_summary_some_invalid_url.txt
    assert_success
    assert_equal $(count_files ${outdir} ${label}) 2
}

@test "Conditional exit" {

    outdir=${outprefix}conditional-exit/
    label="n0"
    # 2 out of 4 genomes will be downloaded
    run ./genome_updater.sh -n 0 -R 1 -o ${outdir}${label}/ -t ${threads} -e ${files_dir}simulated/assembly_summary_some_invalid_url.txt
    assert_success

    label="n1"
    run ./genome_updater.sh -n 1 -R 1 -o ${outdir}${label}/ -t ${threads} -e ${files_dir}simulated/assembly_summary_some_invalid_url.txt
    assert_failure
    
    label="n2"
    run ./genome_updater.sh -n 2 -R 1 -o ${outdir}${label}/ -t ${threads} -e ${files_dir}simulated/assembly_summary_some_invalid_url.txt
    assert_failure

    label="n3"
    run ./genome_updater.sh -n 3 -R 1 -o ${outdir}${label}/ -t ${threads} -e ${files_dir}simulated/assembly_summary_some_invalid_url.txt
    assert_success

    label="n0.2"
    run ./genome_updater.sh -n 0.2 -R 1 -o ${outdir}${label}/ -t ${threads} -e ${files_dir}simulated/assembly_summary_some_invalid_url.txt
    assert_failure

    label="n0.5"
    run ./genome_updater.sh -n 0.5 -R 1 -o ${outdir}${label}/ -t ${threads} -e ${files_dir}simulated/assembly_summary_some_invalid_url.txt
    assert_failure

    label="n0.51"
    run ./genome_updater.sh -n 0.51 -R 1 -o ${outdir}${label}/ -t ${threads} -e ${files_dir}simulated/assembly_summary_some_invalid_url.txt
    assert_success

    label="n0.99"
    run ./genome_updater.sh -n 0.99 -R 1 -o ${outdir}${label}/ -t ${threads} -e ${files_dir}simulated/assembly_summary_some_invalid_url.txt
    assert_success

}

@test "Multiple file types" {
    outdir=${outprefix}multiple-file-types/
    label="test"

    run ./genome_updater.sh -d refseq -g protozoa -D 20210101 -E 20220101 -b ${label} -t ${threads} -o ${outdir} -f "assembly_report.txt,protein.faa.gz,genomic.fna.gz"
    sanity_check ${outdir} ${label} 3
}

@test "Leaf taxids" {
    outdir=${outprefix}leaf-taxids/
    label="test"

    # 5690 Trypanosoma genus - around 6 genomes, get only one per species (01.2022)
    run ./genome_updater.sh -d refseq -g protozoa -T 5690 -A 1 -b ${label} -o ${outdir} -t ${threads} 
    sanity_check ${outdir} ${label}

    # Get counts of taxids on output
    txids_ret=$(get_values_as ${outdir}assembly_summary.txt 6 )
    ret_occ=( $( echo ${txids_ret}  | tr ' ' '\n' | sort | uniq -c | awk '{print $1}' ) )
   
    # Should have one assembly for each species taxid
    for occ in ${ret_occ[@]}; do
        assert_equal ${occ} 1
    done
}

@test "MD5 verbose log" {
    outdir=${outprefix}md5-verbose-log/
    label="test"

    run ./genome_updater.sh -d refseq -g protozoa -D 20210101 -E 20220101 -b ${label} -o ${outdir} -t ${threads} -m -V
    sanity_check ${outdir} ${label}

    # Check if MD5 is verified
    grep -m 1 "MD5 successfully checked" ${outdir}${label}/*.log
    assert_success
}

@test "GTDB assemblies" {
    outdir=${outprefix}gtdb-assemblies/
    label="test"

    # 5693 Trypanosoma cruzi
    run ./genome_updater.sh -e ${files_dir}simulated/assembly_summary_gtdb.txt -b ${label} -o ${outdir} -t ${threads} -M gtdb
    sanity_check ${outdir} ${label}

    # 1 out of 2 available on GTDB
    assert_equal $(count_files ${outdir} ${label}) 1
}

@test "Download taxdump gtdb" {
    outdir=${outprefix}download-taxdump-gtdb/
    label="test"

    run ./genome_updater.sh -d refseq -g archaea -D 20210101 -E 20220101 -b ${label} -o ${outdir} -t ${threads} -a -M gtdb
    sanity_check ${outdir} ${label}

    # Downloaded taxdump
    assert_file_exist ${outdir}${label}/ar53_taxonomy.tsv.gz
}

@test "Download taxdump ncbi" {
    outdir=${outprefix}download-taxdump-ncbi/
    label="test"

    run ./genome_updater.sh -d refseq -g protozoa -D 20210101 -E 20220101 -b ${label} -o ${outdir} -t ${threads} -a -M ncbi
    sanity_check ${outdir} ${label}

    # Downloaded taxdump
    assert_file_exist ${outdir}${label}/taxdump.tar.gz
}