#!/usr/bin/env bash

get_values_as() { # $1 assembly_summary file, $2 col
    grep -v "^#" ${1} | cut -f ${2}
}

count_lines_file(){ # $1 file
    grep -v "^#" ${1:-} | sed '/^\s*$/d' | wc -l | cut -f1 -d' '
}

count_files() { # $1 outdir, $2 label
    find_files ${1} ${2} | wc -l | cut -f1 -d' '
}

find_files() { # $1 outdir, $2 label
    find ${1}${2}/files/ -type f,l
}

sanity_check() { # $1 outdir, $2 label, [$3 number of file types]
    #
    # Check if run was successful and if default files were created
    #
    # Number of file types (default 1) to calculate the expected number of output files
    nfiles=${3:-1} 
    # Ran successfully
    assert_success
    # Created assembly_summary file 
    assert_file_exist ${1}${2}/assembly_summary.txt
    # Created history file 
    assert_file_exist ${1}history.tsv
    # Created link to current version of assembly_summary
    assert_link_exist ${1}assembly_summary.txt
    # Created log file
    assert_file_exist ${1}${2}/*.log
    # Created files folder
    assert_dir_exist ${1}${2}/files
    # Check file count based on assembly_summary
    assert_equal $(count_files ${1} ${2}) $(($(count_lines_file ${1}assembly_summary.txt) * ${nfiles}))
    # Check files in folder (if any)
    for file in $(find_files ${1} ${2}); do
        assert_file_not_empty $file
    done

}