#!/bin/bash
set -euo pipefail
IFS=$' '

# The MIT License (MIT)
 
# Copyright (c) 2020 - Vitor C. Piro - vitorpiro@gmail.com
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

version="0.2.2"

wget_tries=${wget_tries:-3}
wget_timeout=${wget_timeout:-120}
export wget_tries wget_timeout
export LC_NUMERIC="en_US.UTF-8"

#activate aliases in the script
shopt -s expand_aliases
alias sort="sort --field-separator=$'\t'"

get_taxdump()
{
    wget -qO- --tries="${wget_tries}" --read-timeout="${wget_timeout}" "ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz" > ${1}
}

get_new_taxdump()
{
    wget -qO- --tries="${wget_tries}" --read-timeout="${wget_timeout}" "ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/new_taxdump/new_taxdump.tar.gz" > ${1}
}

unpack() # parameter: ${1} file, ${2} output folder[, ${3} files to unpack]
{
    tar xf "${1}" -C "${2}" "${3}"
}

count_lines(){ # parameter: ${1} file - return number of lines
    echo ${1:-} | sed '/^\s*$/d' | wc -l | cut -f1 -d' '
}

count_lines_file(){ # parameter: ${1} file - return number of lines
    sed '/^\s*$/d' ${1:-} | wc -l | cut -f1 -d' '
}

parse_new_taxdump() # parameter: ${1} taxids - return all taxids on of provided taxids
{
	taxids=${1}
	echolog "Downloading taxdump and generating lineage" "0"
    tmp_new_taxdump="${target_output_prefix}new_taxdump.tar.gz"
    tmp_taxidlineage="${working_dir}taxidlineage.dmp"
    get_new_taxdump "${tmp_new_taxdump}"
    unpack "${tmp_new_taxdump}" "${working_dir}" "taxidlineage.dmp"
    tmp_lineage=${working_dir}lineage.tmp
    for tx in ${taxids//,/ }; do
        txids_lin=$(grep "[^0-9]${tx}[^0-9]" "${tmp_taxidlineage}" | cut -f 1) #get only taxids in the lineage section
        echolog " - $(count_lines "${txids_lin}") children taxids in the lineage of ${tx}" "0"
        echo "${txids_lin}" >> "${tmp_lineage}" 
    done
    lineage_taxids=$(sort ${tmp_lineage} | uniq | tr '\n' ',')${taxids} # put lineage back into the taxids variable with the provided taxids
    rm "${tmp_new_taxdump}" "${tmp_taxidlineage}" "${tmp_lineage}"
    echo "${lineage_taxids}"
}

get_assembly_summary() # parameter: ${1} assembly_summary file, ${2} database, ${3} organism_group - return number of lines
{
    species=""
    taxids=""
	# check if is there is species or taxids
	if [[ " ${3} " =~ "species:" ]]; then species="${3/species:/}"; fi
	if [[ " ${3} " =~ "taxids:" ]]; then taxids="${3/taxids:/}"; fi  
    for d in ${2//,/ }
    do
        if [[ ! -z "${taxids}" || ! -z "${species}" ]]; then # Get complete assembly_summary for database
            wget --tries="${wget_tries}" --read-timeout="${wget_timeout}" -qO- ftp://ftp.ncbi.nlm.nih.gov/genomes/${d}/assembly_summary_${d}.txt | tail -n+3 >> "${1}"
        else
            for og in ${3//,/ }
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
    if [[ ! -z "${species}" ]]; then
        join -1 7 -2 1 <(sort -k 7,7 "${1}") <(echo "${species//,/$'\n'}" | sort -k 1,1) -t$'\t' -o "1.1,1.2,1.3,1.4,1.5,1.6,1.7,1.8,1.9,1.10,1.11,1.12,1.13,1.14,1.15,1.16,1.17,1.18,1.19,1.20,1.21,1.22" > "${1}_species"
        mv "${1}_species" "${1}"
    elif [[ ! -z "${taxids}" ]]; then
    	lineage_taxids=$(parse_new_taxdump "${taxids}")
        join -1 6 -2 1 <(sort -k 6,6 "${1}") <(echo "${lineage_taxids//,/$'\n'}" | sort -k 1,1) -t$'\t' -o "1.1,1.2,1.3,1.4,1.5,1.6,1.7,1.8,1.9,1.10,1.11,1.12,1.13,1.14,1.15,1.16,1.17,1.18,1.19,1.20,1.21,1.22" > "${1}_taxids"
        mv "${1}_taxids" "${1}"
    fi
    count_lines_file "${1}"
}

filter_assembly_summary() # parameter: ${1} assembly_summary file - return number of lines
{
    if [[ "${refseq_category}" != "all" || "${assembly_level}" != "all" ]]
    then
        awk -F "\t" -v refseq_category="${refseq_category}" -v assembly_level="${assembly_level}" 'BEGIN{if(refseq_category=="all") refseq_category=".*"; if(assembly_level=="all") assembly_level=".*"} $5 ~ refseq_category && $12 ~ assembly_level && $11=="latest" {print $0}' "${1}" > "${1}_filtered"
        mv "${1}_filtered" "${1}"
    fi
    count_lines_file "${1}"
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
    if [ ! -s "${target_output_prefix}${files_dir}${file_name}" ]; then
        if [ "${2}" -eq 1 ]; then echolog "${file_name} download failed [${1}]" "0"; fi
        # Remove file if exists (only zero-sized files)
        rm -vf "${target_output_prefix}${files_dir}${file_name}" >> "${log_file}" 2>&1
        return 1
    else
        if [ "${2}" -eq 0 ]; then 
            echolog "${file_name} file found on the output folder [${target_output_prefix}${files_dir}${file_name}]" "0"
        else
            echolog "${file_name} downloaded successfully [${1} -> ${target_output_prefix}${files_dir}${file_name}]" "0"
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
                file_md5=$(md5sum ${target_output_prefix}${files_dir}${file_name} | cut -f1 -d' ')
                if [ "${file_md5}" != "${ftp_md5}" ]; then
                    echolog "${file_name} MD5 not matching [${md5checksums_url}] - FILE REMOVED"  "0"
                    # Remove file only when MD5 doesn't match
                    rm -v "${target_output_prefix}${files_dir}${file_name}" >> ${log_file} 2>&1
                    return 1
                else
                    # Outputs checked md5 only on log
                    echolog "${file_name} MD5 successfully checked ${file_md5} [${md5checksums_url}]" "0"
                    return 0
                fi    
            fi
        fi
    else
        return 0
    fi
    
}
export -f check_md5_ftp #export it to be accessible to the parallel call

download() # parameter: ${1} url, ${2} job number, ${3} total files, ${4} url_success_download
{
    ex=0
    dl=0
    if ! check_file_folder ${1} "0"; then # Check if the file is already on the output folder (avoid redundant download)
        dl=1
    elif ! check_md5_ftp ${1}; then # Check if the file already on folder has matching md5
        dl=1
    fi
    if [ "${dl}" -eq 1 ]; then # If file is not yet on folder, download it
        wget ${1} --quiet --continue --tries="${wget_tries}" --read-timeout="${wget_timeout}" -P "${target_output_prefix}${files_dir}"
        if ! check_file_folder ${1} "1"; then # Check if file was downloaded
            ex=1
        elif ! check_md5_ftp ${1}; then # Check file md5
            ex=1
        fi
    fi
    print_progress ${2} ${3}
    if [ "${ex}" -eq 0 ]; then
        echo ${1} >> ${4}
    fi
}
export -f download

download_files() # parameter: ${1} file, ${2} fields [assembly_accesion,url] or field [url,filename], ${3} extension
{
    url_list_download=${working_dir}url_list_download.tmp #Temporary url list of files to download in this call
    url_success_download=${working_dir}url_success_download.tmp #Temporary url list of downloaded files
    touch ${url_success_download}
    # sort files to get all files for the same entry in sequence, in case of failure 
    if [ -z ${3:-} ] #direct download (url+file)
    then
        total_files=$(count_lines_file ${1})
        cut --fields="${2}" ${1} | tr '\t' '/' | sort > "${url_list_download}"
    else
        total_files=$(( $(count_lines_file ${1}) * (n_formats+1) ))
        list_files ${1} ${2} ${3} | cut -f 2,3 | tr '\t' '/' | sort > "${url_list_download}"
    fi

    # parallel -k parameter keeps job output order (better for showing progress) but makes it a bit slower 
    # send url, job number and total files (to print progress)
    parallel --gnu -a ${url_list_download} -j ${threads} download "{}" "{#}" "${total_files}" "${url_success_download}"

    print_progress ${total_files} ${total_files} #print final 100%

    downloaded_count=$(count_lines_file "${url_success_download}")
    failed_count=$(( total_files - downloaded_count ))
    if [ "${url_list}" -eq 1 ]; then # Output URLs
        # add failed urls to log
        join <(sort "${url_list_download}") <(sort "${url_success_download}") -v 1 >> "${target_output_prefix}${timestamp}_url_failed.txt"
        # add successful downloads from this run to the log
        cat "${url_success_download}" >> "${target_output_prefix}${timestamp}_url_downloaded.txt"
    fi
    echolog " - ${downloaded_count}/${total_files} files successfully downloaded" "1"
    rm -f ${url_list_download} ${url_success_download}
}

remove_files() # parameter: ${1} file, ${2} fields [assembly_accesion,url] OR field [filename], ${3} extension
{
    if [ -z ${3:-} ] #direct remove (filename)
    then
        cut --fields="${2}" ${1} | xargs --no-run-if-empty -I{} rm ${target_output_prefix}${files_dir}{} -v >> ${log_file} 2>&1
    else
        list_files ${1} ${2} ${3} | cut -f 3 | xargs --no-run-if-empty -I{} rm ${target_output_prefix}${files_dir}{} -v >> ${log_file} 2>&1
    fi
}

check_missing_files() # ${1} file, ${2} fields [assembly_accesion,url], ${3} extension - returns assembly accession, url and filename
{
    # Just returns if file doens't exist or if it's zero size
    list_files ${1} ${2} ${3} | xargs --no-run-if-empty -n3 sh -c 'if [ ! -s "'"${target_output_prefix}${files_dir}"'${2}" ]; then echo "${0}\\t${1}\\t${2}"; fi'
}

check_complete_record() # parameters: ${1} file, ${2} field [assembly accession, url], ${3} extension - returns assembly accession, url
{
    expected_files=$(list_files ${1} ${2} ${3} | sort -k 3,3)
    join -1 3 -2 1 <(echo "${expected_files}" | sort -k 3,3) <(ls -1 "${target_output_prefix}${files_dir}" | sort) -t$'\t' -o "1.1" -v 1 | sort | uniq | # Check for accessions with at least one missing file
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
    parallel --colsep "\t" -j ${threads} -k 'grep "^[^#]" "'"${target_output_prefix}${files_dir}"'{2}" | tr -d "\r" | cut -f 5,7,9 | sed "s/^/{1}\\t/" | sed "s/$/\\t{3}/"' | # Retrieve info from assembly_report.txt and add assemby accession in the beggining and taxid at the end
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
    elif [ $1 -gt 0 ] && [ $2 -eq 0 ]; then # all failed
        return 1
    else
        return 0
    fi
}

echolog() # parameters: ${1} text, ${2} STDOUT (0->no/1->yes)
{
    if [[ "${2}" -eq "1" ]] && [ "${silent}" -eq 0 ]; then
        echo "${1}" # STDOUT
    fi
    echo "${1}" >> "${log_file}" # LOG
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
external_assembly_summary=""
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
    echo $' -k Dry-run, no data is downloaded or updated - just checks for available sequences and changes'
    echo $' -i Fix failed downloads or any incomplete data from a previous run, keep current version'
    echo $' -x Allow the deletion of extra files if some are found in the repository folder'
    echo
    echo $' -u Report of updated assembly accessions (Added/Removed, assembly accession, url)'
    echo $' -r Report of updated sequence accessions (Added/Removed, assembly accession, genbank accession, refseq accession, sequence length, taxid). Only available when file assembly_report.txt selected and successfully downloaded'
    echo $' -p Output list of URLs for downloaded and failed files'
    echo $' -a Download the current version of the Taxonomy database (taxdump.tar.gz)'
    echo
    echo $' -o Working output directory \n\tDefault: ./tmp.XXXXXXXXXX'
    echo $' -b Version label\n\tDefault: current timestamp (YYYY-MM-DD_HH-MM-SS)'
    echo $' -e External "assembly_summary.txt" file to recover data from \n\tDefault: ""'
    echo $' -t Threads\n\tDefault: 1'
    echo
    echo $' -m Check MD5 for downloaded files'
    echo $' -s Silent output'
    echo $' -w Silent output with download progress (%) and download version at the end'
    echo $' -n Conditional exit status. Exit Code = 1 if more than N files failed to download (integer for file number, float for percentage, 0 -> off)\n\tDefault: 0'
    echo
}

# Check for required tools
tools=( "awk" "bc" "find" "getopts" "join" "md5sum" "parallel" "sed" "tar" "xargs" "wget" )
for t in "${tools[@]}"
do
    command -v ${t} >/dev/null 2>/dev/null || { echo ${t} not found; exit 1; }
done

OPTIND=1 # Reset getopts
while getopts "d:g:c:l:o:e:b:t:f:n:akixmurpswh" opt; do
  case ${opt} in
    d) database=${OPTARG} ;;
    g) organism_group=${OPTARG// } ;; #remove spaces
    c) refseq_category=${OPTARG} ;;
    l) assembly_level=${OPTARG} ;;
    o) working_dir=${OPTARG} ;;
    e) external_assembly_summary=${OPTARG} ;;
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
[ "${1:-}" = "--" ] && shift


######################### General parameter validation ######################### 
valid_databases=( "genbank" "refseq" )
for d in ${database//,/ }
do
    if [[ ! " ${valid_databases[@]} " =~ " ${d} " ]]; then
        echo "Database ${d} not valid";
    fi
done
if [[ " ${organism_group} " =~ "taxids:" ]]; then
    if [[ -z "${organism_group/taxids:/}" ]]; then
        echo "Invalid taxid - ${organism_group/taxids:/}"; exit 1; # TODO validate taxid?
    fi
elif [[ " ${organism_group} " =~ "species:" ]]; then
    if [[ -z "${organism_group/species:/}" ]]; then
        echo "Invalid species taxids - ${organism_group/species:/}"; exit 1; # TODO validate taxid?
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
# If fixing/recovering, need to have assembly_summary.txt
if [[ ! -z "${external_assembly_summary}" ]] && [[ ! -f "${external_assembly_summary}" ]]; then
    echo "External assembly_summary.txt not found [$(readlink -m ${external_assembly_summary})]"; exit 1;
fi
# mandatory organism group/taxids
if [[ -z "${organism_group}" && -z "${external_assembly_summary}" && "${just_fix}" -eq 0 ]]; then
    echo "Please inform the organism group, species or taxids (comma separated) with the -g parameter"; exit 1;
fi


######################### Variable assignment ######################### 
if [ "${silent}" -eq 1 ] ; then 
    silent_progress=0
elif [ "${silent_progress}" -eq 1 ] ; then 
    silent=1
fi
n_formats=$(echo ${file_formats} | tr -cd , | wc -c) # number of file formats
timestamp=$(date +%Y-%m-%d_%H-%M-%S) # timestamp of the run
export check_md5 silent silent_progress n_formats timestamp # To be accessible in functions called by parallel

# Create working directory
if [[ -z "${working_dir}" ]]; then
    working_dir=$(mktemp -d -p .) # default
else
    mkdir -p "${working_dir}" #user input
fi
working_dir="$(readlink -m ${working_dir})/"
files_dir="files/"
export files_dir working_dir

default_assembly_summary=${working_dir}assembly_summary.txt

# set MODE
if [[ "${just_fix}" -eq 1 ]]; then
    MODE="FIX";
elif [[ ! -f "${default_assembly_summary}" ]] || [[ ! -z "${external_assembly_summary}" ]]; then
    MODE="NEW";
else
    MODE="UPDATE";
fi

# If file already exists and it's a new repo
if [[ ( -f "${default_assembly_summary}" || -L "${default_assembly_summary}" ) && "${MODE}" == "NEW" ]]; then
    echo "Cannot start a new repository with an existing assembly_summary.txt in the working directory [${default_assembly_summary}]"; exit 1;
fi

# If file already exists and it's a new repo
if [[ ! -f "${default_assembly_summary}" && "${MODE}" == "FIX" ]]; then
    echo "Cannot find assembly_summary.txt version to fix [${default_assembly_summary}]"; exit 1;
fi

# mode specific variables
if [[ "${MODE}" == "UPDATE" ]] || [[ "${MODE}" == "FIX" ]]; then # get existing version information
    # Current version info
    current_assembly_summary="$(readlink -m ${default_assembly_summary})"
    current_output_prefix="$(dirname ${current_assembly_summary})/"
    current_label="$(basename ${current_output_prefix})" 
fi

if [[ "${MODE}" == "NEW" ]] || [[ "${MODE}" == "UPDATE" ]]; then # with new info, new variables are necessary
    if [[ -z "${label}" ]]; then 
        new_label=${timestamp}; 
    else 
        new_label=${label};
    fi
    new_output_prefix="${working_dir}${new_label}/"
    new_assembly_summary="${new_output_prefix}assembly_summary.txt"
    # If file already exists and it's a new repo
    if [[ -f "${new_assembly_summary}" ]]; then
        echo "Cannot start a new repository with an existing assembly_summary.txt in the new directory [${new_assembly_summary}]"; exit 1;
    fi
    mkdir -p "${new_output_prefix}${files_dir}"
fi

if [[ "${MODE}" == "NEW" ]]; then
	log_file=${new_output_prefix}${timestamp}.log
elif [[ "${MODE}" == "UPDATE" ]]; then
	log_file=${new_output_prefix}${timestamp}.log
elif [[ "${MODE}" == "FIX" ]]; then
	log_file=${current_output_prefix}${timestamp}.log
fi
export log_file

# count of extra files for report
extra_lines=0

echolog "----------------------------------------" "1"
echolog "      genome_updater version: ${version}" "1"
echolog "----------------------------------------" "1"
echolog "Mode: ${MODE} - $(if [[ "${just_check}" -eq 1 ]]; then echo "CHECK"; else echo "DOWNLOAD"; fi)" "1"
echolog "Timestamp: ${timestamp}" "0"
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
echolog "Silent: ${silent}" "0"
echolog "Silent with progress and version: ${silent_progress}" "0"
echolog "Output URLs: ${url_list}" "0"
echolog "External assembly summary: ${external_assembly_summary}" "0"
echolog "Threads: ${threads}" "0"
echolog "Working directory: ${working_dir}" "1"
echolog "Label: ${label}" "0"
echolog "----------------------------------------" "1"

# new
if [[ "${MODE}" == "NEW" ]]; then

	# SET TARGET
    target_output_prefix=${new_output_prefix}
    export target_output_prefix

    if [[ ! -z "${external_assembly_summary}" ]]; then
        echolog "Using external assembly summary [$(readlink -m ${external_assembly_summary})]" "1"
        cp "${external_assembly_summary}" "${new_assembly_summary}";
        if [[ ! -z "${organism_group}" ]]; then
            echolog " - Organism group [${organism_group}] and database [${database}] values ignored when using an external assembly_summary.txt" "1";
        fi
        all_lines=$(count_lines_file "${new_assembly_summary}")
    else
        echolog "Downloading assembly summary" "1"
        all_lines=$(get_assembly_summary "${new_assembly_summary}" "${database}" "${organism_group}")
    fi

    filtered_lines=$(filter_assembly_summary "${new_assembly_summary}")
    echolog " - $((all_lines-filtered_lines))/${all_lines} entries removed [RefSeq category: ${refseq_category}, Assembly level: ${assembly_level}, Version status: latest]" "1"
    echolog " - ${filtered_lines} entries available" "1"
    
    if [ "${just_check}" -eq 1 ]; then
        rm "${new_assembly_summary}" "${log_file}"
        if [ ! "$(ls -A ${new_output_prefix}${files_dir})" ]; then rm -r "${new_output_prefix}${files_dir}"; fi #Remove folder that was just created (if there's nothing in it)
        if [ ! "$(ls -A ${new_output_prefix})" ]; then rm -r "${new_output_prefix}"; fi #Remove folder that was just created (if there's nothing in it)
        if [ ! "$(ls -A ${working_dir})" ]; then rm -r "${working_dir}"; fi #Remove folder that was just created (if there's nothing in it)
    else
        # Set version - link new assembly as the default
        ln -s -r "${new_assembly_summary}" "${default_assembly_summary}"
        
        if [[ "${filtered_lines}" -gt 0 ]] ; then
            echolog " - Downloading $((filtered_lines*(n_formats+1))) files with ${threads} threads"    "1"
            download_files "${new_assembly_summary}" "1,20" "${file_formats}"

            # UPDATED INDICES assembly accession
            if [ "${updated_assembly_accession}" -eq 1 ]; then 
                output_assembly_accession "${new_assembly_summary}" "1,20" "${file_formats}" "A" > "${new_output_prefix}updated_assembly_accession.txt"
            	echolog " - Assembly accession report written [${new_output_prefix}updated_assembly_accession.txt]" "1"
            fi
            # UPDATED INDICES sequence accession
            if [[ "${file_formats}" =~ "assembly_report.txt" ]] && [ "${updated_sequence_accession}" -eq 1 ]; then
                output_sequence_accession "${new_assembly_summary}" "1,20" "${file_formats}" "A" "${new_assembly_summary}" > "${new_output_prefix}updated_sequence_accession.txt"
				echolog " - Sequence accession report written [${new_output_prefix}updated_sequence_accession.txt]" "1"
            fi
        fi
        echolog "" "1"
    fi
    
else # update/fix

	# SET TARGET for fix
    target_output_prefix=${current_output_prefix}
    export target_output_prefix

    # Check for missing files on current version
    echolog "Checking for missing files in the current version [${current_label}]" "1"
    missing="${working_dir}missing.tmp"
    check_missing_files "${current_assembly_summary}" "1,20" "${file_formats}" > "${missing}" # assembly accession, url, filename
    missing_lines=$(count_lines_file "${missing}")
    if [ "${missing_lines}" -gt 0 ]; then
        echolog " - ${missing_lines} missing files" "1"
        if [ "${just_check}" -eq 0 ]; then
            echolog " - Downloading ${missing_lines} files with ${threads} threads"    "1"
            download_files "${missing}" "2,3"

            # if new files were downloaded, rewrite reports (overwrite information on Removed accessions - all become Added)
            if [ "${updated_assembly_accession}" -eq 1 ]; then 
                output_assembly_accession "${current_assembly_summary}" "1,20" "${file_formats}" "A" > "${current_output_prefix}updated_assembly_accession.txt"
                echolog " - Assembly accession report rewritten [${current_output_prefix}updated_assembly_accession.txt]" "1"
            fi
            if [[ "${file_formats}" =~ "assembly_report.txt" ]] && [ "${updated_sequence_accession}" -eq 1 ]; then
                output_sequence_accession "${current_assembly_summary}" "1,20" "${file_formats}" "A" "${current_assembly_summary}" > "${current_output_prefix}updated_sequence_accession.txt"
                echolog " - Sequence accession report rewritten [${current_output_prefix}updated_sequence_accession.txt]" "1"
            fi
        fi
    else
        echolog " - None" "1"
    fi
    echolog "" "1"
    rm "${missing}"
    
    echolog "Checking for extra files [${current_label}]" "1"
    extra="${working_dir}extra.tmp"
    join <(ls -1 "${current_output_prefix}${files_dir}" | sort) <(list_files "${current_assembly_summary}" "1,20" "${file_formats}" | cut -f 3 | sed -e 's/.*\///' | sort) -v 1 > "${extra}"
    extra_lines=$(count_lines_file "${extra}")
    if [ "${extra_lines}" -gt 0 ]; then
        echolog " - ${extra_lines} extra files" "1"
        if [ "${just_check}" -eq 0 ]; then
            if [ "${delete_extra_files}" -eq 1 ]; then
                echolog " - Deleting ${extra_lines} files" "1";
                remove_files "${extra}" "1";
                extra_lines=0;
            else
                cat "${extra}" >> "${log_file}"; #List file in the log when -x is not enabled
            fi
        fi
    else
        echolog " - None" "1"
    fi
    echolog "" "1"
    rm "${extra}"
    
    if [[ "${MODE}" == "UPDATE" ]]; then

        # change TARGET for update
        target_output_prefix=${new_output_prefix}
        export target_output_prefix

        # Check for updates on NCBI
        echolog "Downloading assembly summary [${new_label}]" "1"
        all_lines=$(get_assembly_summary "${new_assembly_summary}" "${database}" "${organism_group}")
        filtered_lines=$(filter_assembly_summary "${new_assembly_summary}")
        echolog " - $((all_lines-filtered_lines))/${all_lines} entries removed [RefSeq category: ${refseq_category}, Assembly level: ${assembly_level}, Version status: latest]" "1"
        echolog " - ${filtered_lines} entries available" "1"
        echolog "" "1"
        
        if [[ "${just_check}" -eq 0 ]]; then
            # Link versions (current and new)
            echolog "Linking versions [${current_label} --> ${new_label}]" "1"
            find "${current_output_prefix}${files_dir}" -maxdepth 1 -xtype f -print0 | xargs -P "${threads}" -I{} -0 ln -s -r "{}" "${new_output_prefix}${files_dir}"
            echolog " - Done." "1"
        	echolog "" "1"
        fi
        
        update=${working_dir}update.tmp
        delete=${working_dir}delete.tmp
        new=${working_dir}new.tmp
        # UPDATED (verify if version or date changed)
        join <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); gsub("/","",$15); print $1,acc_ver,$15,$20}' ${new_assembly_summary} | sort -k 1,1) <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); gsub("/","",$15); print $1,acc_ver,$15,$20}' ${current_assembly_summary} | sort -k 1,1) -o "1.2,1.3,1.4,2.2,2.3,2.4" | awk '{if($2>$5 || $1!=$4){print $1"\t"$3"\t"$4"\t"$6}}' > ${update}
        update_lines=$(count_lines_file "${update}")
        # DELETED
        join <(cut -f 1 ${new_assembly_summary} | sed 's/\.[0-9]*//g' | sort) <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); print $1,acc_ver,$20}' ${current_assembly_summary} | sort -k 1,1) -v 2 -o "2.2,2.3" | tr ' ' '\t' > ${delete}
        delete_lines=$(count_lines_file "${delete}")
        # NEW
        join <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); print $1,acc_ver,$20}' ${new_assembly_summary} | sort -k 1,1) <(cut -f 1 ${current_assembly_summary} | sed 's/\.[0-9]*//g' | sort) -o "1.2,1.3" -v 1 | tr ' ' '\t' > ${new}
        new_lines=$(count_lines_file "${new}")
        
        echolog "Updating [${current_label} --> ${new_label}]" "1"
        echolog " - ${update_lines} updated, ${delete_lines} deleted, ${new_lines} new entries" "1"

        if [ "${just_check}" -eq 1 ]; then
            rm ${update} ${delete} ${new}
            rm -r "${new_output_prefix}"
        else
            # UPDATED INDICES assembly accession
            if [ "${updated_assembly_accession}" -eq 1 ]; then 
                output_assembly_accession "${update}" "3,4" "${file_formats}" "R" > "${new_output_prefix}updated_assembly_accession.txt"
                output_assembly_accession "${delete}" "1,2" "${file_formats}" "R" >> "${new_output_prefix}updated_assembly_accession.txt"
            fi
            # UPDATED INDICES sequence accession (removed entries - do it before deleting them)
            if [[ "${file_formats}" =~ "assembly_report.txt" ]] && [ "${updated_sequence_accession}" -eq 1 ]; then
                output_sequence_accession "${update}" "3,4" "${file_formats}" "R" "${default_assembly_summary}" > "${new_output_prefix}updated_sequence_accession.txt"
                output_sequence_accession "${delete}" "1,2" "${file_formats}" "R" "${default_assembly_summary}" >> "${new_output_prefix}updated_sequence_accession.txt"
            fi
            
            # Execute updates
            if [ "${update_lines}" -gt 0 ]; then
                echolog " - UPDATE: Deleting $((update_lines*(n_formats+1))) files " "1"
                # delete old version
                remove_files "${update}" "3,4" "${file_formats}"
                echolog " - UPDATE: Downloading $((update_lines*(n_formats+1))) files with ${threads} threads" "1"
                # download new version
                download_files "${update}" "1,2" "${file_formats}"
            fi
            if [ "${delete_lines}" -gt 0 ]; then
                echolog " - DELETE: Deleting $((delete_lines*(n_formats+1))) files" "1"
                remove_files "${delete}" "1,2" "${file_formats}"
            fi
            if [ "${new_lines}" -gt 0 ]; then
                echolog " - NEW: Downloading $((new_lines*(n_formats+1))) files with ${threads} threads"    "1"
                download_files "${new}" "1,2" "${file_formats}"
            fi 

            # UPDATED INDICES assembly accession (added entries - do it after downloading them)
            if [ "${updated_assembly_accession}" -eq 1 ]; then 
                output_assembly_accession "${update}" "1,2" "${file_formats}" "A" >> "${new_output_prefix}updated_assembly_accession.txt"
                output_assembly_accession "${new}" "1,2" "${file_formats}" "A" >> "${new_output_prefix}updated_assembly_accession.txt"
            	echolog " - Assembly accession report written [${new_output_prefix}updated_assembly_accession.txt]" "1"
            fi
            # UPDATED INDICES sequence accession (added entries - do it after downloading them)
            if [[ "${file_formats}" =~ "assembly_report.txt" ]] && [ "${updated_sequence_accession}" -eq 1 ]; then
                output_sequence_accession "${update}" "1,2" "${file_formats}" "A" "${new_assembly_summary}">> "${new_output_prefix}updated_sequence_accession.txt"
                output_sequence_accession "${new}" "1,2" "${file_formats}" "A" "${new_assembly_summary}" >> "${new_output_prefix}updated_sequence_accession.txt"
            	echolog " - Sequence accession report written [${new_output_prefix}updated_sequence_accession.txt]" "1"
            fi
            rm "${update}" "${delete}" "${new}"
			echolog "" "1"

            # set version - update default assembly summary
            echolog "Setting new version [${new_label}]" "1"
            rm "${default_assembly_summary}"
            ln -s -r "${new_assembly_summary}" "${default_assembly_summary}"
            echolog " - Done." "1"
            echolog "" "1"
        fi
    fi
fi

if [ "${just_check}" -eq 0 ]; then
	if [ "${download_taxonomy}" -eq 1 ]; then
        echolog "Downloading current Taxonomy database [${target_output_prefix}taxdump.tar.gz] " "1"
        get_taxdump "${target_output_prefix}taxdump.tar.gz"
        echolog " - Done" "1"
        echolog "" "1"
    fi
    expected_files=$(( $(count_lines_file "${default_assembly_summary}")*(n_formats+1) )) # From assembly summary * file formats
    current_files=$(( $(ls "${target_output_prefix}${files_dir}" | wc -l | cut -f1 -d' ') - extra_lines )) # From current folder - extra files
    # Check if the valid amount of files on folder amount of files on folder
    echolog "# ${current_files}/${expected_files} files successfully obtained" "1"
    if [ $(( expected_files-current_files )) -gt 0 ]; then
        echolog " - $(( expected_files-current_files )) file(s) failed to download. Please re-run your command with -i to fix it again" "1"
    fi
    if [ "${extra_lines}" -gt 0 ]; then
        echolog " - ${extra_lines} extra file(s) in the output files folder. To delete them, re-run your command with -i -x" "1"
    fi
    echolog "# Log file: ${log_file}" "1"
    echolog "# Finished! Current version: $(dirname $(readlink -m ${default_assembly_summary}))" "1"
    if [ "${silent_progress}" -eq 1 ] ; then
        echo "$(dirname $(readlink -m ${default_assembly_summary}))"
    fi
    # Exit conditional status
    exit $(exit_status ${expected_files} ${current_files})
fi
