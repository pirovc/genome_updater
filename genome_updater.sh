#!/bin/bash

get_assembly_summary() # parameter: assembly_summary file
{
	for d in ${database//,/ }
	do
		for g in ${organism_group//,/ }
		do
			 wget -qO- ftp://ftp.ncbi.nlm.nih.gov/genomes/$d/$g/assembly_summary.txt | tail -n+3 >> ${1}
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
		cut --fields="${2}" ${1} | parallel -j ${threads} 'wget --no-verbose --continue {1} --append-output='"${log_file}"' -P '"${files}"''
	else
		for f in ${3//,/ }
		do
			cut --fields="${2}" ${1} | awk -F "\t" -v ext="${f}" '{url_count=split($1,url,"/"); print $1"/"url[url_count] "_" ext}' | parallel -j ${threads} 'wget --no-verbose --continue {1} --append-output='"${log_file}"' -P '"${files}"''
		done
	fi
}

remove_files() # parameter: ${1} file, ${2} field [url], ${3} extension
{
	for f in ${3//,/ }
	do
		cut --fields="${2}" ${1} | awk -F "\t" -v ext="${f}" '{url_count=split($1,url,"/"); print url[url_count] "_" ext}' | xargs --no-run-if-empty -I{} rm {} -v >> ${log_file} 2>&1
	done
}

check_files() # parameter: ${1} file, ${2} field [url], ${3} extension
{
	# check if file exist and if it's not zero size
	for f in ${3//,/ }
	do
		cut --fields="${2}" ${1} | awk -F "\t" -v ext="${f}" '{url_count=split($1,url,"/"); print $1 " " url[url_count] "_" ext}' | xargs -n2 sh -c 'if [ ! -f "'"${files}"'${1}" ] || [ ! -s "'"${files}"'${1}" ]; then echo "${0}/${1}"; fi'
	done
}

# Defaults
version="0.01"
database="refseq"
organism_group="bacteria"
refseq_category="all"
assembly_level="all"
file_formats="genomic.fna.gz"
output_folder="db"
threads=1

function showhelp {
	echo
	echo " -- Genome Updater - v${version} --"
	echo
	echo $' -d Database [all, genbank, refseq]\n\tDefault: refseq'
	echo $' -g Organism group [archaea, bacteria, fungi, invertebrate, metagenomes (only genbank), other (synthetic genomes - only genbank), plant, protozoa, vertebrate_mammalian, vertebrate_other, viral (only refseq)]\n\tDefault: bacteria'
	echo $' -c RefSeq Category [all, reference genome, representative genome, na]\n\tDefault: all'
	echo $' -l Assembly lebal [all, Complete Genome, Chromosome, Scaffold, Contig]\n\tDefault: all'
	echo $' -f File formats [genomic.fna.gz,assembly_report.txt, ... - check ftp://ftp.ncbi.nlm.nih.gov/genomes/all/README.txt for all file formats]\n\tDefault: genomic.fna.gz'
	echo $' -o Output folder\n\tDefault: db/'
	echo $' -t Threads\n\tDefault: 1'
	echo
}
		
OPTIND=1 # Reset getopts
while getopts "d:g:c:l:o:t:f:h" opt; do
  case $opt in
    d) database=$OPTARG ;;
    g) organism_group=$OPTARG ;;
	c) refseq_category=$OPTARG ;;
	l) assembly_level=$OPTARG ;;
	o) output_folder=$OPTARG ;;
	t) threads=$OPTARG ;;
	f) file_formats=$OPTARG ;;
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
assembly_summary=${output_folder}/assembly_summary.txt
n_formats=`echo ${file_formats} | tr -cd , | wc -c`
log_file=${output_folder}/${DATE}.log

echo "${DATE}" |& tee -a ${log_file}
echo "Database: $database" |& tee -a ${log_file}
echo "Organims group: $organism_group" |& tee -a ${log_file}
echo "RefSeq category: $refseq_category" |& tee -a ${log_file}
echo "Assembly level: $assembly_level" |& tee -a ${log_file}
echo "File formats: $file_formats" |& tee -a ${log_file}
echo "Threads: $threads" |& tee -a ${log_file}
echo "Output folder: $output_folder" |& tee -a ${log_file}
echo "" |& tee -a ${log_file}

# new download
if [ ! -f "${assembly_summary}" ]; then
    echo "Downloading new assembly summary [`readlink -m ${assembly_summary}`]..." |& tee -a ${log_file}
	all_lines=$(get_assembly_summary "${assembly_summary}")
	filtered_lines=$(filter_assembly_summary "${assembly_summary}")
	echo "$((all_lines-filtered_lines)) out of ${all_lines} entries removed [RefSeq category: $refseq_category, Assembly level: $assembly_level]" |& tee -a ${log_file}

	echo "Downloading $((filtered_lines*(n_formats+1))) files with $threads threads..."	|& tee -a ${log_file}
	download_files "${assembly_summary}" "20" "${file_formats}"
	
	mv ${assembly_summary} ${output_folder}/${DATE}_assembly_summary.txt
	
else # update
	
	# Check for missing files on current version
	missing=${output_folder}/missing.txt
	check_files ${assembly_summary} "20" "${file_formats}" > ${missing}
	missing_lines=`wc -l ${missing} | cut -f1 -d' '`
	if [ "$missing_lines" -gt 0 ]; then
		echo "${missing_lines} missing files on current version [`readlink -m ${assembly_summary}`]" |& tee -a ${log_file}
		echo "Downloading ${missing_lines} files with $threads threads..."	|& tee -a ${log_file}
		download_files "${missing}" "1"
	fi

	# Check for updates on NCBI
	new_assembly_summary=${output_folder}/${DATE}_assembly_summary.txt
	echo "Downloading updated assembly summary [`readlink -m ${new_assembly_summary}` --> last: `readlink -m ${assembly_summary}`]..." |& tee -a ${log_file}
	all_lines=$(get_assembly_summary "${new_assembly_summary}")
	filtered_lines=$(filter_assembly_summary "${new_assembly_summary}")
	echo "$((all_lines-filtered_lines)) out of ${all_lines} entries removed [RefSeq category: $refseq_category, Assembly level: $assembly_level]" |& tee -a ${log_file}
	
	updated=${output_folder}/${DATE}_updated.txt
	deleted=${output_folder}/${DATE}_deleted.txt
	new=${output_folder}/${DATE}_new.txt
	
	# UPDATED (verify if version or date changed)
	join <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); gsub("/","",$15); print $1,acc_ver,$15,$20}' ${new_assembly_summary} | sort -k 1,1) <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); gsub("/","",$15); print $1,acc_ver,$15,$20}' ${assembly_summary} | sort -k 1,1) -o "1.2,1.3,1.4,2.2,2.3,2.4" | awk '{if($2>$5 || $1!=$4){print $1"\t"$3"\t"$4"\t"$6}}' > ${updated}
	updated_lines=`wc -l ${updated} | cut -f1 -d' '`
	echo "${updated_lines} updated entries" |& tee -a ${log_file}
	if [ "$updated_lines" -gt 0 ]; then
		# delete
		remove_files "${updated}" "4" "${file_formats}"
		# new
		echo "Downloading $((updated_lines*(n_formats+1))) files with $threads threads..."	|& tee -a ${log_file}
		download_files "${updated}" "2" "${file_formats}"
	fi
	
	# DELETED
	join <(cut -f 1 ${new_assembly_summary} | sed 's/\.[0-9]*//g' | sort) <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); print $1,acc_ver,$20}' ${assembly_summary} | sort -k 1,1) -v 2 -o "2.2,2.3" > ${deleted}
	deleted_lines=`wc -l ${deleted} | cut -f1 -d' '`
	echo "${deleted_lines} deleted entries" |& tee -a ${log_file}
	if [ "$deleted_lines" -gt 0 ]; then
		remove_files "${deleted}" "2" "${file_formats}"
	fi
	
	# NEW
	join <(awk -F '\t' '{acc_ver=$1; gsub("\\.[0-9]*","",$1); print $1,acc_ver,$20}' ${new_assembly_summary} | sort -k 1,1) <(cut -f 1 ${assembly_summary} | sed 's/\.[0-9]*//g' | sort) -o "1.2,1.3" -v 1 | tr ' ' '\t' > ${new}
	new_lines=`wc -l ${new} | cut -f1 -d' '`
	echo "${new_lines} new entries" |& tee -a ${log_file}
	if [ "$new_lines" -gt 0 ]; then
		echo "Downloading $((new_lines*(n_formats+1))) files with $threads threads..."	|& tee -a ${log_file}
		download_files "${new}" "2" "${file_formats}"
	fi
	
	rm ${assembly_summary} ${missing} ${updated} ${deleted} ${new}
fi

ln -s `readlink -m ${output_folder}/${DATE}_assembly_summary.txt` ${assembly_summary}
