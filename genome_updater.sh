#!/bin/bash
# The MIT License (MIT)
 
# Copyright (c) 2017 - Vitor C. Piro - PiroV@rki.de - vitorpiro@gmail.com
# Robert Koch-Institut, Germany
# All rights reserved.

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

version="0.2.0"

wget_tries=20
wget_timeout=1000
export wget_tries wget_timeout
export LC_NUMERIC="en_US.UTF-8"

#activate aliases in the script
shopt -s expand_aliases
alias sort="sort --field-separator=$'\t'"

get_taxdump()
{
    wget -qO- --tries="${wget_tries}" --read-timeout="${wget_timeout}" ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz > ${1}
}

get_new_taxdump()
{
    wget -qO- --tries="${wget_tries}" --read-timeout="${wget_timeout}" ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/new_taxdump/new_taxdump.tar.gz > ${1}
}

unpack() # parameter: ${1} file, ${2} output folder[, ${3} files to unpack]
{
    tar xf ${1} -C ${2} ${3}
}

get_assembly_summary() # parameter: ${1} assembly_summary file - return number of lines
{
    for d in ${database//,/ }
    do
        if [[ ! -z "${taxids}" || ! -z "${species}" ]]; then # Get complete assembly_summary for database
            wget --tries="${wget_tries}" --read-timeout="${wget_timeout}" -qO- ftp://ftp.ncbi.nlm.nih.gov/genomes/${d}/assembly_summary_${d}.txt | tail -n+3 >> "${1}"
        else
            for og in ${organism_group//,/ }
            do
                #special case: human
                if [[ "${og}" == "human" ]]
                then
                    og="vertebrate_mammalian/Homo_sapiens"
                fi
                wget --tries="${wget_tries}" --read-timeout="${wget_timeout}" -qO- ftp://ftp.ncbi.nlm.nih.gov/genomes/${d}/${og}/assembly_summary.txt | tail -n+3 >> "${1}"
            done
        fi
    done
    # Keep only selected species or taxid lineage
    if [[ ! -z "${species}" ]]
    then
        join -1 7 -2 1 <(sort -k 7,7 "${1}") <(echo "${species//,/$'\n'}" | sort -k 1,1) -t$'\t' -o "1.1,1.2,1.3,1.4,1.5,1.6,1.7,1.8,1.9,1.10,1.11,1.12,1.13,1.14,1.15,1.16,1.17,1.18,1.19,1.20,1.21,1.22" > "${1}_species"
        mv "${1}_species" "${1}"
    elif [[ ! -z "${taxids}" ]]    
    then
        join -1 6 -2 1 <(sort -k 6,6 "${1}") <(echo "${taxids//,/$'\n'}" | sort -k 1,1) -t$'\t' -o "1.1,1.2,1.3,1.4,1.5,1.6,1.7,1.8,1.9,1.10,1.11,1.12,1.13,1.14,1.15,1.16,1.17,1.18,1.19,1.20,1.21,1.22" > "${1}_taxids"
        mv "${1}_taxids" "${1}"
    fi
    wc -l "${1}" | cut -f1 -d' '
}

filter_assembly_summary() # parameter: ${1} assembly_summary file - return number of lines
{
    if [[ "${refseq_category}" != "all" || "${assembly_level}" != "all" ]]
    then
        awk -F "\t" -v refseq_category="${refseq_category}" -v assembly_level="${assembly_level}" 'BEGIN{if(refseq_category=="all") refseq_category=".*"; if(assembly_level=="all") assembly_level=".*"} $5 ~ refseq_category && $12 ~ assembly_level && $11=="latest" {print $0}' ${1} > "${1}_filtered"
        mv "${1}_filtered" ${1}
    fi
    wc -l ${1} | cut -f1 -d' '
}

list_files() # parameter: ${1} file, ${2} fields [assembly_accesion,url], ${3} extensions - returns assembly accession, url and filename (for all selected extensions)
{
    # Given an url returns the url and the filename for all extensions
    for extension in ${3//,/ }
    do
        cut --fields="${2}" ${1} | awk -F "\t" -v ext="${extension}" '{url_count=split($2,url,"/"); print $1 "\t" $2 "\t" url[url_count] "_" ext}'
    done
}

print_progress() # parameter: ${1} file number, ${2} total number of files
{
    if [ "${silent_progress}" -eq 0 ] && [ "${silent}" -eq 0 ] ; then printf "%8d/%d - " ${1} ${2}; fi #Only prints when not silent and not only progress
    if [ "${silent_progress}" -eq 1 ] || [ "${silent}" -eq 0 ] ; then printf "%6.2f%%\r" $(bc -l <<< "scale=4;(${1}/${2})*100"); fi #Always prints besides when it's silent
}
export -f print_progress #export it to be accessible to the parallel call

check_file_folder() # parameter: ${1} url, ${2} log (0->before download/1->after download) - returns 0 (ok) / 1 (error)
{
    file_name=$(basename ${1})
    # Check if file exists and if it has a size greater than zero (-s)
    if [ ! -s "${new_files_dir}${file_name}" ]; then
        if [ "${2}" -eq 1 ]; then echolog "${file_name} download failed [${1}]" "0"; fi
        # Remove file if exists (only zero-sized files)
        rm -vf ${new_files_dir}${file_name} >> ${log_file} 2>&1
        return 1
    else
        if [ "${2}" -eq 0 ]; then 
            echolog "${file_name} file found on the output folder [${new_files_dir}${file_name}]" "0"
        else
            echolog "${file_name} downloaded successfully [${1} -> ${new_files_dir}${file_name}]" "0"
        fi
        return 0
    fi
}
export -f check_file_folder #export it to be accessible to the parallel call

check_md5_ftp() # parameter: ${1} url - returns 0 (ok) / 1 (error)
{
    if [ "${check_md5}" -eq 1 ]; then # Only if md5 checking is activated
        md5checksums_url="$(dirname ${1})/md5checksums.txt" # ftp directory
        file_name=$(basename ${1}) # downloaded file name
        md5checksums_file=$(wget -qO- --tries="${wget_tries}" --read-timeout="${wget_timeout}" "${md5checksums_url}")
        if [ -z "${md5checksums_file}" ]; then
            echolog "${file_name} MD5checksum file download failed [${md5checksums_url}] - FILE KEPT"  "0"
            return 0
        else
            ftp_md5=$(echo "${md5checksums_file}" | grep "${file_name}" | cut -f1 -d' ')
            if [ -z "${ftp_md5}" ]; then
                echolog "${file_name} MD5checksum file not available [${md5checksums_url}] - FILE KEPT"  "0"
                return 0
            else
                file_md5=$(md5sum ${new_files_dir}${file_name} | cut -f1 -d' ')
                if [ "${file_md5}" != "${ftp_md5}" ]; then
                    echolog "${file_name} MD5 not matching [${md5checksums_url}] - FILE REMOVED"  "0"
                    # Remove file only when MD5 doesn't match
                    rm -v ${new_files_dir}${file_name} >> ${log_file} 2>&1
                    return 1
                else
                    # Outputs checked md5 only on log
                    echolog "${file_name} MD5 successfuly checked ${file_md5} [${md5checksums_url}]" "0"
                    return 0
                fi    
            fi
        fi
    else
        return 0
    fi
    
}
export -f check_md5_ftp #export it to be accessible to the parallel call

download_files() # parameter: ${1} file, ${2} fields [assembly_accesion,url] or field [url,filename], ${3} extension
{
    url_list_download=${working_dir}/url_list_download #Temporary url list of files to download in this call
    if [ -z "${3}" ] #direct download (url+file)
    then
        total_files=$(wc -l ${1} | cut -f1 -d' ')
        cut --fields="${2}" ${1} | tr '\t' '/' > ${url_list_download}
    else
        total_files=$(( $(wc -l ${1} | cut -f1 -d' ') * (n_formats+1) ))
        list_files ${1} ${2} ${3} | cut -f 2,3 | tr '\t' '/' > ${url_list_download}
    fi

    # parallel -k parameter keeps job output order (better for showing progress) but makes it a bit slower 
    log_parallel="${working_dir}/download_files.log"
    parallel --gnu --joblog ${log_parallel} -a ${url_list_download} -j ${threads} '
            ex=0
            dl=0
            if ! check_file_folder "{1}" "0"; then # Check if the file is already on the output folder (avoid redundant download)
                dl=1
            elif ! check_md5_ftp "{1}"; then # Check if the file already on folder has matching md5
                dl=1
            fi
            if [ "${dl}" -eq 1 ]; then # If file is not yet on folder, download it
                wget {1} --quiet --continue --tries="'${wget_tries}'" --read-timeout="'${wget_timeout}'" -P "'${new_files_dir}'"
                if ! check_file_folder "{1}" "1"; then # Check if file was downloaded
                    ex=1
                elif ! check_md5_ftp "{1}"; then # Check file md5
                    ex=1
                fi
            fi
            print_progress "{#}" "'${total_files}'"
            if [ "'${url_list}'" -eq 1 ]; then # Output URLs
                if [ "${ex}" -eq 1 ]; then
                    echo "{1}" >> "'${url_list_failed_file}'"
                else
                    echo "{1}" >> "'${url_list_downloaded_file}'"
                fi
            fi
            exit "${ex}"'
            print_progress "${total_files}" "${total_files}" #print final 100
            count_log="$(grep -c "^[0-9]" ${log_parallel})"
            failed_log="$(grep -c "^[0-9]" ${log_parallel} | cut -f 7 | grep -c "^1")"
            echolog " - Successfuly downloaded: $(( total_files - (total_files-count_log) - failed_log )) - Failed: $(( failed_log + (total_files-count_log) ))" "1"
    rm -f ${log_parallel} ${url_list_download}
}

remove_files() # parameter: ${1} file, ${2} fields [assembly_accesion,url] OR field [filename], ${3} extension
{
    if [ -z "${3}" ] #direct remove (filename)
    then
        cut --fields="${2}" ${1} | xargs --no-run-if-empty -I{} rm ${new_files_dir}{} -v >> ${log_file} 2>&1
    else
        list_files ${1} ${2} ${3} | cut -f 3 | xargs --no-run-if-empty -I{} rm ${new_files_dir}{} -v >> ${log_file} 2>&1
    fi
}

check_missing_files() # ${1} file, ${2} fields [assembly_accesion,url], ${3} extension - returns assembly accession, url and filename
{
    # Just returns if file doens't exist or if it's zero size
    list_files ${1} ${2} ${3} | xargs --no-run-if-empty -n3 sh -c 'if [ ! -s "'"${new_files_dir}"'${2}" ]; then echo "${0}\\t${1}\\t${2}"; fi'
}

check_complete_record() # parameters: ${1} file, ${2} field [assembly accession, url], ${3} extension - returns assembly accession, url
{
    expected_files=$(list_files ${1} ${2} ${3} | sort -k 3,3)
    join -1 3 -2 1 <(echo "${expected_files}" | sort -k 3,3) <(ls -1 "${new_files_dir}" | sort) -t$'\t' -o "1.1" -v 1 | sort | uniq | # Check for accessions with at least one missing file
    join -1 1 -2 1 <(echo "${expected_files}" | cut -f 1,2 | sort | uniq) - -t$'\t' -v 1 # Extract just assembly accession and url for complete entries (no missing files)
}

output_assembly_accession() # parameters: ${1} file, ${2} field [assembly accession, url], ${3} extension, ${4} mode (A/R) - returns assembly accession, url and mode
{
    check_complete_record ${1} ${2} ${3} | sed "s/^/${4}\t/" # add mode
}

output_sequence_accession() # parameters: ${1} file, ${2} field [assembly accession, url], ${3} extension, ${4} mode (A/R), ${5} assembly_summary (for taxid)
{
    join <(list_files ${1} ${2} "assembly_report.txt" | sort -k 1,1) <(check_complete_record ${1} ${2} ${3} | sort -k 1,1) -t$'\t' -o "1.1,1.3" | # List assembly accession and filename for all assembly_report.txt with complete record (no missing files) - returns assembly accesion, filename
    join - <(sort -k 1,1 ${5}) -t$'\t' -o "1.1,1.2,2.6" | # Get taxid {1} assembly accesion, {2} filename {3} taxid
    parallel --colsep "\t" -j ${threads} -k 'grep "^[^#]" "'"${new_files_dir}"'{2}" | tr -d "\r" | cut -f 5,7,9 | sed "s/^/{1}\\t/" | sed "s/$/\\t{3}/"' | # Retrieve info from assembly_report.txt and add assemby accession in the beggining and taxid at the end
    sed "s/^/${4}\t/" # Add mode A/R at the end    
}

exit_status() # parameters: ${1} # expected files, ${2} # current files
{
    if [[ ${conditional_exit} =~ ^[+-]?[0-9]*$ ]] ; then # INTEGER
        if [[ ${conditional_exit} -eq 0 ]] ; then # Condition off
            return 0
        elif [[ $(( $1-$2 )) -ge ${conditional_exit} ]] ; then
            return 1
        else
            return 0
        fi
    elif [[ ${conditional_exit} =~ ^[+-]?[0-9]+\.?[0-9]*$ ]] ; then # FLOAT
        if (( $(echo "((${1}-${2})/${1}) >= ${conditional_exit} " | bc -l) )); then
            return 1
        else
            return 0
        fi
    else
        return 0
    fi
}

echolog() # parameters: ${1} text, ${2} STDOUT (0->no/1->yes)
{
    if [[ "${2}" -eq "1" ]] && [ "${silent}" -eq 0 ]; then
        echo "${1}" # STDOUT
    fi
    echo "${1}" >> ${log_file} # LOG

}
export -f echolog #export it to be accessible to the parallel call

# Defaults
database="refseq"
organism_group=""
refseq_category="all"
assembly_level="all"
file_formats="assembly_report.txt"
download_taxonomy=0
delete_extra_files=0
check_md5=0
updated_assembly_accession=0
updated_sequence_accession=0
url_list=0
just_check=0
just_fix=0
conditional_exit=0
silent=0
silent_progress=0
working_dir=""
label=""
threads=1

function showhelp {
    echo "genome_updater v${version} by Vitor C. Piro (vitorpiro@gmail.com, http://github.com/pirovc)"
    echo
    echo $' -g Organism group (one or more comma-separated entries) [archaea, bacteria, fungi, human (also contained in vertebrate_mammalian), invertebrate, metagenomes (genbank), other (synthetic genomes - only genbank), plant, protozoa, vertebrate_mammalian, vertebrate_other, viral (only refseq)]. Example: archaea,bacteria'
    echo $'    or Species level taxids (one or more comma-separated entries). Example: species:622,562'
    echo $'    or Any level taxids - lineage will be generated (one or more comma-separated entries). Example: taxids:620,649776'
    echo
    echo $' -d Database [genbank, refseq]\n\tDefault: refseq'
    echo $' -c RefSeq Category [all, reference genome, representative genome, na]\n\tDefault: all'
    echo $' -l Assembly level [all, Complete Genome, Chromosome, Scaffold, Contig]\n\tDefault: all'
    echo $' -f File formats [genomic.fna.gz,assembly_report.txt, ... - check ftp://ftp.ncbi.nlm.nih.gov/genomes/all/README.txt for all file formats]\n\tDefault: assembly_report.txt'
    echo
    echo $' -a Download the current version of the Taxonomy database (taxdump.tar.gz)'
    echo $' -k Just check for updates, keep current version'
    echo $' -i Fix or recover files based on the current version or external file (assembly_summary.txt), do not look for updates'
    echo $' -x Delete any extra files inside the output folder'
    echo $' -m Check md5 (after download only)'
    echo
    echo $' -u Output list of updated assembly accessions (Added/Removed, assembly accession, url)'
    echo $' -r Output list of updated sequence accessions (Added/Removed, assembly accession, genbank accession, refseq accession, sequence length, taxid). Only available when file assembly_report.txt selected and successfuly downloaded'
    echo $' -p Output list of URLs for downloaded and failed files'
    echo
    echo $' -n Conditional exit status. Exit Code = 1 if more than N files failed to download (integer for file number, float for percentage, 0 -> off)\n\tDefault: 0'
    echo
    echo $' -s Silent output'
    echo $' -w Silent output with download progress (%) and download version at the end'
    echo $' -o Working directory \n\tDefault: ./tmp.XXXXXXXXXX'
    echo $' -b Output label\n\tDefault: current timestamp (YYYY-MM-DD_HH-MM-SS)'
    echo $' -t Threads\n\tDefault: 1'
    echo
}

# Check for required tools
tools=( "getopts" "parallel" "awk" "wget" "join" "bc" "md5sum" "xargs" "tar" )
for t in "${tools[@]}"
do
    command -v ${t} >/dev/null 2>/dev/null || { echo ${t} not found; exit 1; }
done

OPTIND=1 # Reset getopts
while getopts "d:g:c:l:o:b:t:f:n:akixmurpswh" opt; do
  case ${opt} in
    d) database=${OPTARG} ;;
    g) organism_group=${OPTARG// } ;; #remove spaces
    c) refseq_category=${OPTARG} ;;
    l) assembly_level=${OPTARG} ;;
    o) working_dir=${OPTARG} ;;
    b) label=${OPTARG} ;;
    t) threads=${OPTARG} ;;
    f) file_formats=${OPTARG// } ;; #remove spaces
    a) download_taxonomy=1 ;;
    k) just_check=1 ;;
    i) just_fix=1 ;;
    x) delete_extra_files=1 ;;
    m) check_md5=1 ;;
    u) updated_assembly_accession=1 ;;
    r) updated_sequence_accession=1 ;;
    p) url_list=1 ;;
    n) conditional_exit=${OPTARG} ;;
    s) silent=1 ;;
    w) silent_progress=1 ;;
    h|\?) showhelp; exit 1 ;;
    :) echo "Option -${OPTARG} requires an argument." >&2; exit 1 ;;
  esac
done
if [ ${OPTIND} -eq 1 ]; then showhelp; exit 1; fi
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

# Check parameters
valid_databases=( "genbank" "refseq" )
for d in ${database//,/ }
do
    if [[ ! " ${valid_databases[@]} " =~ " ${d} " ]]; then
        echo "Database ${d} not valid"; exit 1;
    fi
done

# mandatory organism group/taxids
if [[ -z "${organism_group}" && "${just_fix}" -eq 0 ]]; then
    echo "Please inform the organism group, species or taxids (comma separated) with the -g parameter"; exit 1;
fi

species=""
taxids=""
if [[ " ${organism_group} " =~ "taxids:" ]]; then
    taxids=${organism_group/taxids:/}
    if [[ -z "${taxids}" ]]; then
        echo "Invalid taxid - ${taxids}"; exit 1; # TODO validate taxid?
    fi
elif [[ " ${organism_group} " =~ "species:" ]]; then
    species=${organism_group/species:/}
    if [[ -z "${species}" ]]; then
        echo "Invalid species taxids - ${species}"; exit 1; # TODO validate taxid?
    fi
else
    valid_organism_groups=( "archaea" "bacteria" "fungi" "human" "invertebrate" "metagenomes" "other" "plant" "protozoa" "vertebrate_mammalian" "vertebrate_other" "viral" )
    for og in ${organism_group//,/ }
    do
        if [[ ! " ${valid_organism_groups[@]} " =~ " ${og} " ]]; then
            echo "Organism group - ${og} - not valid"; exit 1;
        fi
    done
fi

valid_refseq_categories=( "all" "reference genome" "representative genome" "na" )
if [[ ! " ${valid_refseq_categories[@]} " =~ " ${refseq_category} " ]]; then
    echo "RefSeq category - ${refseq_category} - not valid"; exit 1;
fi
valid_assembly_levels=( "all" "Complete Genome" "Chromosome" "Scaffold" "Contig" )
if [[ ! " ${valid_assembly_levels[@]} " =~ " ${assembly_level} " ]]; then
    echo "Assembly level - ${assembly_level} - not valid"; exit 1;
fi

# Create working directory
if [[ -z "${working_dir}" ]]; then
    working_dir=$(mktemp -d -p .) # default
else
    mkdir -p ${working_dir} #user input
fi
working_dir=$(readlink -m ${working_dir})/

default_assembly_summary=${working_dir}/assembly_summary.txt

# If fixing/recovering, need to have assembly_summary.txt
if [[ "${just_fix}" -eq 1 && ! -f "${default_assembly_summary}" ]]; then
    echo "Fix/recover mode activated but no assembly_summary.txt found [${working_dir}]"; exit 1;
fi

# label (deafult with timestamp)
if [[ -z "${label}" ]]; then
    new_label=$(date +%Y-%m-%d_%H-%M-%S)
else
    new_label=${label}
fi

# output prefix for this run
new_output_prefix=${working_dir}/${new_label}/
new_assembly_summary=${new_output_prefix}assembly_summary.txt

if [ -d "${new_output_prefix}" ]; then
    echo "Directory with label \"${new_label}\" already exists in the working directory [$(readlink -m ${new_output_prefix})]"; exit 1;
fi

# output files for this run
new_files_dir=${new_output_prefix}files/
mkdir -p ${new_files_dir}

# log file for this run
log_file=${new_output_prefix}log.txt

# formats selected
n_formats=$(echo ${file_formats} | tr -cd , | wc -c)

# silent mode
if [ "${silent}" -eq 1 ] ; then 
    silent_progress=0
elif [ "${silent_progress}" -eq 1 ] ; then 
    silent=1
fi

# To be accessible in functions called by parallel
export new_files_dir log_file working_dir check_md5 silent silent_progress

echolog "----------------------------------------" "1"
echolog "      genome_updater version: ${version}" "1"
echolog "----------------------------------------" "1"
echolog "Database: ${database}" "0"
echolog "Organims group: ${organism_group}" "0"
echolog "RefSeq category: ${refseq_category}" "0"
echolog "Assembly level: ${assembly_level}" "0"
echolog "File formats: ${file_formats}" "0"
echolog "Download taxonomy: ${download_taxonomy}" "0"
echolog "Just check for updates: ${just_check}" "0"
echolog "Just fix/recover current version: ${just_fix}" "0"
echolog "Delete extra files: ${delete_extra_files}" "0"
echolog "Check md5: ${check_md5}" "0"
echolog "Output updated assembly accessions: ${updated_assembly_accession}" "0"
echolog "Output updated sequence accessions: ${updated_sequence_accession}" "0"
echolog "Conditional exit status: ${conditional_exit}" "0"
echolog "Silent ${silent}" "0"
echolog "Silent with progress and version: ${silent_progress}" "0"
echolog "Output URLs: ${url_list}" "0"
echolog "Threads: ${threads}" "0"
echolog "Working directory: ${working_dir}" "0"
echolog "Label: ${new_label}" "0"
echolog "----------------------------------------" "0"
    
# PROGRAM MODE (check, fix, new or update)
if [ "${just_check}" -eq 1 ]; then
    echolog " > CHECK < " "1"
elif [ "${just_fix}" -eq 1 ]; then
    echolog " > FIX/RECOVER < " "1"
elif [ ! -f "${default_assembly_summary}" ]; then
    echolog " > NEW < " "1"
else
    echolog " > UPDATE < " "1"
fi
echolog "" "1"
echolog "Working directory: ${working_dir}" "1"
echolog "" "1"

if [ "${updated_assembly_accession}" -eq 1 ]; then updated_assembly_accession_file=${new_output_prefix}updated_assembly_accession.txt; fi
if [ "${updated_sequence_accession}" -eq 1 ]; then updated_sequence_accession_file=${new_output_prefix}updated_sequence_accession.txt; fi
if [ "${url_list}" -eq 1 ]; then
    url_list_downloaded_file=${new_output_prefix}url_list_downloaded.txt
    url_list_failed_file=${new_output_prefix}url_list_failed.txt
fi

# download new_taxdump and get all the lineage from the input taxid
if [[ ! -z "${taxids}" ]]; then
    echolog "Downloading taxdump and generating lineage" "1"
    tmp_new_taxdump="${new_output_prefix}new_taxdump.tar.gz"
    tmp_taxidlineage="${working_dir}/taxidlineage.dmp"
    get_new_taxdump "${tmp_new_taxdump}"
    unpack "${tmp_new_taxdump}" "${working_dir}" "taxidlineage.dmp"
    tmp_lineage=${working_dir}/lineage.txt
    for tx in ${taxids//,/ }; do
        grep "[^0-9]${tx}[^0-9]" "${tmp_taxidlineage}" | cut -f 1 >> ${tmp_lineage} #get only taxids in the lineage section
    done
    tx_lines=$(wc -l ${tmp_lineage} | cut -f1 -d' ')
    echolog " - ${tx_lines} children taxids in the lineage of: ${taxids}" "1"
    taxids=$(sort ${tmp_lineage} | uniq | tr '\n' ',')${taxids} # put lineage back into the taxids variable with the provided taxids
    rm ${tmp_new_taxdump} ${tmp_taxidlineage} ${tmp_lineage}
fi

# new download
if [ ! -f "${default_assembly_summary}" ]; then

    echolog "Downloading assembly summary [$(basename ${new_label})]..." "1"
    all_lines=$(get_assembly_summary "${new_assembly_summary}")
    filtered_lines=$(filter_assembly_summary "${new_assembly_summary}")
    echolog " - $((all_lines-filtered_lines)) out of ${all_lines} entries removed [RefSeq category: ${refseq_category}, Assembly level: ${assembly_level}, Version status: latest]" "1"
    echolog " - ${filtered_lines} entries available" "1"
    
    if [ "${just_check}" -eq 1 ]; then
        rm ${new_assembly_summary} ${log_file}
        if [ ! "$(ls -A ${new_files_dir})" ]; then rm -r ${new_files_dir}; fi #Remove folder that was just created (if there's nothing in it)
        if [ ! "$(ls -A ${new_output_prefix})" ]; then rm -r ${new_output_prefix}; fi #Remove folder that was just created (if there's nothing in it)
        if [ ! "$(ls -A ${working_dir})" ]; then rm -r ${working_dir}; fi #Remove folder that was just created (if there's nothing in it)
    else
        # link new assembly as the default
        ln -s -r "${new_assembly_summary}" "${default_assembly_summary}"
        
        if [[ "${filtered_lines}" -gt 0 ]] ; then
            echolog " - Downloading $((filtered_lines*(n_formats+1))) files with ${threads} threads..."    "1"
            download_files "${new_assembly_summary}" "1,20" "${file_formats}"

            # UPDATED INDICES assembly accession
            if [ "${updated_assembly_accession}" -eq 1 ]; then 
                output_assembly_accession "${new_assembly_summary}" "1,20" "${file_formats}" "A" > ${updated_assembly_accession_file}
            fi
            # UPDATED INDICES sequence accession
            if [[ "${file_formats}" =~ "assembly_report.txt" ]] && [ "${updated_sequence_accession}" -eq 1 ]; then
                output_sequence_accession "${new_assembly_summary}" "1,20" "${file_formats}" "A" "${new_assembly_summary}" > ${updated_sequence_accession_file}
            fi
        fi

        if [ "${download_taxonomy}" -eq 1 ]; then
            echolog "" "1"
            echolog "Downloading current Taxonomy database [${new_label}/taxdump.tar.gz] ..." "1"
            get_taxdump "${new_output_prefix}taxdump.tar.gz"
            echolog " - OK" "1"
        fi
    fi
    
else # update

    # Current version info
    current_assembly_summary=$(readlink -m ${default_assembly_summary})
    current_output_prefix=$(dirname ${current_assembly_summary})/
    current_files_dir=${current_output_prefix}files/
    current_label=$(basename ${current_output_prefix})

    # Just do linking when assembly_summary is a link (not recovery mode)
    if [[ -L "${default_assembly_summary}" ]]; then
	    # Link versions (current and new)
	    echolog "Linking versions [${current_label} --> ${new_label}]..." "1"
	    echolog "" "1"
	    ln -s -r "${current_files_dir}"* "${new_files_dir}"
	fi

    # Check for missing files on current version
    echolog "Checking for missing files..." "1"
    missing=${working_dir}/missing.txt
    check_missing_files ${current_assembly_summary} "1,20" "${file_formats}" > ${missing} # assembly accession, url, filename
    missing_lines=$(wc -l ${missing} | cut -f1 -d' ')
    if [ "${missing_lines}" -gt 0 ]; then
        echolog " - ${missing_lines} missing files from current version [${current_label}]" "1"
        if [ "${just_check}" -eq 0 ]; then
            echolog " - Downloading ${missing_lines} files with ${threads} threads..."    "1"
            download_files "${missing}" "2,3"

            # UPDATED INDICES assembly accession
            if [ "${updated_assembly_accession}" -eq 1 ]; then 
                output_assembly_accession "${missing}" "1,2" "${file_formats}" "A" > ${new_output_prefix}missing_assembly_accession.txt
            fi
            # UPDATED INDICES sequence accession for missing files
            if [[ "${file_formats}" =~ "assembly_report.txt" ]] && [ "${updated_sequence_accession}" -eq 1 ]; then
                output_sequence_accession "${missing}" "1,2" "${file_formats}" "A" "${current_assembly_summary}" > ${new_output_prefix}missing_sequence_accession.txt
            fi
        fi
    else
        echolog " - None" "1"
    fi
    echolog "" "1"
    rm ${missing}
    
    echolog "Checking for extra files..." "1"
    extra=${working_dir}/extra.txt
    join <(ls -1 ${new_files_dir} | sort) <(list_files ${current_assembly_summary} "1,20" "${file_formats}" | cut -f 3 | sed -e 's/.*\///' | sort) -v 1 > ${extra}
    extra_lines=$(wc -l ${extra} | cut -f1 -d' ')
    if [ "${extra_lines}" -gt 0 ]; then
        echolog " - ${extra_lines} extra files on current folder [${new_files_dir}]" "1"
        if [ "${just_check}" -eq 0 ]; then
            if [ "${delete_extra_files}" -eq 1 ]; then
                echolog " - Deleting ${extra_lines} files..." "1"
                remove_files "${extra}" "1"
                extra_lines=0
            else
                cat ${extra} >> ${log_file} #List file in the log when -x is not enabled
            fi
        fi
    else
        echolog " - None" "1"
    fi
    echolog "" "1"
    rm ${extra}
    
    if [ "${just_fix}" -eq 1 ]; then
    	# if just fixing, keep same assembly summary in the new version
    	cp "${default_assembly_summary}" "${new_assembly_summary}"
    else
        # Check for updates on NCBI
        echolog "Downloading assembly summary [${new_label}]..." "1"
        all_lines=$(get_assembly_summary "${new_assembly_summary}")
        filtered_lines=$(filter_assembly_summary "${new_assembly_summary}")
        echolog " - $((all_lines-filtered_lines)) out of ${all_lines} entries removed [RefSeq category: ${refseq_category}, Assembly level: ${assembly_level}, Version status: latest]]" "1"
        echolog " - ${filtered_lines} entries available" "1"
        
        update=${working_dir}/update.txt
        delete=${working_dir}/delete.txt
        new=${working_dir}/new.txt
        # UPDATED (verify if version or date changed)
        join <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); gsub("/","",$15); print $1,acc_ver,$15,$20}' ${new_assembly_summary} | sort -k 1,1) <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); gsub("/","",$15); print $1,acc_ver,$15,$20}' ${current_assembly_summary} | sort -k 1,1) -o "1.2,1.3,1.4,2.2,2.3,2.4" | awk '{if($2>$5 || $1!=$4){print $1"\t"$3"\t"$4"\t"$6}}' > ${update}
        update_lines=$(wc -l ${update} | cut -f1 -d' ')
        # DELETED
        join <(cut -f 1 ${new_assembly_summary} | sed 's/\.[0-9]*//g' | sort) <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); print $1,acc_ver,$20}' ${current_assembly_summary} | sort -k 1,1) -v 2 -o "2.2,2.3" | tr ' ' '\t' > ${delete}
        delete_lines=$(wc -l ${delete} | cut -f1 -d' ')
        # NEW
        join <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); print $1,acc_ver,$20}' ${new_assembly_summary} | sort -k 1,1) <(cut -f 1 ${current_assembly_summary} | sed 's/\.[0-9]*//g' | sort) -o "1.2,1.3" -v 1 | tr ' ' '\t' > ${new}
        new_lines=$(wc -l ${new} | cut -f1 -d' ')
        
        echolog " - ${update_lines} updated, ${delete_lines} deleted, ${new_lines} new entries" "1"

        if [ "${just_check}" -eq 1 ]; then
            rm ${update} ${delete} ${new}
            rm -r "${new_output_prefix}"
        else
            # UPDATED INDICES assembly accession
            if [ "${updated_assembly_accession}" -eq 1 ]; then 
                output_assembly_accession "${update}" "3,4" "${file_formats}" "R" > ${updated_assembly_accession_file} 
                output_assembly_accession "${delete}" "1,2" "${file_formats}" "R" >> ${updated_assembly_accession_file}
            fi
            # UPDATED INDICES sequence accession (removed entries - do it before deleting them)
            if [[ "${file_formats}" =~ "assembly_report.txt" ]] && [ "${updated_sequence_accession}" -eq 1 ]; then
                output_sequence_accession "${update}" "3,4" "${file_formats}" "R" "${default_assembly_summary}" > ${updated_sequence_accession_file}
                output_sequence_accession "${delete}" "1,2" "${file_formats}" "R" "${default_assembly_summary}" >> ${updated_sequence_accession_file}
            fi
            
            # Execute updates
            if [ "${update_lines}" -gt 0 ]; then
                echolog " - UPDATE: Deleting $((update_lines*(n_formats+1))) files ..." "1"
                # delete old version
                remove_files "${update}" "3,4" "${file_formats}"
                echolog " - UPDATE: Downloading $((update_lines*(n_formats+1))) files with ${threads} threads..." "1"
                # download new version
                download_files "${update}" "1,2" "${file_formats}"
            fi
            if [ "${delete_lines}" -gt 0 ]; then
                echolog " - DELETE: Deleting $((delete_lines*(n_formats+1))) files..." "1"
                remove_files "${delete}" "1,2" "${file_formats}"
            fi
            if [ "${new_lines}" -gt 0 ]; then
                echolog " - NEW: Downloading $((new_lines*(n_formats+1))) files with ${threads} threads..."    "1"
                download_files "${new}" "1,2" "${file_formats}"
            fi 

            # UPDATED INDICES assembly accession (added entries - do it after downloading them)
            if [ "${updated_assembly_accession}" -eq 1 ]; then 
                output_assembly_accession "${update}" "1,2" "${file_formats}" "A" >> ${updated_assembly_accession_file}
                output_assembly_accession "${new}" "1,2" "${file_formats}" "A" >> ${updated_assembly_accession_file}
            fi
            # UPDATED INDICES sequence accession (added entries - do it after downloading them)
            if [[ "${file_formats}" =~ "assembly_report.txt" ]] && [ "${updated_sequence_accession}" -eq 1 ]; then
                output_sequence_accession "${update}" "1,2" "${file_formats}" "A" "${new_assembly_summary}">> ${updated_sequence_accession_file}
                output_sequence_accession "${new}" "1,2" "${file_formats}" "A" "${new_assembly_summary}" >> ${updated_sequence_accession_file}
            fi
            
            if [ "${download_taxonomy}" -eq 1 ]; then
                echolog "" "1"
                echolog "Downloading current Taxonomy database [${new_label}/taxdump.tar.gz] ..." "1"
                get_taxdump "${new_output_prefix}taxdump.tar.gz"
                echolog " - OK" "1"
            fi
            rm ${update} ${delete} ${new}

        fi
    fi
	
	if [ "${just_check}" -eq 0 ]; then
		# update default assembly summary (not when checking)
	    rm "${default_assembly_summary}"
	    ln -s -r "${new_assembly_summary}" "${default_assembly_summary}"
	fi

fi

if [ "${just_check}" -eq 0 ]; then
    echolog "" "1"
    if [ -z "${extra_lines}" ]; then extra_lines=0; fi # define extra_lines if non-existent
    expected_files=$(( $(wc -l "${default_assembly_summary}" | cut -f1 -d' ')*(n_formats+1) )) # From assembly summary * file formats
    current_files=$(( $(ls ${new_files_dir} | wc -l | cut -f1 -d' ') - extra_lines )) # From current folder - extra files
    # Check if the valid amount of files on folder amount of files on folder
    if [ "$(( expected_files - current_files ))" -gt 0 ]; then
        echolog "# $(( expected_files-current_files )) out of ${expected_files} failed" "1"
    else
        echolog "# All ${expected_files} files were successfully obtained" "1"
    fi
    if [ "${extra_lines}" -gt 0 ]; then
        echolog "# There are ${extra_lines} extra files in the output folder [${new_files_dir}] (to delete them, re-run your command with: -i -x)" "1"
    fi
    echolog "# Check the log file for more details: ${log_file}" "1"
    echolog "" "1"
    echolog "Done. Current version:" "1"
    echolog "$(dirname $(readlink -m ${default_assembly_summary}))" "1"
    if [ "${silent_progress}" -eq 1 ] ; then
        echo "$(dirname $(readlink -m ${default_assembly_summary}))"
    fi
    # Exit conditional status
    exit $(exit_status ${expected_files} ${current_files})
fi
