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

wget_tries=5
wget_timeout=20
export wget_tries wget_timeout

get_taxonomy()
{
	wget -qO- --tries="${wget_tries}" --read-timeout="${wget_timeout}" ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz > ${1}
}

get_assembly_summary() # parameter: assembly_summary file
{
	for d in ${database//,/ }
	do
		for g in ${organism_group//,/ }
		do
			 wget --tries="${wget_tries}" --read-timeout="${wget_timeout}" -qO- ftp://ftp.ncbi.nlm.nih.gov/genomes/${d}/${g}/assembly_summary.txt | tail -n+3 >> ${1}
		done
	done
	wc -l ${1} | cut -f1 -d' ' #return number of lines
}

filter_assembly_summary() # parameter: assembly_summary file
{
	if [[ "${refseq_category}" != "all" || "${assembly_level}" != "all" ]]
	then
		awk -F "\t" -v refseq_category="${refseq_category}" -v assembly_level="${assembly_level}" 'BEGIN{if(refseq_category=="all") refseq_category=".*"; if(assembly_level=="all") assembly_level=".*"} $5 ~ refseq_category && $12 ~ assembly_level && $11=="latest" {print $0}' ${1} > "${1}_filtered"
		mv "${1}_filtered" ${1}
	fi
	wc -l ${1} | cut -f1 -d' ' #return number of lines
}

print_progress() # parameter: ${1} file number, ${2} total number of files
{
	echo -ne "   ${1}/${2} ($(bc -l <<< "scale=4;(${1}/${2})*100")%)\r"
}
export -f print_progress #export it to be accessible to the parallel call

check_file() # parameter: ${1} url - returns 0 (ok) / 1 (error)
{
	file_name=$(basename ${1})
	# Check if file exists and if it has a size greater than zero (-s)
	if [ ! -s "${files}${file_name}" ]; then
		echo "${file_name} download failed [${1}]" |& tee -a ${log_file}
		# Remove file if exists (only zero-sized files)
		rm -vf ${files}${file_name} >> ${log_file} 2>&1
		return 1
	else
		echo "${file_name} downloaded successfully [${1} -> ${files}${file_name}]" >> ${log_file}
		return 0
	fi
}
export -f check_file

check_md5_ftp() # parameter: ${1} url 
{
	md5checksums_url="$(dirname ${1})/md5checksums.txt" # ftp directory
	file_name=$(basename ${1}) # downloaded file name
	md5checksums_file=$(wget -qO- --tries="${wget_tries}" --read-timeout="${wget_timeout}" "${md5checksums_url}")
	if [ -z "${md5checksums_file}" ]; then
		echo "${file_name} MD5checksum file download failed [${md5checksums_url}] - FILE KEPT" >> ${log_file}
	else
		ftp_md5=$(echo "${md5checksums_file}" | grep "${file_name}$" | cut -f1 -d' ')
		if [ -z "${ftp_md5}" ]; then
			echo "${file_name} MD5checksum file not available [${md5checksums_url}] - FILE KEPT" >> ${log_file}
		else
			file_md5=$(md5sum ${files}${file_name} | cut -f1 -d' ')
			if [ "${file_md5}" != "${ftp_md5}" ]; then
				echo "${file_name} MD5 not matching [${md5checksums_url}] - FILE REMOVED" |& tee -a ${log_file}
				# Remove file only when MD5 doesn't match
				rm -v ${files}${file_name} >> ${log_file} 2>&1
			else
				# Outputs checked md5 only on log
				echo "${file_name} MD5 successfuly checked ${file_md5} [${md5checksums_url}]" >> ${log_file}
			fi	
		fi
	fi
	
}
export -f check_md5_ftp #export it to be accessible to the parallel call

download_files() # parameter: ${1} file, ${2} field [url], ${3} extension
{
	lines=$(wc -l ${1} | cut -f1 -d' ')
	total_files=$(( lines * (n_formats+1) ))
	rm -f ${output_folder}/url_list.download
	if [ -z "${3}" ] #direct download (full url)
	then
		cut --fields="${2}" ${1} > ${output_folder}/url_list.download 
	else
		for f in ${3//,/ }
		do
			cut --fields="${2}" ${1} | awk -F "\t" -v ext="${f}" '{url_count=split($1,url,"/"); print $1"/"url[url_count] "_" ext}' >> ${output_folder}/url_list.download
		done
	fi
	# parallel -k parameter keeps job output order (better for showing progress) but makes it a bit slower 
	parallel --gnu -a ${output_folder}/url_list.download -j ${threads} '
			wget {1} --quiet --continue --tries='"${wget_tries}"' --read-timeout='"${wget_timeout}"' -P '"${files}"'; 
			if check_file {1}; then 
				if [ '"${check_md5}"' -eq 1 ]; then check_md5_ftp "{1}"; fi;
			fi;
			print_progress "{#}" '"${total_files}"'
		'
	print_progress "${total_files}" "${total_files}"
	rm -f ${output_folder}/url_list.download
}

remove_files() # parameter: ${1} file, ${2} field [url], ${3} extension
{
	if [ -z "${3}" ] #direct remove (filename)
	then
		cut --fields="${2}" ${1} | xargs --no-run-if-empty -I{} rm ${files}{} -v >> ${log_file} 2>&1
	else
		for f in ${3//,/ }
		do
			cut --fields="${2}" ${1} | awk -F "\t" -v ext="${f}" '{url_count=split($1,url,"/"); print url[url_count] "_" ext}' | xargs --no-run-if-empty -I{} rm ${files}{} -v >> ${log_file} 2>&1
		done
	fi
}

check_missing_files() # parameter: ${1} file, ${2} field [url], ${3} extension - returns URL
{
	# Just returns if file doens't exist or if it's zero size
	for f in ${3//,/ }
	do
		cut --fields="${2}" ${1} | awk -F "\t" -v ext="${f}" '{url_count=split($1,url,"/"); print $1 " " url[url_count] "_" ext}' | xargs --no-run-if-empty -n2 sh -c 'if [ ! -s "'"${files}"'${1}" ]; then echo "${0}/${1}"; fi'
	done
}

list_files() # parameter: ${1} file, ${2} field [url], ${3} extension - returns filename
{
	# return all filenames
	for f in ${3//,/ }
	do
		cut --fields="${2}" ${1} | awk -F "\t" -v ext="${f}" '{url_count=split($1,url,"/"); print url[url_count] "_" ext}'
	done
}

output_assembly_accession() # parameters: ${1} file, ${2} field [assembly accession, url], ${3} mode (A/R)
{
	cut --fields="${2}" ${1} | sed "s/^/${3}\t/"
}
output_sequence_accession() # parameters: ${1} file, ${2} field [assembly accession], ${3} mode (A/R), ${4} assembly_summary
{
	cut --fields="${2}" ${1} | sort -k 1,1 | join - <(sort -k 1,1 ${4}) -t$'\t' -o "2.6,2.20" | awk -F "\t" -v files="${files}" '{url_count=split($2,url,"/"); print $1 "\t" files url[url_count] "_assembly_report.txt"}' | parallel --colsep "\t" 'grep "^[^#]" {2} | tr -d "\r" | cut -f 5,7,9 | sed s/$/\\t{1}/' | sed "s/^/${3}\t/"
}

# Defaults
version="0.07"
database="refseq"
organism_group="bacteria"
refseq_category="all"
assembly_level="all"
file_formats="genomic.fna.gz"
download_taxonomy=0
delete_extra_files=0
check_md5=0
updated_assembly_accession=0
updated_sequence_accession=0
just_check=0
just_fix=0
output_folder="db"
threads=1

function showhelp {
	echo "genome_updater v${version} by Vitor C. Piro (vitorpiro@gmail.com, http://github.com/pirovc)"
	echo
	echo $' -d Database [all, genbank, refseq]\n\tDefault: refseq'
	echo $' -g Organism group [archaea, bacteria, fungi, invertebrate, metagenomes (only genbank), other (synthetic genomes - only genbank), plant, protozoa, vertebrate_mammalian, vertebrate_other, viral (only refseq)]\n\tDefault: bacteria'
	echo $' -c RefSeq Category [all, reference genome, representative genome, na]\n\tDefault: all'
	echo $' -l Assembly level [all, Complete Genome, Chromosome, Scaffold, Contig]\n\tDefault: all'
	echo $' -f File formats [genomic.fna.gz,assembly_report.txt, ... - check ftp://ftp.ncbi.nlm.nih.gov/genomes/all/README.txt for all file formats]\n\tDefault: genomic.fna.gz'
	echo
	echo $' -a Download current version of the Taxonomy database (taxdump.tar.gz)'
	echo $' -k Just check for updates, keep current version'
	echo $' -i Just fix files based on the current version, do not look for updates'
	echo $' -x Delete any extra files inside the folder'
	echo $' -m Check md5 (after download only)'
	echo
	echo $' -u Output list of updated assembly accessions (Added/Removed, assembly accession, url)'
	echo $' -r Output list of updated sequence accessions (Added/Removed, refseq accession, genbank accession, sequence length, taxid). Only available when file assembly_report.txt is downloaded'
	echo
	echo $' -o Output folder\n\tDefault: db/'
	echo $' -t Threads\n\tDefault: 1'
	echo
}

# Check for required tools
tools=( "getopts" "parallel" "awk" "wget" "join" "bc" "md5sum" )
for t in "${tools[@]}"
do
	command -v ${t} >/dev/null 2>/dev/null || { echo ${t} not found; exit 1; }
done

OPTIND=1 # Reset getopts
while getopts "d:g:c:l:o:t:f:akixmurh" opt; do
  case ${opt} in
    d) database=${OPTARG} ;;
    g) organism_group=${OPTARG} ;;
	c) refseq_category=${OPTARG} ;;
	l) assembly_level=${OPTARG} ;;
	o) output_folder=${OPTARG} ;;
	t) threads=${OPTARG} ;;
	f) file_formats=${OPTARG} ;;
	a) download_taxonomy=1 ;;
	k) just_check=1 ;;
	i) just_fix=1 ;;
	x) delete_extra_files=1 ;;
	m) check_md5=1 ;;
	u) updated_assembly_accession=1 ;;
	r) updated_sequence_accession=1 ;;
    h|\?) showhelp; exit 1 ;;
    :) echo "Option -${OPTARG} requires an argument." >&2; exit 1 ;;
  esac
done
if [ ${OPTIND} -eq 1 ]; then showhelp; exit 1; fi
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

if [ ${database} == "all" ]; then database="genbank,refseq"; fi
DATE=$(date +%Y-%m-%d_%H-%M-%S)
mkdir -p ${output_folder}
mkdir -p ${output_folder}/files/
files=${output_folder}/files/
std_assembly_summary=${output_folder}/assembly_summary.txt
n_formats=$(echo ${file_formats} | tr -cd , | wc -c)
log_file=${output_folder}/${DATE}.log

# To be accessible in functions called by parallel
export files log_file output_folder

echo "genome_updater version: ${version}" |& tee -a ${log_file}
echo "Database: ${database}" |& tee -a ${log_file}
echo "Organims group: ${organism_group}" |& tee -a ${log_file}
echo "RefSeq category: ${refseq_category}" |& tee -a ${log_file}
echo "Assembly level: ${assembly_level}" |& tee -a ${log_file}
echo "File formats: ${file_formats}" |& tee -a ${log_file}
echo "Download taxonomy: ${download_taxonomy}" |& tee -a ${log_file}
echo "Just check for updates: ${just_check}" |& tee -a ${log_file}
echo "Just fix current version: ${just_fix}" |& tee -a ${log_file}
echo "Delete extra files: ${delete_extra_files}" |& tee -a ${log_file}
echo "Check md5: ${check_md5}" |& tee -a ${log_file}
echo "Output updated assembly accessions: ${updated_assembly_accession}" |& tee -a ${log_file}
echo "Output updated sequence accessions: ${updated_sequence_accession}" |& tee -a ${log_file}
echo "Threads: ${threads}" |& tee -a ${log_file}
echo "Output folder: ${output_folder}" |& tee -a ${log_file}
echo "Output files: ${files}" |& tee -a ${log_file}
echo "" |& tee -a ${log_file}
	
# PROGRAM MODE (check, fix, new or update)
if [ "${just_check}" -eq 1 ]; then
	echo "-- CHECK --" |& tee -a ${log_file}
elif [ ! -f "${std_assembly_summary}" ]; then
	if [ "${just_fix}" -eq 1 ]; then
		echo "No current version found [$(readlink -m ${output_folder})]"
		exit
	fi
	echo "-- NEW --" |& tee -a ${log_file}
elif [ "${just_fix}" -eq 1 ]; then
	echo "-- FIX --" |& tee -a ${log_file}
else
	echo "-- UPDATE --" |& tee -a ${log_file}
fi

if [ "${updated_assembly_accession}" -eq 1 ]; then updated_assembly_accession_file=${output_folder}/${DATE}_updated_assembly_accession.txt; fi
if [ "${updated_sequence_accession}" -eq 1 ]; then updated_sequence_accession_file=${output_folder}/${DATE}_updated_sequence_accession.txt; fi

# new download
if [ ! -f "${std_assembly_summary}" ]; then

	assembly_summary=${output_folder}/${DATE}_assembly_summary.txt
    echo "Downloading assembly summary [$(basename ${assembly_summary})]..." |& tee -a ${log_file}
	all_lines=$(get_assembly_summary "${assembly_summary}")
	filtered_lines=$(filter_assembly_summary "${assembly_summary}")
	echo " - $((all_lines-filtered_lines)) out of ${all_lines} entries removed [RefSeq category: ${refseq_category}, Assembly level: ${assembly_level}]" |& tee -a ${log_file}
	echo " - ${filtered_lines} entries available" |& tee -a ${log_file}
	
	if [ "${just_check}" -eq 1 ]; then
		rm -r ${assembly_summary} ${log_file} ${files}
	else
		ln -s $(readlink -m ${assembly_summary}) "${std_assembly_summary}"
		echo " - Downloading $((filtered_lines*(n_formats+1))) files with ${threads} threads..."	|& tee -a ${log_file}
		download_files "${assembly_summary}" "20" "${file_formats}"
		
		# UPDATED INDICES assembly accession
		if [ "${updated_assembly_accession}" -eq 1 ]; then 
			output_assembly_accession "${assembly_summary}" "1,20" "A" > ${updated_assembly_accession_file}
		fi
		# UPDATED INDICES sequence accession
		if [[ "${file_formats}" =~ "assembly_report.txt" ]] && [ "${updated_sequence_accession}" -eq 1 ]; then
			output_sequence_accession "${assembly_summary}" "1" "A" "${assembly_summary}" > ${updated_sequence_accession_file}
		fi
	fi
	
else # update
	
	# Current assembly summary
	assembly_summary=$(readlink -m ${std_assembly_summary})
	
	# Check for missing files on current version
	echo "Checking for missing files..." |& tee -a ${log_file}
	missing=${output_folder}/missing.txt
	check_missing_files ${assembly_summary} "20" "${file_formats}" > ${missing}
	missing_lines=$(wc -l ${missing} | cut -f1 -d' ')
	if [ "${missing_lines}" -gt 0 ]; then
		echo " - ${missing_lines} missing files on current version [$(basename ${assembly_summary})]" |& tee -a ${log_file}
		if [ "${just_check}" -eq 0 ]; then
			echo " - Downloading ${missing_lines} files with ${threads} threads..."	|& tee -a ${log_file}
			download_files "${missing}" "1"
		fi
	else
		echo " - None" |& tee -a ${log_file}
	fi
	echo ""
	rm ${missing}
	
	echo "Checking for extra files..." |& tee -a ${log_file}
	extra=${output_folder}/extra.txt
	join <(ls -1 ${files} | sort) <(list_files ${assembly_summary} "20" "${file_formats}" | sed -e 's/.*\///' | sort) -v 1 > ${extra}
	extra_lines=$(wc -l ${extra} | cut -f1 -d' ')
	if [ "${extra_lines}" -gt 0 ]; then
		echo " - ${extra_lines} extra files on current folder [${files}]" |& tee -a ${log_file}
		if [ "${just_check}" -eq 0 ]; then
			if [ "${delete_extra_files}" -eq 1 ]; then
				echo " - Deleting ${extra_lines} files..." |& tee -a ${log_file}
				remove_files "${extra}" "1"
			else
				cat ${extra} >> ${log_file} #List file in the log when -x is not enabled
			fi
		fi
	else
		echo " - None" |& tee -a ${log_file}
	fi
	echo ""
	rm ${extra}
	
	if [ "${just_fix}" -eq 0 ]; then
		
		# Check for updates on NCBI
		new_assembly_summary=${output_folder}/${DATE}_assembly_summary.txt
		echo "Downloading assembly summary [$(basename ${new_assembly_summary})]..." |& tee -a ${log_file}
		all_lines=$(get_assembly_summary "${new_assembly_summary}")
		filtered_lines=$(filter_assembly_summary "${new_assembly_summary}")
		echo " - $((all_lines-filtered_lines)) out of ${all_lines} entries removed [RefSeq category: ${refseq_category}, Assembly level: ${assembly_level}]" |& tee -a ${log_file}
		echo " - ${filtered_lines} entries available" |& tee -a ${log_file}
		echo ""
		
		update=${output_folder}/update.txt
		delete=${output_folder}/delete.txt
		new=${output_folder}/new.txt
		# UPDATED (verify if version or date changed)
		join <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); gsub("/","",$15); print $1,acc_ver,$15,$20}' ${new_assembly_summary} | sort -k 1,1) <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); gsub("/","",$15); print $1,acc_ver,$15,$20}' ${assembly_summary} | sort -k 1,1) -o "1.2,1.3,1.4,2.2,2.3,2.4" | awk '{if($2>$5 || $1!=$4){print $1"\t"$3"\t"$4"\t"$6}}' > ${update}
		update_lines=$(wc -l ${update} | cut -f1 -d' ')
		# DELETED
		join <(cut -f 1 ${new_assembly_summary} | sed 's/\.[0-9]*//g' | sort) <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); print $1,acc_ver,$20}' ${assembly_summary} | sort -k 1,1) -v 2 -o "2.2,2.3" | tr ' ' '\t' > ${delete}
		delete_lines=$(wc -l ${delete} | cut -f1 -d' ')
		# NEW
		join <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); print $1,acc_ver,$20}' ${new_assembly_summary} | sort -k 1,1) <(cut -f 1 ${assembly_summary} | sed 's/\.[0-9]*//g' | sort) -o "1.2,1.3" -v 1 | tr ' ' '\t' > ${new}
		new_lines=$(wc -l ${new} | cut -f1 -d' ')
		
		echo "$(basename ${assembly_summary}) --> $(basename ${new_assembly_summary})" |& tee -a ${log_file}
		echo " - ${update_lines} updated, ${delete_lines} deleted, ${new_lines} new entries" |& tee -a ${log_file}

		if [ "${just_check}" -eq 1 ]; then
			rm ${update} ${delete} ${new} ${new_assembly_summary} ${log_file}
		else
			# UPDATED INDICES assembly accession
			if [ "${updated_assembly_accession}" -eq 1 ]; then 
				output_assembly_accession "${update}" "3,4" "R" > ${updated_assembly_accession_file} 
				output_assembly_accession "${delete}" "1,2" "R" >> ${updated_assembly_accession_file}
				output_assembly_accession "${update}" "1,2" "A" >> ${updated_assembly_accession_file}
				output_assembly_accession "${new}" "1,2" "A" >> ${updated_assembly_accession_file}
			fi
			# UPDATED INDICES sequence accession (removed entries - do it before deleting them)
			if [[ "${file_formats}" =~ "assembly_report.txt" ]] && [ "${updated_sequence_accession}" -eq 1 ]; then
				output_sequence_accession "${update}" "3" "R" "${std_assembly_summary}" > ${updated_sequence_accession_file}
				output_sequence_accession "${delete}" "1" "R" "${std_assembly_summary}" >> ${updated_sequence_accession_file}
			fi
			
			# Execute updates
			if [ "${update_lines}" -gt 0 ]; then
				echo " - UPDATE: Deleting $((update_lines*(n_formats+1))) files, Downloading $((update_lines*(n_formats+1))) files with ${threads} threads..."	|& tee -a ${log_file}
				# delete old version
				remove_files "${update}" "4" "${file_formats}"
				# download new version
				download_files "${update}" "2" "${file_formats}"
			fi
			if [ "${delete_lines}" -gt 0 ]; then
				echo " - DELETE: Deleting ${delete_lines} files..." |& tee -a ${log_file}
				remove_files "${delete}" "2" "${file_formats}"
			fi
			if [ "${new_lines}" -gt 0 ]; then
				echo " - NEW: Downloading $((new_lines*(n_formats+1))) files with ${threads} threads..."	|& tee -a ${log_file}
				download_files "${new}" "2" "${file_formats}"
			fi 

			# UPDATED INDICES sequence accession (added entries - do it after downloading them)
			if [[ "${file_formats}" =~ "assembly_report.txt" ]] && [ "${updated_sequence_accession}" -eq 1 ]; then
				output_sequence_accession "${update}" "1" "A" "${new_assembly_summary}" >> ${updated_sequence_accession_file}
				output_sequence_accession "${new}" "1" "A" "${new_assembly_summary}" >> ${updated_sequence_accession_file}
			fi
			
			# Replace STD assembly summary with the new version
			rm ${update} ${delete} ${new} ${std_assembly_summary} 
			ln -s $(readlink -m ${new_assembly_summary}) "${std_assembly_summary}"

		fi
	fi
fi

if [ "${just_check}" -eq 0 ] && [ "${just_fix}" -eq 0 ]; then
	if [ "${download_taxonomy}" -eq 1 ]; then
		echo ""
		echo "Downloading current Taxonomy database [${DATE}_taxdump.tar.gz] ..." |& tee -a ${log_file}
		get_taxonomy "${output_folder}/${DATE}_taxdump.tar.gz"
		echo " - OK"
	fi
	
	final_lines=$(wc -l "${std_assembly_summary}" | cut -f1 -d' ')
	final_files=$(ls ${files} | wc -l | cut -f1 -d' ')
	echo ""
	echo ""
	echo "# Files available on the current version: $((final_lines*(n_formats+1)))"
	echo "# Successfuly downloaded files [${files}]: ${final_files}"
	echo ""
	echo "Done. Current version: ${DATE}" |& tee -a ${log_file}
fi
