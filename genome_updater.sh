#!/usr/bin/env bash
set -euo pipefail
IFS=$' '

# The MIT License (MIT)
 
# Copyright (c) 2023 - Vitor C. Piro - pirovc.github.io
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

version="0.6.3"

# Define ncbi_base_url or use local files (for testing)
local_dir=${local_dir:-}
if [[ ! -z "${local_dir}" ]]; then
    # set local dir with absulute path and "file://"
    local_dir="file://$(cd "${local_dir}" && pwd)"
fi
ncbi_base_url=${ncbi_base_url:-ftp://ftp.ncbi.nlm.nih.gov/} #Alternative ftp://ftp.ncbi.nih.gov/
gtdb_base_url="https://data.gtdb.ecogenomic.org/releases/latest/"
retries=${retries:-3}
timeout=${timeout:-120}
export retries timeout ncbi_base_url gtdb_base_url local_dir

# Export locale numeric to avoid errors on printf in different setups
export LC_NUMERIC="en_US.UTF-8"

#activate aliases in the script
shopt -s expand_aliases
alias sort="sort --field-separator=$'\t'"
join_as_fields1="1.1,1.2,1.3,1.4,1.5,1.6,1.7,1.8,1.9,1.10,1.11,1.12,1.13,1.14,1.15,1.16,1.17,1.18,1.19,1.20,1.21,1.22,1.23,1.24,1.25,1.26,1.27,1.28,1.29,1.30,1.31,1.32,1.33,1.34,1.35,1.36,1.37,1.38"
join_as_fields2="1.1,2.2,2.3,2.4,2.5,2.6,2.7,2.8,2.9,2.10,2.11,2.12,2.13,2.14,2.15,2.16,2.17,2.18,2.19,2.20,2.21,2.22,2.23,2.24,2.25,2.26,2.27,2.28,2.29,2.30,2.31,2.32,2.33,2.34,2.35,2.36,2.37,2.38"

download_url() # parameter: ${1} url, ${2} output file/directory (omit/empty to STDOUT)
{
    url="${1}"
    outfiledir="${2:-}"
    if [[ ! -z "${outfiledir}" ]]; then
        if [[ -d "${outfiledir}" ]]; then
            outfile="${outfiledir}/${1##*/}" # based on given output dir and file to download
        else
            outfile="${outfiledir}"
        fi
    else
        outfile="-" # STDOUT
    fi

    # Replace base url with local directory if provided
    if [[ ! -z "${local_dir}" ]]; then 
        url="${local_dir}/${url#*://*/}";
    fi
    downloader "${outfile}" "${url}"
}
export -f download_url  #export it to be accessible to the parallel call

download_retry_md5(){ # parameter: ${1} url, ${2} output file, ${3} url MD5 (empty to skip), ${4} re-tries
    for (( att=1; att<=${4:-1}; att++ )); do
        if [ "${att}" -gt 1 ]; then
            echolog " - Failed to download ${url}. Trying again #${att}" "1"
        fi
        download_url "${1}" "${2}"
        # No md5 file to check
        if [[ -z "${3}" ]]; then
            return 0;
        else
            real_md5=$(download_url "${3}" | grep "${1##*/}" | cut -f1 -d' ')
            if [ -z "${real_md5}" ]; then
                continue; # did not find url file on md5 file (or empty), try again
            else
                file_md5=$(md5sum ${2} | cut -f1 -d' ')
                if [ "${file_md5}" != "${real_md5}" ]; then
                    continue; # md5 didn't match, try again
                else
                    return 0; # md5 matched, return success
                fi    
            fi
        fi
    done
    return 1; # failed to check md5 after all attempts
}

path_output() # parameter: ${1} file/url
{
    f=$(basename ${1});
    path="${files_dir}";
    if [[ "${ncbi_folders}" -eq 1 ]]; then
        path="${path}${f:0:3}/${f:4:3}/${f:7:3}/${f:10:3}/";
    fi
    echo "${path}";
}
export -f path_output

link_version() # parameter: ${1} current_output_prefix, ${2} new_output_prefix, ${3} file
{
    path_out=$(path_output ${3})
    if [[ -f "${1}${path_out}${3}" ]]; then
        mkdir -p "${2}${path_out}";
        ln -s -r "${1}${path_out}${3}" "${2}${path_out}";
    fi
}
export -f link_version  #export it to be accessible to the parallel call

list_local_files() # parameter: ${1} prefix, ${2} 1 to list list all, "" list only '-not -empty'
{
    # Returns list of local files, without folder structure
    if [[ "${ncbi_folders}" -eq 0 ]]; then
        depth="-maxdepth 1";
    else
        depth="-mindepth 4";
    fi
    param="-not -empty"
    if [[ ! -z "${2:-}" ]]; then
        param=""
    fi
    find "${1}${files_dir}" ${depth} ${param} \( -type f -o -type l \) -printf "%f\n"
}

unpack() # parameter: ${1} file, ${2} output folder[, ${3} files to unpack]
{
    tar xf "${1}" -C "${2}" "${3}"
}

count_lines() # parameter: ${1} file - return number of lines
{
    echo ${1:-} | sed '/^\s*$/d' | wc -l | cut -f1 -d' '
}

count_lines_file() # parameter: ${1} file - return number of lines
{
    sed '/^\s*$/d' ${1:-} | wc -l | cut -f1 -d' '
}

check_assembly_summary() # parameter: ${1} assembly_summary file - return 0 true 1 false
{
    # file exists and it's not empty
    if [ ! -s "${1}" ]; then return 1; fi

    # Last char is empty (line break)
    if [ ! -z $(tail -c -1 "${1}") ]; then return 1; fi

    # if contains header char parts of the header anywhere besides starting lines
    grep -m 1 "^#" "${1}" > /dev/null 2>&1
    if [ $? -eq 0 ]; then return 1; fi

    # if contains parts of the header anywhere
    ##   See ftp://ftp.ncbi.nlm.nih.gov/genomes/README_assembly_summary.txt for a description of the columns in this file.
    grep -m 1 "ftp://ftp.ncbi.nlm.nih.gov/genomes/README_assembly_summary.txt" "${1}" > /dev/null 2>&1
    if [ $? -eq 0 ]; then return 1; fi
    # assembly_accession    bioproject  biosample   wgs_master  refseq_category taxid   species_taxid   organism_name   infraspecific_name  isolate version_status  assembly_levelrelease_type  genome_rep  seq_rel_date    asm_name    submitter   gbrs_paired_asm paired_asm_comp ftp_path    excluded_from_refseq    relation_to_type_material   asm_not_live_date
    grep -m 1 " assembly_accession" "${1}" > /dev/null 2>&1
    if [ $? -eq 0 ]; then return 1; fi

    # if every line has same number of cols (besides headers)
    ncols=$(grep -v "^#" "${1}" | awk 'BEGIN{FS=OFS="\t"}{print NF}' | uniq | wc -l)
    if [[ ${ncols} -gt 1 ]]; then return 1; fi

    # if every line starts with GCF_ or GCA_
    grep -v "^GC[FA]_" "${1}" > /dev/null 2>&1
    if [ $? -eq 0 ]; then return 1; fi

    return 0;
}

get_assembly_summary() # parameter: ${1} assembly_summary file, ${2} database, ${3} organism_group - return number of lines
{
    # Collect urls to download
    as_to_download=()
    for d in ${2//,/ }
    do
        # If no organism group is chosen, get complete assembly_summary for the database
        if [[ -z "${3}" ]]; then
            as_to_download+=("${ncbi_base_url}genomes/${d}/assembly_summary_${d}.txt")
            if [[ "${tax_mode}" == "gtdb" ]]; then
                as_to_download+=("${ncbi_base_url}genomes/${d}/assembly_summary_${d}_historical.txt")
            fi
        else
            for og in ${3//,/ }
            do
                #special case: human
                if [[ "${og}" == "human" ]]; then og="vertebrate_mammalian/Homo_sapiens"; fi
                as_to_download+=("${ncbi_base_url}genomes/${d}/${og}/assembly_summary.txt")
                if [[ "${tax_mode}" == "gtdb" ]]; then
                    as_to_download+=("${ncbi_base_url}genomes/${d}/${og}/assembly_summary_historical.txt")
                fi
            done
        fi
    done

    # Download files with retry attempts, checking consistency of assembly_summary after every download
    for as in "${as_to_download[@]}"
    do
        for (( att=1; att<=${retry_download_batch}; att++ )); do
            if [ "${att}" -gt 1 ]; then
                echolog " - Failed to download ${as}. Trying again #${att}" "1"
            fi
            download_url "${as}" 2> /dev/null | tail -n+3 > "${1}.tmp"
            if check_assembly_summary "${1}.tmp"; then
                cat "${1}.tmp" >> "${1}"
                break; 
            elif [ ${att} -eq ${retry_download_batch} ]; then
                return 1; # failed to download after all attempts
            fi
        done
    done
    rm -f "${1}.tmp"

    # Final check full file
    if check_assembly_summary "${1}"; then
        return 0;
    else
        return 1;
    fi
}

write_history(){ # parameter: ${1} current label, ${2} new label, ${3} new timestamp, ${4} assembly_summary file
    # if current label is the same as new label (new)
    # reading the history
    # Only new_label = NEW
    # both current and new_label = UPDATE
    # only current_label = FIX
    if [[ "${1}" == "${2}" ]]; then 
        echo -e "#current_label\tnew_label\ttimestamp\tassembly_summary_entries\targuments" > ${history_file}
        echo -n -e "\t" >> ${history_file}
    else
        echo -n -e "${1}\t" >> ${history_file}
    fi
    echo -n -e "${2}\t" >> ${history_file}
    echo -n -e "${3}\t" >> ${history_file}
    echo -n -e "$(count_lines_file ${4})\t" >> ${history_file}
    echo -e "${genome_updater_args}" >> ${history_file}
}

filter_assembly_summary() # parameter: ${1} assembly_summary file, ${2} number of lines - return 1 if no lines or failed, 0 success
{
    assembly_summary="${1}"
    filtered_lines=${2}
    if [[ "${filtered_lines}" -eq 0 ]]; then return 1; fi
    
    gtdb_tax=""
    ncbi_tax=""
    ncbi_rank_tax=""
    tmp_new_taxdump=""
    if [[ "${tax_mode}" == "gtdb" ]]; then
        echolog " - Downloading taxonomy (gtdb)" "1"
        # Download and parse GTDB tax
        gtdb_tax=$(tmp_file "gtdb_tax.tmp")
        for url in "${gtdb_urls[@]}"; do
            tmp_tax=$(tmp_file "gtdb_tax.tmp.gz")
            #if ! download_retry_md5 "${url}" "${tmp_tax}" "${gtdb_base_url}MD5SUM.txt" "${retry_download_batch}"; then
            if ! download_retry_md5 "${url}" "${tmp_tax}" "" "${retry_download_batch}"; then
                return 1;
            else
                # awk to remove prefix RS_ or GB_
                zcat "${tmp_tax}" | awk -F "\t" '{print substr($1, 4, length($1))"\t"$2}' >> "${gtdb_tax}"
            fi
            rm -f "${tmp_tax}"
        done
    elif [[ "${tax_mode}" == "ncbi" && ( ! -z "${taxids}" || ( ! -z "${top_assemblies_rank}" && "${top_assemblies_rank}" != "species" ) ) ]]; then
        echolog " - Downloading taxonomy (ncbi)" "1"
        tmp_new_taxdump="${working_dir}new_taxdump.tar.gz"
        if ! download_retry_md5 "${ncbi_base_url}pub/taxonomy/new_taxdump/new_taxdump.tar.gz" "${tmp_new_taxdump}" "${ncbi_base_url}pub/taxonomy/new_taxdump/new_taxdump.tar.gz.md5" "${retry_download_batch}"; then
            return 1;
        fi
    fi

    if [[ "${tax_mode}" == "gtdb" ]]; then
        tmp_gtdb_missing=$(tmp_file "gtdb_missing")
        gtdb_lines=$(filter_gtdb "${assembly_summary}" "${gtdb_tax}" "${tmp_gtdb_missing}")
        echolog " - $((filtered_lines-gtdb_lines)) assemblies removed not in GTDB" "1"
        
        # If missing file has entries, report on log
        gtdb_missing_lines=$(count_lines_file "${tmp_gtdb_missing}")
        if [[ "${gtdb_missing_lines}" -gt 0 ]]; then
            echolog " - Could not retrieve "${gtdb_missing_lines}" GTDB assemblies" "1"
            cat "${tmp_gtdb_missing}" >> "${log_file}"    
        fi
        rm "${tmp_gtdb_missing}"

        filtered_lines=${gtdb_lines}
        if [[ "${filtered_lines}" -eq 0 ]]; then return 0; fi
    fi

    # DATE
    if [[ ! -z "${date_start}" || ! -z "${date_end}" ]]; then
        date_lines=$(filter_date "${assembly_summary}")
        echolog " - $((filtered_lines-date_lines)) assemblies removed not in the date range [ ${date_start} .. ${date_end} ]" "1"
        filtered_lines=${date_lines}
        if [[ "${filtered_lines}" -eq 0 ]]; then return 0; fi
    fi

    # TAXIDS
    if [[ ! -z "${taxids}" ]]; then
        if [[ "${tax_mode}" == "ncbi" ]]; then
            unpack "${tmp_new_taxdump}" "${working_dir}" "taxidlineage.dmp"
            ncbi_tax="${working_dir}taxidlineage.dmp"
            taxids_lines=$(filter_taxids_ncbi "${assembly_summary}" "${ncbi_tax}")
        else
            taxids_lines=$(filter_taxids_gtdb "${assembly_summary}" "${gtdb_tax}")
        fi
        echolog " - $((filtered_lines-taxids_lines)) assemblies removed not in taxids [${taxids}]" "1"
        filtered_lines=${taxids_lines}
        if [[ "${filtered_lines}" -eq 0 ]]; then return 0; fi
    fi

    # Filter columns
    columns_lines=$(filter_columns "${assembly_summary}")
    if [ "$((filtered_lines-columns_lines))" -gt 0 ]; then
        echolog " - $((filtered_lines-columns_lines)) assemblies removed based on filters:" "1"
        echolog "   valid URLs" "1"
        if [[ "${tax_mode}" == "ncbi" ]]; then echolog "   version status=latest" "1"; fi
        if [ ! -z "${refseq_category}" ]; then echolog "   refseq category=${refseq_category}" "1"; fi
        if [ ! -z "${assembly_level}" ]; then echolog "   assembly level=${assembly_level}" "1"; fi
        if [ ! -z "${custom_filter}" ]; then echolog "   custom filter=${custom_filter}" "1"; fi
        filtered_lines=${columns_lines}
        if [[ "${filtered_lines}" -eq 0 ]]; then return 0; fi
    fi

    #TOP ASSEMBLIES
    if [ "${top_assemblies_num}" -gt 0 ]; then
        # Add chosen rank as first col of a temporary assembly_summary
        if [[ "${tax_mode}" == "ncbi" ]]; then
            if [[ ! -z "${top_assemblies_rank}" && "${top_assemblies_rank}" != "species" ]]; then
                unpack "${tmp_new_taxdump}" "${working_dir}" "rankedlineage.dmp"    
                ncbi_rank_tax="${working_dir}rankedlineage.dmp"
            fi
            ranked_lines=$(add_rank_ncbi "${assembly_summary}" "${assembly_summary}_rank" "${ncbi_rank_tax}")
        else
            ranked_lines=$(add_rank_gtdb "${assembly_summary}" "${assembly_summary}_rank" "${gtdb_tax}")
        fi
        if [ $((filtered_lines-ranked_lines)) -gt 0 ]; then
            echolog " - Failed to match all entries to taxonomic identifiers with ${top_assemblies}" "1"
        fi
        top_lines=$(filter_top_assemblies "${assembly_summary}" "${assembly_summary}_rank")
        echolog " - $((filtered_lines-top_lines)) entries removed with top ${top_assemblies}" "1"
        rm -f "${assembly_summary}_rank"
        filtered_lines=${top_lines}
        if [[ "${filtered_lines}" -eq 0 ]]; then return 0; fi
    fi

    rm -f "${ncbi_tax}" "${ncbi_rank_tax}" "${gtdb_tax}" "${tmp_new_taxdump}"
    return 0;
}

filter_taxids_ncbi() # parameter: ${1} assembly_summary file, ${2} ncbi_tax file - return number of lines
{
    # Keep only selected taxid lineage, removing at the end duplicated entries from duplicates on taxids
    tmp_lineage=$(tmp_file "lineage.tmp")
    for tx in ${taxids//,/ }; do
        txids_lin=$(grep "[^0-9]${tx}[^0-9]" "${2}" | cut -f 1) #get only taxids in the lineage section
        echolog " - $(count_lines "${txids_lin}") children taxids in the lineage of ${tx}" "0"
        echo "${txids_lin}" >> "${tmp_lineage}" 
    done
    lineage_taxids=$(sort ${tmp_lineage} | uniq | tr '\n' ',')${taxids} # put lineage back into the taxids variable with the provided taxids
    rm "${tmp_lineage}"

    # Join with assembly_summary based on taxid field 6
    join -1 6 -2 1 <(sort -k 6,6 "${1}") <(echo "${lineage_taxids//,/$'\n'}" | sort -k 1,1) -t$'\t' -o ${join_as_fields1} | sort | uniq > "${1}_taxids"
    mv "${1}_taxids" "${1}"
    count_lines_file "${1}"
}

filter_taxids_gtdb() # parameter: ${1} assembly_summary file, ${2} gtdb_tax file return number of lines
{
    tmp_gtdb_acc=$(tmp_file "gtdb_acc.tmp")
    IFS=","
    for tx in ${taxids}; do
        sed -e 's/\t/\t;/g' -e 's/$/;/p' ${2} | grep ";${tx};" | cut -f 1 >> "${tmp_gtdb_acc}"
    done
    IFS=$' '
    join -1 1 -2 1 <(sort -k 1,1 "${1}") <(sort -k 1,1 "${tmp_gtdb_acc}" | uniq) -t$'\t' -o ${join_as_fields1} | sort | uniq > "${1}_taxids"
    mv "${1}_taxids" "${1}"
    rm "${tmp_gtdb_acc}"
    count_lines_file "${1}"
}

filter_date() # parameter: ${1} assembly_summary file - return number of lines
{
    awk -v dstart="${date_start}" -v dend="${date_end}" 'BEGIN{FS=OFS="\t"}{date=$15; gsub("/","",date); if((date>=dstart || dstart=="") && (date<=dend || dend=="")) print $0}' "${1}" > "${1}_date"
    mv "${1}_date" "${1}"
    count_lines_file "${1}"
}

filter_columns() # parameter: ${1} assembly_summary file - return number of lines
{
    # Build string to filter file by columns in the format
    # colA:val1,val2|colB:val3
    # AND between cols, OR between values
    
    # Valid URLs (not na)
    awk -F "\t" '{if($20!="na"){print $0}}' "${1}" > "${1}_valid"

    colfilter=""
    if [[ "${tax_mode}" == "ncbi" ]]; then
        colfilter="11:latest|"
    fi
    if [[ ! -z "${refseq_category}" ]]; then
        colfilter="${colfilter}5:${refseq_category}|"
    fi
    if [[ ! -z "${assembly_level}" ]]; then
        colfilter="${colfilter}12:${assembly_level}|"
    fi
    if [[ ! -z "${custom_filter}" ]]; then
        colfilter="${colfilter}${custom_filter}|"
    fi

    if [[ ! -z "${colfilter}" ]]; then
        awk -F "\t" -v colfilter="${colfilter%?}" '
            function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
            function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s }
            function trim(s) { return rtrim(ltrim(s)); }
            BEGIN{
            split(colfilter, fields, "|");
            for(f in fields){
                split(fields[f], keyvals, ":");
                filter[keyvals[1]]=keyvals[2];}
            }{
                k=0;
                for(f in filter){
                    split(filter[f], v, ","); for (i in v) vals[tolower(trim(v[i]))]="";
                    if(tolower($f) in vals){
                        k+=1;
                    }
                };
                if(k==length(filter)){
                    print $0;
                }
            }' "${1}_valid" > "${1}"
        rm -f "${1}_valid"
    else
        mv "${1}_valid" "${1}"
    fi
    count_lines_file "${1}"
}

filter_gtdb() # parameter: ${1} assembly_summary file, ${2} gtdb_tax file,  ${3} gtdb_missing file - return number of lines
{
    # Check for missing entries
    join -1 1 -2 1 <(sort -k 1,1 "${1}") <(sort -k 1,1 "${2}") -v 2 > ${3}
    # Match entries
    join -1 1 -2 1 <(sort -k 1,1 "${1}") <(sort -k 1,1 "${2}") -t$'\t' -o ${join_as_fields1} | sort | uniq > "${1}_gtdb"
    mv "${1}_gtdb" "${1}"
    count_lines_file "${1}"
}

add_rank_ncbi(){ # parameter: ${1} assembly_summary file, ${2} modified assembly_summary file with rank as first col, ${3} ncbi_tax file - return number of lines
    # rankedlineage.dmp cols (sep tab|tab):
    # $1=taxid, $3=name, $5=species, $7=genus, $9=family, $11=order, $13=class, $15=phylum, $17=kingdom, $19=superkingdom
    if [[ -z "${top_assemblies_rank}" ]]; then
        # Repeat leaf taxid
        awk 'BEGIN{FS=OFS="\t"}{print $6,$0}' "${1}" > "${2}"
    elif [[ "${top_assemblies_rank}" == "species" ]]; then
        # Repeat species taxid
        awk 'BEGIN{FS=OFS="\t"}{print $7,$0}' "${1}" > "${2}"
    else
        # export taxid <tab> ranked name
        tmp_ranked_taxids=$(tmp_file "ranked_taxids.tmp")
        awk -v rank="${top_assemblies_rank}" 'BEGIN{
                FS=OFS="\t";
                r["genus"]=7;
                r["family"]=9;
                r["order"]=11;
                r["class"]=13;
                r["phylum"]=15;
                r["superkingdom"]=19;
            }{
                print $1, $r[rank] ? $r[rank] : $1;
            }' "${3}" > "${tmp_ranked_taxids}"
        # Join ranked name by taxid col
        join -1 6 -2 1 <(sort -k 6,6 "${1}") <(sort -k 1,1 "${tmp_ranked_taxids}") -t$'\t' -o "2.2,${join_as_fields1}" > "${2}"
        rm -f "${tmp_ranked_taxids}"
    fi
    count_lines_file "${2}"
}

add_rank_gtdb(){ # parameter: ${1} assembly_summary file, ${2} modified assembly_summary file with rank as first col, ${3} gtdb_tax file - return number of lines
    # gtdb taxonomy (RS_ and GB_ already stripped)
    # accession.version <tab> d__Bacteria;p__Firmicutes;c__Bacilli;o__Staphylococcales;f__Staphylococcaceae;g__Staphylococcus;s__Staphylococcus aureus
    # export accession <tab> ranked name
    #if top_assemblies_rank empty, default to species (leaves on gtdb)
    tmp_ranked_accessions=$(tmp_file "ranked_accessions.tmp")
    cat "${3}" | tr ';' '\t' | awk -v rank="${top_assemblies_rank:-species}" 'BEGIN{
            FS=OFS="\t";
            r["species"]=8;
            r["genus"]=7;
            r["family"]=6;
            r["order"]=5;
            r["class"]=4;
            r["phylum"]=3;
            r["superkingdom"]=2;
        }{
            print $1, $r[rank] ? $r[rank] : $1;
        }' > "${tmp_ranked_accessions}"

    # Join ranked taxid by accession
    join -1 1 -2 1 <(sort -k 1,1 "${1}") <(sort -k 1,1 "${tmp_ranked_accessions}") -t$'\t' -o "2.2,${join_as_fields1}" > "${2}"
    rm -f "${tmp_ranked_accessions}"
    count_lines_file "${2}"
}

filter_top_assemblies() # parameter: ${1} assembly_summary file, ${2} modified assembly_summary file with rank as first col - return number of lines
{
    # First col contains rank info (all other get shifted with +1)
    awk -v taxcol="1" 'BEGIN{
            FS=OFS="\t";
            col5["reference genome"]=1;
            col5["representative genome"]=2;
            col5["na"]=3;
            col12["Complete Genome"]=1;
            col12["Chromosome"]=2;
            col12["Scaffold"]=3;
            col12["Contig"]=4;
            col22["assembly from type material"]=1;
            col22["assembly from synonym type material"]=2;
            col22["assembly from pathotype material"]=3;
            col22["assembly designated as neotype"]=4;
            col22["assembly designated as reftype"]=5;
            col22["ICTV species exemplar"]=6;
            col22["ICTV additional isolate"]=7;
            max_val=9;
        }{
            gsub("/","",$(15+1)); 
            print $(1+1), $taxcol, $(5+1) in col5 ? col5[$(5+1)] : max_val, $(12+1) in col12 ? col12[$(12+1)] : max_val, $(22+1) in col22 ? col22[$(22+1)] : max_val, $(15+1);
        }' "${2}" | sort -t$'\t' -k 2,2 -k 3,3 -k 4,4 -k 5,5 -k 6nr,6 -k 1,1 | awk -v top="${top_assemblies_num}" 'BEGIN{FS=OFS="\t"}{if(cnt[$2]<top){print $1;cnt[$2]+=1}}' > "${2}_top_acc"
    join <(sort -k 1,1 "${2}_top_acc") <(sort -k 1,1 "${1}") -t$'\t' -o ${join_as_fields2} > "${1}_top"
    mv "${1}_top" "${1}"
    rm "${2}_top_acc"
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

tmp_file(){ # parameter: ${1} filename - return full path of created file
    f="${working_dir}${1}"
    rm -f "${f}"
    touch "${f}"
    echo "${f}"
}

print_progress() # parameter: ${1} file number, ${2} total number of files
{
    if [ "${silent_progress}" -eq 1 ] || [ "${silent}" -eq 0 ] ; then
        printf "%5d/%d - " ${1} ${2}
        printf "%2.2f%%\r" $(bc -l <<< "scale=4;(${1}/${2})*100")
    fi
}
export -f print_progress #export it to be accessible to the parallel call

check_file_folder() # parameter: ${1} url, ${2} log (0->before download/1->after download) - returns 0 (ok) / 1 (error)
{
    file_name=$(basename ${1})
    path_name="${target_output_prefix}$(path_output ${file_name})${file_name}"
    # Check if file exists and if it has a size greater than zero (-s)
    if [ ! -s "${path_name}" ]; then
        if [ "${2}" -eq 1 ]; then echolog "${file_name} download failed [${1}]" "0"; fi
        # Remove file if exists (only zero-sized files)
        rm -vf "${path_name}" >> "${log_file}" 2>&1
        return 1
    else
        if [ "${verbose_log}" -eq 1 ]; then
            if [ "${2}" -eq 0 ]; then 
                echolog "${file_name} file found on the output folder [${path_name}]" "0"
            else
                echolog "${file_name} downloaded successfully [${1} -> ${path_name}]" "0"
            fi
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
        md5checksums_file=$(download_url "${md5checksums_url}")
        if [ -z "${md5checksums_file}" ]; then
            echolog "${file_name} MD5checksum file download failed [${md5checksums_url}] - FILE KEPT"  "0"
            return 0
        else
            ftp_md5=$(echo "${md5checksums_file}" | grep "${file_name}" | cut -f1 -d' ')
            if [ -z "${ftp_md5}" ]; then
                echolog "${file_name} MD5checksum file not available [${md5checksums_url}] - FILE KEPT"  "0"
                return 0
            else
                path_name="${target_output_prefix}$(path_output ${file_name})${file_name}" # local file path and name
                file_md5=$(md5sum ${path_name} | cut -f1 -d' ')
                if [ "${file_md5}" != "${ftp_md5}" ]; then
                    echolog "${file_name} MD5 not matching [${md5checksums_url}] - FILE REMOVED"  "0"
                    # Remove file only when MD5 doesn't match
                    rm -v "${path_name}" >> ${log_file} 2>&1
                    return 1
                else
                    if [ "${verbose_log}" -eq 1 ]; then
                        echolog "${file_name} MD5 successfully checked ${file_md5} [${md5checksums_url}]" "0"
                    fi
                    return 0
                fi    
            fi
        fi
    else
        return 0
    fi
    
}
export -f check_md5_ftp #export it to be accessible to the parallel call

download() # parameter: ${1} url, ${2} job number, ${3} total files, ${4} url_success_download (append)
{
    ex=0
    dl=0
    if ! check_file_folder ${1} "0"; then # Check if the file is already on the output folder (avoid redundant download)
        dl=1
    elif ! check_md5_ftp ${1}; then # Check if the file already on folder has matching md5
        dl=1
    fi
    if [ "${dl}" -eq 1 ]; then # If file is not yet on folder, download it
        path_out="${target_output_prefix}$(path_output ${1})"
        mkdir -p "${path_out}"
        download_url "${1}" "${path_out}"
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
    url_list_download=$(tmp_file "url_list_download.tmp") #Temporary url list of files to download in this call
    # sort files to get all files for the same entry in sequence, in case of failure 
    if [ -z ${3:-} ]; then #direct download (url+file)
        cut --fields="${2}" ${1} | tr '\t' '/' | sort > "${url_list_download}"
    else
        list_files ${1} ${2} ${3} | cut -f 2,3 | tr '\t' '/' | sort > "${url_list_download}"
    fi
    total_files=$(count_lines_file "${url_list_download}")

    url_success_download=$(tmp_file "url_success_download.tmp") #Temporary url list of downloaded files
    # Retry download in batches
    for (( att=1; att<=${retry_download_batch}; att++ )); do
        if [ "${att}" -gt 1 ]; then
            echolog " - Failed download - ${failed_count} files. Trying again #${att}" "1"
            # Make a new list to download without entres already successfuly downloaded
            join <(sort "${url_list_download}") <(sort "${url_success_download}") -v 1 > "${url_list_download}_2"
            mv "${url_list_download}_2" "${url_list_download}"
            total_to_download=$(count_lines_file "${url_list_download}")
        else
            total_to_download=${total_files}
        fi
        
        # send url, job number and total files (to print progress)
        # successfuly files are appended to the $url_success_download
        parallel --gnu --tmpdir ${working_dir} -a ${url_list_download} -j ${threads} download "{}" "{#}" "${total_to_download}" "${url_success_download}"

        downloaded_count=$(count_lines_file "${url_success_download}")
        failed_count=$(( total_files - downloaded_count ))

        echolog " - $(( total_files-failed_count ))/${total_files} files successfully downloaded" "1"
        # If no failures, break
        if [ "${failed_count}" -eq 0 ]; then
            break;
        fi
    done

    # Output URL reports
    if [ "${url_list}" -eq 1 ]; then 
        # add left overs of the list to the failed urls
        join <(sort "${url_list_download}") <(sort "${url_success_download}") -v 1 >> "${target_output_prefix}${timestamp}_url_failed.txt"
        # add successful downloads the the downloaded urls
        cat "${url_success_download}" >> "${target_output_prefix}${timestamp}_url_downloaded.txt"
    fi
    rm -f ${url_list_download} ${url_success_download}
}

remove_files() # parameter: ${1} file, ${2} fields [assembly_accesion,url] OR field [filename], ${3} extension - returns number of deleted files
{
    if [ -z ${3:-} ]; then
        # direct remove (filename)
        filelist=$(cut --fields="${2}" ${1});
    else
        # generate files
        filelist=$(list_files ${1} ${2} ${3} | cut -f 3);
    fi
    deleted_files=0
    while read f; do
        path_name="${target_output_prefix}$(path_output ${f})${f}"
        # Only delete if delete option is enable or if it's a symbolic link (from updates)
        if [[ -L "${path_name}" || "${delete_extra_files}" -eq 1 ]]; then
            rm "${path_name}" -v >> ${log_file}
            deleted_files=$((deleted_files + 1))
        else
            echolog "kept '${path_name}'" "0"
        fi
    done <<< "${filelist}"
    echo ${deleted_files}
}

check_missing_files() # ${1} file, ${2} fields [assembly_accesion,url], ${3} extension - returns assembly accession, url and filename
{
    join -1 3 -2 1 <(list_files ${1} ${2} ${3} | sort -k 3,3 -t$'\t') <(list_local_files "${target_output_prefix}" | sort) -t$'\t' -v 1 -o "1.1,1.2,1.3"
}

check_complete_record() # parameters: ${1} file, ${2} field [assembly accession, url], ${3} extension - returns assembly accession, url
{
    expected_files=$(list_files ${1} ${2} ${3} | sort -k 3,3)
    join -1 3 -2 1 <(echo "${expected_files}" | sort -k 3,3) <(list_local_files "${target_output_prefix}" | sort) -t$'\t' -o "1.1" -v 1 | sort | uniq | # Check for accessions with at least one missing file
    join -1 1 -2 1 <(echo "${expected_files}" | cut -f 1,2 | sort | uniq) - -t$'\t' -v 1 # Extract just assembly accession and url for complete entries (no missing files)
}

output_assembly_accession() # parameters: ${1} file, ${2} field [assembly accession, url], ${3} extension, ${4} mode (A/R) - returns assembly accession, url and mode
{
    check_complete_record ${1} ${2} ${3} | sed "s/^/${4}\t/" # add mode
}

output_sequence_accession() # parameters: ${1} file, ${2} field [assembly accession, url], ${3} extension, ${4} mode (A/R), ${5} assembly_summary (for taxid)
{
    join <(list_files ${1} ${2} "assembly_report.txt" | sort -k 1,1) <(check_complete_record ${1} ${2} ${3} | sort -k 1,1) -t$'\t' -o "1.1,1.3" | # List assembly accession and filename for all assembly_report.txt with complete record (no missing files) - returns assembly accesion, filename
    join - <(sort -k 1,1 ${5}) -t$'\t' -o "1.1,1.2,2.6" |     # Get taxid {1} assembly accession, {2} filename {3} taxid
    parallel --tmpdir ${working_dir} --colsep "\t" -j ${threads} -k 'grep "^[^#]" "${target_output_prefix}$(path_output {2}){2}" | tr -d "\r" | cut -f 5,7,9 | sed "s/^/{1}\\t/" | sed "s/$/\\t{3}/"' | # Retrieve info from assembly_report.txt and add assemby accession in the beggining and taxid at the end
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
    if [[ "${2:-0}" -eq "1" ]] && [ "${silent}" -eq 0 ]; then
        echo "${1}" # STDOUT
    fi
    echo "${1}" >> "${log_file}" # LOG
}
export -f echolog #export it to be accessible to the parallel call

print_debug() # parameters: ${1} tools
{
    echo "========================================================";
    echo "genome_updater version ${version}"
    echo "========================================================";
    bash --version
    echo "========================================================";
    locale
    for t in "${tools[@]}"
    do
        echo "========================================================";
        tool=$(command -v "${t}");
        echo "${t} => ${tool}";
        echo "========================================================";
        ${tool} --version;
    done
    echo "========================================================";
}

function print_logo {
    echo "┌─┐┌─┐┌┐┌┌─┐┌┬┐┌─┐    ┬ ┬┌─┐┌┬┐┌─┐┌┬┐┌─┐┬─┐";
    echo "│ ┬├┤ ││││ ││││├┤     │ │├─┘ ││├─┤ │ ├┤ ├┬┘";
    echo "└─┘└─┘┘└┘└─┘┴ ┴└─┘────└─┘┴  ─┴┘┴ ┴ ┴ └─┘┴└─";
    echo "                                     v${version} ";
}

function print_line {
    echo "-------------------------------------------"
}

function showhelp {
    echo
    print_logo
    echo
    echo $'Database options:'
    echo $' -d Database (comma-separated entries)\n\t[genbank, refseq]'
    echo
    echo $'Organism options:'
    echo $' -g Organism group(s) (comma-separated entries, empty for all)\n\t[archaea, bacteria, fungi, human, invertebrate, metagenomes, \n\tother, plant, protozoa, vertebrate_mammalian, vertebrate_other, viral]\n\tDefault: ""'
    echo $' -T Taxonomic identifier(s) (comma-separated entries, empty for all).\n\tExample: "562" (for -M ncbi) or "s__Escherichia coli" (for -M gtdb)\n\tDefault: ""'
    echo
    echo $'File options:'
    echo $' -f file type(s) (comma-separated entries)\n\t[genomic.fna.gz, assembly_report.txt, protein.faa.gz, genomic.gbff.gz]\n\tMore formats at https://ftp.ncbi.nlm.nih.gov/genomes/all/README.txt\n\tDefault: assembly_report.txt'
    echo
    echo $'Filter options:'
    echo $' -c refseq category (comma-separated entries, empty for all)\n\t[reference genome, representative genome, na]\n\tDefault: ""'
    echo $' -l assembly level (comma-separated entries, empty for all)\n\t[complete genome, chromosome, scaffold, contig]\n\tDefault: ""' 
    echo $' -D Start date (>=), based on the sequence release date. Format YYYYMMDD.\n\tDefault: ""'
    echo $' -E End date (<=), based on the sequence release date. Format YYYYMMDD.\n\tDefault: ""'
    echo $' -F custom filter for the assembly summary in the format colA:val1|colB:valX,valY (case insensitive).\n\tExample: -F "2:PRJNA12377,PRJNA670754|14:Partial" (AND between cols, OR between values)\n\tColumn info at https://ftp.ncbi.nlm.nih.gov/genomes/README_assembly_summary.txt\n\tDefault: ""'
    echo
    echo $'Taxonomy options:'
    echo $' -M Taxonomy. gtdb keeps only assemblies in GTDB (latest). ncbi keeps only latest assemblies (version_status). \n\t[ncbi, gtdb]\n\tDefault: "ncbi"'
    echo $' -A Keep a limited number of assemblies for each selected taxa (leaf nodes). 0 for all. \n\tSelection by ranks are also supported with rank:number (e.g genus:3)\n\t[species, genus, family, order, class, phylum, kingdom, superkingdom]\n\tSelection order based on: RefSeq Category, Assembly level, Relation to type material, Date.\n\tDefault: 0'
    echo $' -a Keep the current version of the taxonomy database in the output folder'
    echo
    echo $'Run options:'
    echo $' -o Output/Working directory \n\tDefault: ./tmp.XXXXXXXXXX'
    echo $' -t Threads to parallelize download and some file operations\n\tDefault: 1'
    echo $' -k Dry-run mode. No sequence data is downloaded or updated - just checks for available sequences and changes'
    echo $' -i Fix only mode. Re-downloads incomplete or failed data from a previous run. Can also be used to change files (-f).'
    echo $' -m Check MD5 of downloaded files'
    echo
    echo $'Report options:'
    echo $' -u Updated assembly accessions report\n\t(Added/Removed, assembly accession, url)'
    echo $' -r Updated sequence accessions report\n\t(Added/Removed, assembly accession, genbank accession, refseq accession, sequence length, taxid)\n\tOnly available when file format assembly_report.txt is selected and successfully downloaded'
    echo $' -p Reports URLs successfuly downloaded and failed (url_failed.txt url_downloaded.txt)'
    echo
    echo $'Misc. options:'
    echo $' -b Version label\n\tDefault: current timestamp (YYYY-MM-DD_HH-MM-SS)'
    echo $' -e External "assembly_summary.txt" file to recover data from. Mutually exclusive with -d / -g \n\tDefault: ""'
    echo $' -B Alternative version label to use as the current version. Mutually exclusive with -i.\n\tCan be used to rollback to an older version or to create multiple branches from a base version.\n\tDefault: ""'
    echo $' -R Number of attempts to retry to download files in batches \n\tDefault: 3'
    echo $' -n Conditional exit status based on number of failures accepted, otherwise will Exit Code = 1.\n\tExample: -n 10 will exit code 1 if 10 or more files failed to download\n\t[integer for file number, float for percentage, 0 = off]\n\tDefault: 0'
    echo $' -N Output files in folders like NCBI ftp structure (e.g. files/GCF/000/499/605/GCF_000499605.1_EMW001_assembly_report.txt)'
    echo $' -L Downloader\n\t[wget, curl]\n\tDefault: wget'
    echo $' -x Allow the deletion of regular extra files (not symbolic links) found in the output folder'
    echo $' -s Silent output'
    echo $' -w Silent output with download progress only'
    echo $' -V Verbose log'
    echo $' -Z Print debug information and run in debug mode'
    echo
}

# Defaults
database=""
organism_group=""
taxids=""
refseq_category=""
assembly_level=""
custom_filter=""
file_formats="assembly_report.txt"
top_assemblies=0
date_start=""
date_end=""
tax_mode="ncbi"
download_taxonomy=0
delete_extra_files=0
check_md5=0
updated_assembly_accession=0
updated_sequence_accession=0
url_list=0
dry_run=0
just_fix=0
conditional_exit=0
ncbi_folders=0
silent=0
silent_progress=0
debug_mode=0
working_dir=""
external_assembly_summary=""
retry_download_batch=3
label=""
rollback_label=""
threads=1
verbose_log=0
downloader_tool="wget"

# Check for required tools
tool_not_found=0
tools=( "awk" "bc" "find" "join" "md5sum" "parallel" "sed" "tar" "wget" )
for t in "${tools[@]}"
do
    if [ ! -x "$(command -v ${t})" ]; then
        echo "${t} not found";
        tool_not_found=1;
    fi
done
if [ "${tool_not_found}" -eq 1 ]; then exit 1; fi

# Parse -o and -B first to detect possible updates
getopts_list="aA:b:B:c:d:D:e:E:f:F:g:hikl:L:mM:n:No:prR:st:T:uVwxZ"
OPTIND=1 # Reset getopts
# Parses working_dir from "$@"
while getopts "${getopts_list}" opt; do
  case ${opt} in
    o) working_dir=${OPTARG} ;;
    B) rollback_label=${OPTARG} ;;
    \?) echo "Invalid options" >&2; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
  esac
done

# If workingdir exists and there's a history file, grab and inject params
if [[ ! -z "${working_dir}" && -s "${working_dir}/history.tsv" ]]; then
    
    if [[ ! -z "${rollback_label}" ]]; then
        # If rolling back, get specific parameters of that version
        rollback_assembly_summary="${working_dir}/${rollback_label}/assembly_summary.txt"
        if [[ -f "${rollback_assembly_summary}" ]]; then
            declare -a "args=($(awk -F '\t' '$2 == "'${rollback_label}'"' "${working_dir}/history.tsv" | cut -f 5))"
        else
            echo "Rollback label/assembly_summary.txt not found ["${rollback_assembly_summary}"]"; exit 1
        fi
    else
        # Parse arguments into associative array
        # automatically detecting and replacing the escaped non-printable characters (e.g.: complete\ genome)
        declare -a "args=($(cut -f 5 "${working_dir}/history.tsv" | tail -n 1))"
    fi

    # For each entry of the current argument list $@
    # add to the end of the array to have priority
    c=${#args[@]}
    for f in "$@"; do 
        args[$c]="${f}"
        c=$((c+1))
    done
else
    # parse command line arguments by default
    declare -a "args=($( printf "%q " "$@" ))"
fi

declare -A new_args
bool_args=""
OPTIND=1 # Reset getopts
while getopts "${getopts_list}" opt "${args[@]}"; do
  case ${opt} in
    a) download_taxonomy=1 ;;
    A) top_assemblies=${OPTARG} ;;
    b) label=${OPTARG} ;;
    B) rollback_label=${OPTARG} ;;
    c) refseq_category=${OPTARG} ;;
    d) database=${OPTARG} ;;
    D) date_start=${OPTARG} ;;
    e) external_assembly_summary=${OPTARG} ;;
    E) date_end=${OPTARG} ;;
    f) file_formats=${OPTARG// } ;; #remove spaces
    F) custom_filter=${OPTARG} ;;
    g) organism_group=${OPTARG// } ;; #remove spaces
    h) showhelp; exit 0 ;;
    i) just_fix=1 ;;
    k) dry_run=1 ;;
    l) assembly_level=${OPTARG} ;;
    L) downloader_tool=${OPTARG} ;;
    m) check_md5=1 ;;
    M) tax_mode=${OPTARG} ;;
    n) conditional_exit=${OPTARG} ;;
    N) ncbi_folders=1 ;;
    o) working_dir=${OPTARG} ;;
    p) url_list=1 ;;
    r) updated_sequence_accession=1 ;;
    R) retry_download_batch=${OPTARG} ;;
    s) silent=1 ;;
    t) threads=${OPTARG} ;;
    T) taxids=${OPTARG} ;;
    u) updated_assembly_accession=1 ;;
    V) verbose_log=1 ;;
    w) silent_progress=1 ;;
    x) delete_extra_files=1 ;;
    Z) debug_mode=1 ;;
    \?) echo "Invalid options" >&2; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
  esac

  # Colect parsed args in an associative array for each opt
  # the args added later have precedence
  if [ "${OPTARG-unset}" = unset ]; then
    bool_args="${bool_args} -${opt}"  # boolean args, OPTARG is not set in getopts
  elif [[ ! -z "${OPTARG}" ]]; then
    new_args[${opt}]="-${opt} '${OPTARG}'" # args with option argument
  else
    unset new_args[${opt}] # args with option argument set to ''
  fi

done

# No params
if [ ${OPTIND} -eq 1 ]; then showhelp; exit 1; fi

# Activate debug mode
if [ "${debug_mode}" -eq 1 ] ; then 
    print_debug tools  # Print tools and versions
    # If debug is the only parameter, exit, otherwise set debug mode for the run (set -x)
    if [ $# -eq 1 ]; then
        exit 0;
    else
        set -x
    fi
fi

# Build argument list to save
genome_updater_args="${new_args[@]}"
export genome_updater_args

######################### Parameter validation ######################### 

# If fixing/recovering, need to have assembly_summary.txt
if [[ ! -z "${external_assembly_summary}" ]]; then
    if [[ ! -f "${external_assembly_summary}" ]] ; then
        echo "External assembly_summary.txt not found [$(readlink -m ${external_assembly_summary})]"; exit 1;
    elif [[ ! -z "${database}" || ! -z "${organism_group}" ]]; then
        echo "External assembly_summary.txt cannot be used with database (-d) and/or organism group (-g)"; exit 1;
    fi
fi

if [[ ! -z "${rollback_label}" && "${just_fix}" -eq 1 ]]; then
    echo "-B and -i are mutually exclusive. To continue an update from a previus run, use -B ''"; exit 1;
fi

if [[ ! "${file_formats}" =~ "assembly_report.txt" && "${updated_sequence_accession}" -eq 1 ]]; then
    echo "Updated sequence accessions report (-r) can only be used if -f contains 'assembly_report.txt'"; exit 1;
fi

if [[ -z "${database}" && -z "${external_assembly_summary}" ]]; then
    echo "Database is required (-d)"; exit 1;
elif [[ ! -z "${database}" ]]; then
    valid_databases=( "genbank" "refseq" )
    for d in ${database//,/ }; do
        if [[ ! " ${valid_databases[@]} " =~ " ${d} " ]]; then
            echo "${d}: invalid database [ $(printf "'%s' " "${valid_databases[@]}")]"; exit 1;
        fi
    done
fi

gtdb_urls=()
if [[ "${tax_mode}" == "gtdb" ]]; then
    if [[ -z "${organism_group}" ]]; then
        gtdb_urls+=("${gtdb_base_url}ar53_taxonomy.tsv.gz")
        gtdb_urls+=("${gtdb_base_url}bac120_taxonomy.tsv.gz")
    else
        for og in ${organism_group//,/ }; do
            if [[ "${og}" == "archaea" ]]; then
                gtdb_urls+=("${gtdb_base_url}ar53_taxonomy.tsv.gz")
            elif [[ "${og}" == "bacteria" ]]; then
                gtdb_urls+=("${gtdb_base_url}bac120_taxonomy.tsv.gz")
            else
                echo "${og}: invalid organism group for GTDB [ 'archaea' 'bacteria' ] "; exit 1;
            fi
        done
    fi
elif [[ "${tax_mode}" == "ncbi" ]]; then
    valid_organism_groups=( "archaea" "bacteria" "fungi" "human" "invertebrate" "metagenomes" "other" "plant" "protozoa" "vertebrate_mammalian" "vertebrate_other" "viral" )
    for og in ${organism_group//,/ }; do
        if [[ ! " ${valid_organism_groups[@]} " =~ " ${og} " ]]; then
            echo "${og}: invalid organism group [ $(printf "'%s' " "${valid_organism_groups[@]}")]"; exit 1;
        fi
    done
else
    echo "${tax_mode}: invalid taxonomy mode ['ncbi' 'gtdb']"; exit 1;
fi

if [[ "${tax_mode}" == "ncbi" ]]; then
    if [[ ! -z "${taxids}"  ]]; then
        if [[ ! "${taxids}" =~ ^[0-9,]+$ ]]; then
            echo "${taxids}: invalid taxids"; exit 1;
        fi
    fi
    taxids=${taxids// } # remove spaces
elif [[ "${tax_mode}" == "gtdb" ]]; then
    IFS=","
    for tx in ${taxids}; do
        if [[ ! "${tx}" =~ ^[dpcofgs]__.* ]]; then
            echo "${tx}: invalid taxid"; exit 1;
        fi
    done
    IFS=$' '
fi

# top assemblies by rank
if [[ ! "${top_assemblies}" =~ ^[0-9]+$ && ! "${top_assemblies}" =~ ^(superkingdom|phylum|class|order|family|genus|species)\:[1-9][0-9]*$ ]]; then
    echo "${top_assemblies}: invalid top assemblies - should be a number > 0 or [superkingdom|phylum|class|order|family|genus|species]:number"; exit 1;
else
    top_assemblies_rank=""
    if [[ "${top_assemblies}" =~ ^[0-9]+$ ]]; then
        top_assemblies_num=${top_assemblies}
    else
        top_assemblies_rank=${top_assemblies%:*}
        top_assemblies_num=${top_assemblies#*:}
    fi
fi

IFS=","
valid_refseq_category=( "reference genome" "representative genome" "na" )
if [[ ! -z "${refseq_category}" ]]; then
    for rc in ${refseq_category}; do
        # ${rc,,} to lowercase
        if [[ ! " ${valid_refseq_category[@]} " =~ " ${rc,,} " ]]; then
            echo "${rc}: invalid refseq category [ $(printf "'%s' " "${valid_refseq_category[@]}")]"; exit 1;
        fi
    done
fi
if [[ ! -z "${assembly_level}" ]]; then
    valid_assembly_level=( "complete genome" "chromosome" "scaffold" "contig" )
    for al in ${assembly_level}; do
        # ${al,,} to lowercase
        if [[ ! " ${valid_assembly_level[@]} " =~ " ${al,,} " ]]; then
            echo "${al}: invalid assembly level [ $(printf "'%s' " "${valid_assembly_level[@]}")]"; exit 1;
        fi
    done
fi
IFS=$' '
if [[ ! -z "${date_start}" ]]; then
    if ! date "+%Y%m%d" -d "${date_start}" > /dev/null 2>&1; then
        echo "${date_start}: invalid start date"; exit 1;
    fi
fi
if [[ ! -z "${date_end}" ]]; then
    if ! date "+%Y%m%d" -d "${date_end}" > /dev/null 2>&1; then
        echo "${date_end}: invalid end date"; exit 1;
    fi
fi

######################### Variable assignment ######################### 

# Define downloader to use
if [[ ! -z "${local_dir}" || "${downloader_tool}" == "curl" ]]; then
    function downloader(){ # parameter: ${1} output file, ${2} url
        curl --silent --retry ${retries} --connect-timeout ${timeout} --output "${1}" "${2}"
    }
else
    function downloader(){ # parameter: ${1} output file, ${2} url
        wget --quiet --continue --tries ${retries} --read-timeout ${timeout} --output-document "${1}" "${2}"
    }
fi
export -f downloader

if [ "${silent}" -eq 1 ] ; then 
    silent_progress=0
elif [ "${silent_progress}" -eq 1 ] ; then 
    silent=1
fi
n_formats=$(echo ${file_formats} | tr -cd , | wc -c) # number of file formats
timestamp=$(date +%Y-%m-%d_%H-%M-%S) # timestamp of the run
export check_md5 silent silent_progress n_formats timestamp verbose_log # To be accessible in functions called by parallel

# Create working directory
if [[ -z "${working_dir}" ]]; then
    working_dir=$(mktemp -d -p .) # default
else
    mkdir -p "${working_dir}" #user input
fi
working_dir="$(readlink -m ${working_dir})/"
files_dir="files/"
export files_dir working_dir ncbi_folders

default_assembly_summary=${working_dir}assembly_summary.txt
history_file=${working_dir}history.tsv

# set MODE
if [[ "${just_fix}" -eq 1 ]]; then
    MODE="FIX";
elif [[ ! -f "${default_assembly_summary}" ]] || [[ ! -z "${external_assembly_summary}" ]]; then
    MODE="NEW";
else
    MODE="UPDATE";
fi

# If file already exists and it's a new repo
if [[ "${MODE}" == "NEW" ]]; then
    if [[ -f "${default_assembly_summary}" || -L "${default_assembly_summary}" ]]; then
        echo "Cannot start a new repository with an existing assembly_summary.txt in the working directory [${default_assembly_summary}]"; exit 1;
    fi
fi

# If file already exists and it's a new repo
if [[ "${MODE}" == "FIX" ]]; then
    if [[ ! -f "${default_assembly_summary}" ]]; then
        echo "Cannot find assembly_summary.txt version to fix [${default_assembly_summary}]"; exit 1;
    fi
fi

if [[ "${MODE}" == "UPDATE" ]]; then
    # Rollback to a different base version
    if [[ ! -z "${rollback_label}" ]]; then
        rollback_assembly_summary="${working_dir}/${rollback_label}/assembly_summary.txt"
        if [[ -f "${rollback_assembly_summary}" ]]; then
            rm ${default_assembly_summary}
            ln -s -r "${rollback_assembly_summary}" "${default_assembly_summary}"
        else
            echo "Rollback label/assembly_summary.txt not found ["${rollback_assembly_summary}"]"; exit 1
        fi
    fi
fi

if [[ "${MODE}" == "UPDATE" ]] || [[ "${MODE}" == "FIX" ]]; then # get existing version information
    # Check if default assembly_summary is a symbolic link to some version
    if [[ ! -L "${default_assembly_summary}"  ]]; then
        echo "assembly_summary.txt is not a link to any version [${default_assembly_summary}]"; exit 1
    fi
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
        if [[ ! -z "${label}" ]]; then 
            echo "Label ["${label}"] already used. Please set another label with -b"; exit 1;
        else 
            echo "Cannot start a new repository with an existing assembly_summary.txt in the new directory [${new_assembly_summary}]"; exit 1;
        fi
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
extra_files=0

if [ "${silent}" -eq 0 ]; then 
    print_line
    print_logo
    print_line
fi

echolog "--- genome_updater version: ${version} ---" "0"
echolog "Mode: ${MODE} $(if [[ "${dry_run}" -eq 1 ]]; then echo "(DRY-RUN)"; fi)" "1"
echolog "Args: ${genome_updater_args}${bool_args}" "1"
echolog "Outp: ${working_dir}" "1"
echolog "-------------------------------------" "1"

if [ "${debug_mode}" -eq 1 ] ; then 
    ls -laR "${working_dir}"
fi

# new
if [[ "${MODE}" == "NEW" ]]; then

    # SET TARGET
    target_output_prefix=${new_output_prefix}
    export target_output_prefix

    if [[ ! -z "${external_assembly_summary}" ]]; then
        echolog "Using external assembly summary [$(readlink -m ${external_assembly_summary})]" "1"
        # Skip possible header lines (|| true -> do not output error if none)
        grep -v "^#" "${external_assembly_summary}" > "${new_assembly_summary}" || true
        if ! check_assembly_summary "${new_assembly_summary}"; then 
            echolog " - Invalid external assembly_summary.txt" "1"
            exit 1; 
        fi
        all_lines=$(count_lines_file "${new_assembly_summary}")
    else
        echolog "Downloading assembly summary [${new_label}]" "1"
        echolog " - Database [${database}]" "1"
        if [[ ! -z "${organism_group}" ]]; then
            echolog " - Organism group [${organism_group}]" "1"
        fi
        if ! get_assembly_summary "${new_assembly_summary}" "${database}" "${organism_group}"; then 
            echolog " - Failed to download one or more assembly_summary files" "1"
            exit 1; 
        fi
        all_lines=$(count_lines_file "${new_assembly_summary}")
    fi
    echolog " - ${all_lines} assembly entries available" "1"
    echolog "" "1"
    echolog "Filtering assembly summary [${new_label}]" "1"
    if ! filter_assembly_summary "${new_assembly_summary}" ${all_lines}; then
        echolog " - Failed" "1";
        exit 1;
    fi
    filtered_lines=$(count_lines_file "${new_assembly_summary}")
    echolog " - ${filtered_lines} assembly entries to download" "1"
    echolog "" "1"
    
    if [[ "${dry_run}" -eq 1 ]]; then
        rm "${new_assembly_summary}" "${log_file}"
        if [ ! "$(ls -A ${new_output_prefix}${files_dir})" ]; then rm -r "${new_output_prefix}${files_dir}"; fi #Remove folder that was just created (if there's nothing in it)
        if [ ! "$(ls -A ${new_output_prefix})" ]; then rm -r "${new_output_prefix}"; fi #Remove folder that was just created (if there's nothing in it)
        if [ ! "$(ls -A ${working_dir})" ]; then rm -r "${working_dir}"; fi #Remove folder that was just created (if there's nothing in it)
    else
        # Set version - link new assembly as the default
        ln -s -r "${new_assembly_summary}" "${default_assembly_summary}"
        # Add entry on history
        write_history ${new_label} ${new_label} ${timestamp} ${new_assembly_summary}

        if [[ "${filtered_lines}" -gt 0 ]] ; then
            echolog "Downloading $((filtered_lines*(n_formats+1))) files with ${threads} threads" "1"
            download_files "${new_assembly_summary}" "1,20" "${file_formats}"
            echolog "" "1"

            if [ "${updated_assembly_accession}" -eq 1 ]; then 
                echolog "Writing assembly accession report" "1"
                output_assembly_accession "${new_assembly_summary}" "1,20" "${file_formats}" "A" > "${new_output_prefix}${timestamp}_assembly_accession.txt"
                echolog " - ${new_output_prefix}${timestamp}_assembly_accession.txt" "1"
                echolog "" "1"
            fi
            if [ "${updated_sequence_accession}" -eq 1 ]; then
                echolog "Writing sequence accession report" "1"
                output_sequence_accession "${new_assembly_summary}" "1,20" "${file_formats}" "A" "${new_assembly_summary}" > "${new_output_prefix}${timestamp}_sequence_accession.txt"
                echolog " - ${new_output_prefix}${timestamp}_sequence_accession.txt" "1"
                echolog "" "1"
            fi
        fi
    fi
    
else # update/fix

    # SET TARGET for fix
    target_output_prefix=${current_output_prefix}
    export target_output_prefix

    # Check for missing files on current version
    echolog "Checking for missing files in the current version [${current_label}]" "1"
    missing=$(tmp_file "missing.tmp")
    check_missing_files "${current_assembly_summary}" "1,20" "${file_formats}" > "${missing}" # assembly accession, url, filename
    missing_lines=$(count_lines_file "${missing}")

    if [ "${missing_lines}" -gt 0 ]; then
        echolog " - ${missing_lines} missing files" "1"
        if [ "${dry_run}" -eq 0 ]; then
            if [ "${just_fix}" -eq 1 ]; then
                write_history ${current_label} "" ${timestamp} ${current_assembly_summary}
            fi
            echolog "Downloading ${missing_lines} files with ${threads} threads" "1"
            download_files "${missing}" "2,3"
            echolog "" "1"
            # if new files were downloaded, rewrite reports (overwrite information on Removed accessions - all become Added)
            if [ "${updated_assembly_accession}" -eq 1 ]; then 
                echolog "Writing assembly accession report" "1"
                output_assembly_accession "${missing}" "1,2" "${file_formats}" "A" > "${current_output_prefix}${timestamp}_assembly_accession.txt"
                echolog " - ${current_output_prefix}${timestamp}_assembly_accession.txt" "1"
                echolog "" "1"
            fi
            if [ "${updated_sequence_accession}" -eq 1 ]; then
                echolog "Writing sequence accession report" "1"
                output_sequence_accession "${missing}" "1,2" "${file_formats}" "A" "${current_assembly_summary}" > "${current_output_prefix}${timestamp}_sequence_accession.txt"
                echolog " - ${current_output_prefix}${timestamp}_sequence_accession.txt" "1"
                echolog "" "1"
            fi
        fi
    else
        echolog " - None" "1"
    fi
    echolog "" "1"
    rm "${missing}"

    echolog "Checking for extra files in the current version [${current_label}]" "1"
    extra=$(tmp_file "extra.tmp")
    # List local files, "1" to list also empty files
    join <(list_local_files "${current_output_prefix}" "1" | sort) <(list_files "${current_assembly_summary}" "1,20" "${file_formats}" | cut -f 3 | sed -e 's/.*\///' | sort) -v 1 > "${extra}"
    extra_files=$(count_lines_file "${extra}")
    if [ "${extra_files}" -gt 0 ]; then
        echolog " - ${extra_files} extra files" "1"
        if [ "${dry_run}" -eq 0 ]; then    
            del_files=$(remove_files "${extra}" "1")
            echolog " - ${del_files} files successfully deleted" "1";
            # Keep track how many extra files were kept
            extra_files=$((extra_files - del_files))
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

        echolog "Downloading assembly summary [${new_label}]" "1"
        echolog " - Database [${database}]" "1"
        if [[ ! -z "${organism_group}" ]]; then
            echolog " - Organism group [${organism_group}]" "1";
        fi
        if ! get_assembly_summary "${new_assembly_summary}" "${database}" "${organism_group}"; then 
            echolog " - Failed to download one or more assembly_summary files" "1";   
            exit 1; 
        fi
        all_lines=$(count_lines_file "${new_assembly_summary}")

        echolog " - ${all_lines} assembly entries available" "1"
        echolog "" "1"
        echolog "Filtering assembly summary [${new_label}]" "1"
        if ! filter_assembly_summary "${new_assembly_summary}" ${all_lines}; then
            echolog " - Failed" "1";
            exit 1;
        fi
        filtered_lines=$(count_lines_file "${new_assembly_summary}")
        echolog " - ${filtered_lines} assembly entries to download" "1"
        echolog "" "1"
        
        update=$(tmp_file "update.tmp")
        remove=$(tmp_file "remove.tmp")
        new=$(tmp_file "new.tmp")
        # UPDATED (verify if version or date changed)
        join <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); gsub("/","",$15); print $1,acc_ver,$15,$20}' ${new_assembly_summary} | sort -k 1,1) <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); gsub("/","",$15); print $1,acc_ver,$15,$20}' ${current_assembly_summary} | sort -k 1,1) -o "1.2,1.3,1.4,2.2,2.3,2.4" | awk '{if($2>$5 || $1!=$4){print $1"\t"$3"\t"$4"\t"$6}}' > ${update}
        update_lines=$(count_lines_file "${update}")
        # REMOVED
        join <(cut -f 1 ${new_assembly_summary} | sed 's/\.[0-9]*//g' | sort) <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); print $1,acc_ver,$20}' ${current_assembly_summary} | sort -k 1,1) -v 2 -o "2.2,2.3" | tr ' ' '\t' > ${remove}
        remove_lines=$(count_lines_file "${remove}")
        # NEW
        join <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); print $1,acc_ver,$20}' ${new_assembly_summary} | sort -k 1,1) <(cut -f 1 ${current_assembly_summary} | sed 's/\.[0-9]*//g' | sort) -o "1.2,1.3" -v 1 | tr ' ' '\t' > ${new}
        new_lines=$(count_lines_file "${new}")
        echolog "Updates available [${current_label} --> ${new_label}]" "1"
        echolog " - ${update_lines} updated, ${remove_lines} removed, ${new_lines} new entries" "1"
        echolog "" "1"

        if [ "${dry_run}" -eq 1 ]; then
            rm -r "${new_output_prefix}"
        else
            # Link versions
            echolog "Linking versions [${current_label} --> ${new_label}]" "1"
            # Only link existing files relative to the current version
            list_files "${current_assembly_summary}" "1,20" "${file_formats}" | cut -f 3 | parallel -P "${threads}" link_version "${current_output_prefix}" "${new_output_prefix}" "{}"
            echolog " - Done" "1"
            echolog "" "1"
            # set version - update default assembly summary
            echolog "Setting-up new version [${new_label}]" "1"
            rm "${default_assembly_summary}"
            ln -s -r "${new_assembly_summary}" "${default_assembly_summary}"
            # Add entry on history
            write_history ${current_label} ${new_label} ${timestamp} ${new_assembly_summary}
            echolog " - Done" "1"
            echolog "" "1"

            # UPDATED INDICES assembly accession
            if [ "${updated_assembly_accession}" -eq 1 ]; then 
                output_assembly_accession "${update}" "3,4" "${file_formats}" "R" > "${new_output_prefix}${timestamp}_assembly_accession.txt"
                output_assembly_accession "${remove}" "1,2" "${file_formats}" "R" >> "${new_output_prefix}${timestamp}_assembly_accession.txt"
            fi
            # UPDATED INDICES sequence accession (removed entries - do it before deleting them)
            if [ "${updated_sequence_accession}" -eq 1 ]; then
                # current_assembly_summary is the old summary
                output_sequence_accession "${update}" "3,4" "${file_formats}" "R" "${current_assembly_summary}" > "${new_output_prefix}${timestamp}_sequence_accession.txt"
                output_sequence_accession "${remove}" "1,2" "${file_formats}" "R" "${current_assembly_summary}" >> "${new_output_prefix}${timestamp}_sequence_accession.txt"
            fi
            
            # Execute updates
            echolog "Updating" "1"
            if [ "${update_lines}" -gt 0 ]; then
                echolog " - UPDATE: Removing $((update_lines*(n_formats+1))) files " "1"
                # remove old version
                del_lines=$(remove_files "${update}" "3,4" "${file_formats}")
                echolog " - ${del_lines} files successfully removed from the current version" "1"
                echolog " - UPDATE: Downloading $((update_lines*(n_formats+1))) files with ${threads} threads" "1"
                # download new version
                download_files "${update}" "1,2" "${file_formats}"
            fi
            if [ "${remove_lines}" -gt 0 ]; then
                echolog " - REMOVE: Removing $((remove_lines*(n_formats+1))) files" "1"
                del_lines=$(remove_files "${remove}" "1,2" "${file_formats}")
                echolog " - ${del_lines} files successfully removed from the current version" "1"
            fi
            if [ "${new_lines}" -gt 0 ]; then
                echolog " - NEW: Downloading $((new_lines*(n_formats+1))) files with ${threads} threads"    "1"
                download_files "${new}" "1,2" "${file_formats}"
            fi 
            echolog " - Done" "1"
            echolog "" "1"

            # UPDATED INDICES assembly accession (added entries - do it after downloading them)
            if [ "${updated_assembly_accession}" -eq 1 ]; then 
                echolog "Writing assembly accession report" "1"
                output_assembly_accession "${update}" "1,2" "${file_formats}" "A" >> "${new_output_prefix}${timestamp}_assembly_accession.txt"
                output_assembly_accession "${new}" "1,2" "${file_formats}" "A" >> "${new_output_prefix}${timestamp}_assembly_accession.txt"
                echolog " - ${new_output_prefix}${timestamp}_assembly_accession.txt" "1"
                echolog "" "1"
            fi
            # UPDATED INDICES sequence accession (added entries - do it after downloading them)
            if [ "${updated_sequence_accession}" -eq 1 ]; then
                echolog "Writing sequence accession report" "1"
                output_sequence_accession "${update}" "1,2" "${file_formats}" "A" "${new_assembly_summary}">> "${new_output_prefix}${timestamp}_sequence_accession.txt"
                output_sequence_accession "${new}" "1,2" "${file_formats}" "A" "${new_assembly_summary}" >> "${new_output_prefix}${timestamp}_sequence_accession.txt"
                echolog " - ${new_output_prefix}${timestamp}_sequence_accession.txt" "1"
                echolog "" "1"
            fi
        fi
        # Remove update files
        rm ${update} ${remove} ${new}
    fi
fi

if [ "${dry_run}" -eq 0 ]; then

    # Clean possible empty folders in NCBI structure after update
    if [[ "${ncbi_folders}" -eq 1 ]]; then
        find "${target_output_prefix}${files_dir}" -type d -empty -delete
    fi

    if [ "${download_taxonomy}" -eq 1 ]; then
        echolog "Downloading taxonomy database [${tax_mode}]" "1"
        if [[ "${tax_mode}" == "ncbi" ]]; then
            if ! download_retry_md5 "${ncbi_base_url}pub/taxonomy/taxdump.tar.gz" "${target_output_prefix}taxdump.tar.gz" "${ncbi_base_url}pub/taxonomy/taxdump.tar.gz.md5" "${retry_download_batch}"; then
                echolog " - Failed" "1"
            else
                echolog " - ${target_output_prefix}taxdump.tar.gz" "1"
            fi
        else
            for url in "${gtdb_urls[@]}"; do
                if ! download_retry_md5 "${url}" "${target_output_prefix}${url##*/}" "${gtdb_base_url}MD5SUM.txt" "${retry_download_batch}"; then
                    echolog " - Failed" "1"
                else
                    echolog "${target_output_prefix}${url##*/}" "1"
                fi
            done
        fi
        echolog "" "1"
    fi

    expected_files=$(( $(count_lines_file "${default_assembly_summary}")*(n_formats+1) )) # From assembly summary * file formats
    current_files=$(list_local_files "${target_output_prefix}" | wc -l | cut -f1 -d' ') # From current folder

    # If is in fixing mode, remove kept extra files from calculation
    if [[ "${extra_files}" -gt 0 && "${just_fix}" -eq 1 ]]; then
        current_files=$(( current_files-extra_files ))
    fi

    [ "${silent}" -eq 0 ] && print_line
    echolog "# ${current_files}/${expected_files} files in the current version" "1"
    # Check if the valid amount of files on folder amount of files on folder
    if [ $(( expected_files-current_files )) -gt 0 ]; then
        echolog " - $(( expected_files-current_files )) file(s) failed to download. Please re-run your command again with -i to fix it" "1"
    fi
    if [[ "${extra_files}" -gt 0 && "${just_fix}" -eq 1 ]]; then
        echolog " - ${extra_files} extra file(s) found in the output files folder. To delete them, re-run your command with -i -x" "1"
    fi
    echolog "# Current version: $(dirname $(readlink -m ${default_assembly_summary}))" "1"
    echolog "# Log file       : ${log_file}" "1"
    echolog "# History        : ${history_file}" "1"
    [ "${silent}" -eq 0 ] && print_line

    if [ "${debug_mode}" -eq 1 ] ; then 
        ls -laR "${working_dir}"
    fi

    # Exit conditional status
    exit $(exit_status ${expected_files} ${current_files})
fi
