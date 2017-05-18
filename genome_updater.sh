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

get_assembly_summary() # parameter: assembly_summary file
{
	for d in ${database//,/ }
	do
		for g in ${organism_group//,/ }
		do
			 wget --tries="${wget_tries}" --read-timeout="${wget_timeout}" -qO- ftp://ftp.ncbi.nlm.nih.gov/genomes/$d/$g/assembly_summary.txt | tail -n+3 >> ${1}
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

download_files() # parameter: ${1} file, ${2} field [url], ${3} extension
{
	if [ -z "${3}" ] #direct download (full url)
	then
		cut --fields="${2}" ${1} | parallel -j ${threads} 'wget --no-verbose --continue {1} --tries='"${wget_tries}"' --read-timeout='"${wget_timeout}"' --append-output='"${log_file}"' -P '"${files}"''
	else
		for f in ${3//,/ }
		do
			cut --fields="${2}" ${1} | awk -F "\t" -v ext="${f}" '{url_count=split($1,url,"/"); print $1"/"url[url_count] "_" ext}' | parallel -j ${threads} 'wget --no-verbose --continue --tries='"${wget_tries}"' --read-timeout='"${wget_timeout}"' {1} --append-output='"${log_file}"' -P '"${files}"''
		done
	fi
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
		cut --fields="${2}" ${1} | awk -F "\t" -v ext="${f}" '{url_count=split($1,url,"/"); print $1 " " url[url_count] "_" ext}' | xargs --no-run-if-empty -n2 sh -c 'if [ ! -f "'"${files}"'${1}" ] || [ ! -s "'"${files}"'${1}" ]; then echo "${0}/${1}"; fi'
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

# Defaults
version="0.03"
database="refseq"
organism_group="bacteria"
refseq_category="all"
assembly_level="all"
file_formats="genomic.fna.gz"
delete_extra_files=0
output_updated_indices=0
just_check=0
output_folder="db"
threads=1

function showhelp {
	echo "Genome Updater v${version} by Vitor C. Piro (vitorpiro@gmail.com, http://github.com/pirovc)"
	echo
	echo $' -d Database [all, genbank, refseq]\n\tDefault: refseq'
	echo $' -g Organism group [archaea, bacteria, fungi, invertebrate, metagenomes (only genbank), other (synthetic genomes - only genbank), plant, protozoa, vertebrate_mammalian, vertebrate_other, viral (only refseq)]\n\tDefault: bacteria'
	echo $' -c RefSeq Category [all, reference genome, representative genome, na]\n\tDefault: all'
	echo $' -l Assembly level [all, Complete Genome, Chromosome, Scaffold, Contig]\n\tDefault: all'
	echo $' -f File formats [genomic.fna.gz,assembly_report.txt, ... - check ftp://ftp.ncbi.nlm.nih.gov/genomes/all/README.txt for all file formats]\n\tDefault: genomic.fna.gz'
	echo $' -k Just check for updates, keep current version'
	echo $' -x Delete any extra files inside the folder'
	echo $' -u Output list of updated indices (added/removed)'
	echo $' -o Output folder\n\tDefault: db/'
	echo $' -t Threads\n\tDefault: 1'
	echo
}
		
OPTIND=1 # Reset getopts
while getopts "d:g:c:l:o:t:f:kxuh" opt; do
  case $opt in
    d) database=$OPTARG ;;
    g) organism_group=$OPTARG ;;
	c) refseq_category=$OPTARG ;;
	l) assembly_level=$OPTARG ;;
	o) output_folder=$OPTARG ;;
	t) threads=$OPTARG ;;
	f) file_formats=$OPTARG ;;
	k) just_check=1 ;;
	x) delete_extra_files=1 ;;
	u) output_updated_indices=1 ;;
    h|\?) showhelp; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
  esac
done
if [ $OPTIND -eq 1 ]; then showhelp; exit 1; fi
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

if [ ${database} == "all" ]; then database="genbank,refseq"; fi
DATE=`date +%Y-%m-%d_%H-%M-%S`
mkdir -p ${output_folder}
mkdir -p ${output_folder}/files/
files=${output_folder}/files/
std_assembly_summary=${output_folder}/assembly_summary.txt
n_formats=`echo ${file_formats} | tr -cd , | wc -c`
log_file=${output_folder}/${DATE}.log

echo "GenomeUpdater version: ${version}" |& tee -a ${log_file}
echo "Database: $database" |& tee -a ${log_file}
echo "Organims group: $organism_group" |& tee -a ${log_file}
echo "RefSeq category: $refseq_category" |& tee -a ${log_file}
echo "Assembly level: $assembly_level" |& tee -a ${log_file}
echo "File formats: $file_formats" |& tee -a ${log_file}
echo "Just check for updates: $just_check" |& tee -a ${log_file}
echo "Delete extra files: $delete_extra_files" |& tee -a ${log_file}
echo "Output updated indices: $output_updated_indices" |& tee -a ${log_file}
echo "Threads: $threads" |& tee -a ${log_file}
echo "Output folder: $output_folder" |& tee -a ${log_file}
echo "Output files: $files" |& tee -a ${log_file}
echo "" |& tee -a ${log_file}

# new download
if [ ! -f "${std_assembly_summary}" ]; then
	if [ "$just_check" -eq 1 ]; then
		echo "-- CHECK --" |& tee -a ${log_file}
	else
		echo "-- NEW --" |& tee -a ${log_file}
	fi
	
	assembly_summary=${output_folder}/${DATE}_assembly_summary.txt
    echo "Downloading assembly summary [`basename ${assembly_summary}`]..." |& tee -a ${log_file}
	all_lines=$(get_assembly_summary "${assembly_summary}")
	filtered_lines=$(filter_assembly_summary "${assembly_summary}")
	echo " - $((all_lines-filtered_lines)) out of ${all_lines} entries removed [RefSeq category: $refseq_category, Assembly level: $assembly_level]" |& tee -a ${log_file}
	echo " - ${filtered_lines} entries available" |& tee -a ${log_file}
	
	if [ "$just_check" -eq 1 ]; then
		rm -r ${assembly_summary} ${log_file} ${files}
	else
		ln -s `readlink -m ${assembly_summary}` "${std_assembly_summary}"
		echo " - Downloading $((filtered_lines*(n_formats+1))) files with $threads threads..."	|& tee -a ${log_file}
		download_files "${assembly_summary}" "20" "${file_formats}"
	fi
	
else # update

	if [ "$just_check" -eq 1 ]; then
		echo "-- CHECK --" |& tee -a ${log_file}
	else
		echo "-- UPDATE --" |& tee -a ${log_file}
	fi
	
	# Current assembly summary
	assembly_summary=`readlink -m ${std_assembly_summary}`
	
	# Check for missing files on current version
	echo "Checking for missing files..." |& tee -a ${log_file}
	missing=${output_folder}/missing.txt
	check_missing_files ${assembly_summary} "20" "${file_formats}" > ${missing}
	missing_lines=`wc -l ${missing} | cut -f1 -d' '`
	if [ "$missing_lines" -gt 0 ]; then
		echo " - ${missing_lines} missing files on current version [`basename ${assembly_summary}`]" |& tee -a ${log_file}
		if [ "$just_check" -eq 0 ]; then
			echo " - Downloading ${missing_lines} files with $threads threads..."	|& tee -a ${log_file}
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
	extra_lines=`wc -l ${extra} | cut -f1 -d' '`
	if [ "$extra_lines" -gt 0 ]; then
		echo " - ${extra_lines} extra files on current folder [${files}]" |& tee -a ${log_file}
		if [ "$just_check" -eq 0 ]; then
			if [ "$delete_extra_files" -eq 1 ]; then
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
	
	# Check for updates on NCBI
	new_assembly_summary=${output_folder}/${DATE}_assembly_summary.txt
	echo "Downloading assembly summary [`basename ${new_assembly_summary}`]..." |& tee -a ${log_file}
	all_lines=$(get_assembly_summary "${new_assembly_summary}")
	filtered_lines=$(filter_assembly_summary "${new_assembly_summary}")
	echo " - $((all_lines-filtered_lines)) out of ${all_lines} entries removed [RefSeq category: $refseq_category, Assembly level: $assembly_level]" |& tee -a ${log_file}
	echo " - ${filtered_lines} entries available" |& tee -a ${log_file}
	echo ""
	
	update=${output_folder}/${DATE}_update.txt
	delete=${output_folder}/${DATE}_delete.txt
	new=${output_folder}/${DATE}_new.txt
	# UPDATED (verify if version or date changed)
	join <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); gsub("/","",$15); print $1,acc_ver,$15,$20}' ${new_assembly_summary} | sort -k 1,1) <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); gsub("/","",$15); print $1,acc_ver,$15,$20}' ${assembly_summary} | sort -k 1,1) -o "1.2,1.3,1.4,2.2,2.3,2.4" | awk '{if($2>$5 || $1!=$4){print $1"\t"$3"\t"$4"\t"$6}}' > ${update}
	update_lines=`wc -l ${update} | cut -f1 -d' '`
	# DELETED
	join <(cut -f 1 ${new_assembly_summary} | sed 's/\.[0-9]*//g' | sort) <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); print $1,acc_ver,$20}' ${assembly_summary} | sort -k 1,1) -v 2 -o "2.2,2.3" | tr ' ' '\t' > ${delete}
	delete_lines=`wc -l ${delete} | cut -f1 -d' '`
	# NEW
	join <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); print $1,acc_ver,$20}' ${new_assembly_summary} | sort -k 1,1) <(cut -f 1 ${assembly_summary} | sed 's/\.[0-9]*//g' | sort) -o "1.2,1.3" -v 1 | tr ' ' '\t' > ${new}
	new_lines=`wc -l ${new} | cut -f1 -d' '`
	
	echo "`basename ${assembly_summary}` --> `basename ${new_assembly_summary}`" |& tee -a ${log_file}
	echo " - ${update_lines} updated, ${delete_lines} deleted, ${new_lines} new entries" |& tee -a ${log_file}

	if [ "$just_check" -eq 1 ]; then
		rm ${update} ${delete} ${new} ${new_assembly_summary} ${log_file}
	else
		if [ "$update_lines" -gt 0 ]; then
			echo " - UPDATE: Deleting $((update_lines*(n_formats+1))) files, Downloading $((update_lines*(n_formats+1))) files with $threads threads..."	|& tee -a ${log_file}
			# delete old version
			remove_files "${update}" "4" "${file_formats}"
			# download new version
			download_files "${update}" "2" "${file_formats}"
		fi
		if [ "$delete_lines" -gt 0 ]; then
			echo " - DELETE: Deleting ${delete_lines} files..." |& tee -a ${log_file}
			remove_files "${delete}" "2" "${file_formats}"
		fi
		if [ "$new_lines" -gt 0 ]; then
			echo " - NEW: Downloading $((new_lines*(n_formats+1))) files with $threads threads..."	|& tee -a ${log_file}
			download_files "${new}" "2" "${file_formats}"
		fi 
		
		# UPDATED INDICES (added/removed)
		if [ "$output_updated_indices" -eq 1 ]; then 
			cut -f 1 ${update} > ${output_folder}/${DATE}_added.txt
			cut -f 1 ${new} >> ${output_folder}/${DATE}_added.txt
			cut -f 3 ${update} > ${output_folder}/${DATE}_removed.txt
			cut -f 1 ${delete} >> ${output_folder}/${DATE}_removed.txt
		fi
		
		# Replace STD assembly summary with the new version
		rm ${update} ${delete} ${new} ${std_assembly_summary} 
		ln -s `readlink -m ${new_assembly_summary}` "${std_assembly_summary}"

	fi
fi

if [ "$just_check" -eq 0 ]; then
	echo ""
	echo "Done. Current version: ${DATE}" |& tee -a ${log_file}
fi
