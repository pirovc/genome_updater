#!/usr/bin/env bash

entries=20
outfld="files/"
mkdir -p ${outfld}
ext="assembly_report.txt" #,protein.faa.gz"
db="refseq,genbank"
og="archaea,fungi"

og="default,${og}"
for d in ${db//,/ }
do
    for o in ${og//,/ }
    do      
        if [[ ${o} == "default" ]]; then
            mkdir -p "${outfld}genomes/${d}/"
            wget --quiet --show-progress -O "full_assembly_summary.txt" "ftp://ftp.ncbi.nlm.nih.gov/genomes/${d}/assembly_summary_${d}.txt"
            out_as="${outfld}genomes/${d}/assembly_summary_$d.txt"
        else
            mkdir -p "${outfld}genomes/${d}/${o}/"
            wget --quiet --show-progress -O "full_assembly_summary.txt" "ftp://ftp.ncbi.nlm.nih.gov/genomes/${d}/${o}/assembly_summary.txt"
            out_as="${outfld}genomes/${d}/${o}/assembly_summary.txt"
        fi
        head -n 2 "full_assembly_summary.txt" > "${out_as}"
        tail -n+3 "full_assembly_summary.txt" | shuf | head -n ${entries} >> "${out_as}"
        # create a dummy historical for gtdb tests (just a copy)
        cp "${out_as}" "${out_as%.*}_historical.txt"
        # Download files
        tail -n+3 "${out_as}" | cut -f 20 | sed 's/https:/ftp:/g' | xargs -P ${entries} wget --quiet --show-progress --directory-prefix="${outfld}" --recursive --level 2 --accept "${ext}"
        cp -r "${outfld}ftp.ncbi.nlm.nih.gov/genomes/" "${outfld}"
        rm -rf "full_assembly_summary.txt" "${outfld}ftp.ncbi.nlm.nih.gov/" 
    done
done

# Download and filter taxonomies for used accessions/taxids

# Get used accessions and taxids
cut -f 1,6 ${outfld}genomes/*/assembly_summary_*.txt ${outfld}genomes/*/*/assembly_summary.txt | grep -v "^#" | sort | uniq > ${outfld}accessions_taxids.txt
# ncbi new_taxdump
wget --quiet --show-progress --output-document "${outfld}new_taxdump.tar.gz" "https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/new_taxdump/new_taxdump.tar.gz"
tar xf "${outfld}new_taxdump.tar.gz" -C "${outfld}" taxidlineage.dmp rankedlineage.dmp
mkdir -p "${outfld}pub/taxonomy/new_taxdump/"
cat "${outfld}accessions_taxids.txt" | xargs -l bash -c 'grep "^${1}[^0-9]" "'${outfld}'taxidlineage.dmp"' > "${outfld}pub/taxonomy/new_taxdump/taxidlineage.dmp"
cat "${outfld}accessions_taxids.txt" | xargs -l bash -c 'grep "[^0-9]${1}[^0-9]" "'${outfld}'taxidlineage.dmp"' >> "${outfld}pub/taxonomy/new_taxdump/taxidlineage.dmp"
cat "${outfld}accessions_taxids.txt" | xargs -l bash -c 'grep "^${1}[^0-9]" "'${outfld}'rankedlineage.dmp"' > "${outfld}pub/taxonomy/new_taxdump/rankedlineage.dmp"

find "${outfld}pub/taxonomy/new_taxdump/" -printf "%P\n" | tar -czf "${outfld}pub/taxonomy/new_taxdump/new_taxdump.tar.gz" --no-recursion -C "${outfld}pub/taxonomy/new_taxdump/" -T -
md5sum "${outfld}pub/taxonomy/new_taxdump/new_taxdump.tar.gz" > "${outfld}pub/taxonomy/new_taxdump/new_taxdump.tar.gz.md5"
rm "${outfld}new_taxdump.tar.gz" "${outfld}taxidlineage.dmp" "${outfld}rankedlineage.dmp" "${outfld}pub/taxonomy/new_taxdump/taxidlineage.dmp" "${outfld}pub/taxonomy/new_taxdump/rankedlineage.dmp"

#gtdb
gtdb_out="${outfld}releases/release207/207.0/"
mkdir -p "${gtdb_out}"
gtdb_tax=( "ar53_taxonomy_r207.tsv.gz" "bac120_taxonomy_r207.tsv.gz" )
for tax in "${gtdb_tax[@]}"; do
    wget --quiet --show-progress --output-document "${outfld}${tax}" "https://data.gtdb.ecogenomic.org/releases/release207/207.0/${tax}"
    join -1 1 -2 1 <(cut -f 1 "${outfld}accessions_taxids.txt" | sort) <(zcat "${outfld}${tax}" | awk 'BEGIN{FS=OFS="\t"}{print $1,$1,$2}' | sed -r 's/^.{3}//' | sort) -t$'\t' -o "2.2,2.3" | gzip > "${gtdb_out}${tax}"
    rm "${outfld}${tax}"
done

md5sum ${gtdb_out}*.tsv.gz > "${gtdb_out}MD5SUM"
rm ${outfld}accessions_taxids.txt
