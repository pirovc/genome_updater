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
        tail -n+3 "${out_as}" | cut -f 20 | sed 's/https:/ftp:/g' | xargs -P ${entries} wget --quiet --show-progress --directory-prefix="${outfld}" --recursive --level 2 --accept "${ext}"
        cp -r "${outfld}ftp.ncbi.nlm.nih.gov/genomes/" "${outfld}"
        rm -rf "full_assembly_summary.txt" "${outfld}ftp.ncbi.nlm.nih.gov/" 
    done
done

