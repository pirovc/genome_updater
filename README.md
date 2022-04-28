# genome_updater

Bash script to download and update snapshots of the NCBI genomes repository (refseq/genbank) [1] with several filters, detailed logs, reports, file integrity check (MD5) and parallel [2] download support.

## Quick usage guide

### Get genome_updater

	wget https://raw.githubusercontent.com/pirovc/genome_updater/master/genome_updater.sh
	chmod +x genome_updater.sh

### Download

Download complete genome Archaea sequences in the RefSeq repository (`-t` number parallel downloads):

	./genome_updater.sh -o "arc_refseq_cg" -d "refseq" -g "archaea" -l "complete genome" -f "genomic.fna.gz" -t 12

### Update

Some days later, update the repository:

	./genome_updater.sh -o "arc_refseq_cg"

 - Add `-k` to perform a dry-run before the actual run. genome_updater will show how many files will be downloaded/updated and exit without changes

 - Parameters can be changed for each update by just calling the command with the desired values. For example `./genome_updater.sh -o "arc_refseq_cg" -t 2` to use a different number of threads or `./genome_updater.sh -o "arc_refseq_cg" -l ""` to remove the "complete genome" filter.

 - `history.tsv` will be created in the output folder, tracking versions and arguments used (boolean arguments are not tracked).

## Details

- with genome_updater you can download and keep several snapshots of a certain sub-set of the genomes repository, without redundancy and with incremental track of changes
- genome_updater runs on a working directory (defined with `-o`) and creates a snapshot (`-b`) of refseq and/or genbank (`-d`) genome repositories based on selected organism groups (`-g`) and/or taxonomic ids (`-S`/`-T`) with the desired files type(s) (`-f`)
- filters can be applied to refine the selection: RefSeq category (`-c`), assembly level (`-l`), dates (`-D`/`-E`), custom filters (`-F`), top assemblies (`-P`/`-A`), GTDB [3] compatible sequences (`-z`).
- the repository can updated (e.g. after some days) with only incremental changes. genome_updater will identify previous files and update the working directory with the most recent versions, keeping track of all changes and just downloading/removing what is necessary


## Installation

[![install with bioconda](https://img.shields.io/badge/install%20with-bioconda-brightgreen.svg?style=flat)](http://bioconda.github.io/recipes/genome_updater/README.html)

With conda:

	conda install -c bioconda genome_updater 

or direct file download:

	wget https://raw.githubusercontent.com/pirovc/genome_updater/master/genome_updater.sh
	chmod +x genome_updater.sh

 - genome_updater is portable and depends on the GNU Core Utilities + few additional tools (`awk` `bc` `find` `join` `md5sum` `parallel` `sed` `tar` `xargs` `wget`/`curl`) which are commonly available and installed in most distributions. If you are not sure if you have them all, just run `genome_updater.sh` and it will tell you if something is missing (otherwise the it will show the help page).

To test if all genome_updater functions are running properly on your system:

	git clone --recurse-submodules https://github.com/pirovc/genome_updater.git
	cd genome_updater
	tests/test.sh


## Options

Data selection:
- `-d`: database selection (genbank and/or refseq)
- `-g`: organism groups (`-g "archaea,bacteria"`)
- `-S`: species taxids (`-S "562,623"`)
- `-T`: any taxids including all children nodes (`-T "620,1643685"`)
- `-f`: files to be downloaded [genomic.fna.gz,assembly_report.txt, ... - check ftp://ftp.ncbi.nlm.nih.gov/genomes/all/README.txt for all file formats]
- `-l`: filter by Assembly level [complete genome, chromosome, scaffold, contig]
- `-c`: filter by RefSeq Category [reference genome, representative genome, na]
- `-P`: select [top assemblies](#top-assemblies) for species entries. `-P 3` downloads the top 3 assemblies for each species
- `-A`: select [top assemblies](#top-assemblies) for taxids entries. `-A 3` downloads the top 3 assemblies for each taxid selected
- `-D`: filter entries published on or after this date
- `-E`: filter entries published on or before this date
- `-z`: select only assemblies included in the latest GTDB release

Utilities:
- `-i`: fixes current snapshot in case of network or any other failure during download
- `-k`: dry-run - do not perform any action but shows number of files to be downloaded or updated
- `-t`: downloads in parallel
- `-m`: checks for file integrity (MD5)
- `-e`: re-downloads entries from any "assembly_summary.txt" obtained from external sources. Easy way to share snapshots of exact database version used.
- `-a`: downloads the current version of the NCBI taxonomy database (taxdump.tar.gz)

Reports:
- `-u`: Added/Removed assembly accessions
- `-r`: Added/Removed sequence accessions 
- `-p`: Output list of URLs for downloaded and failed files

Version control:
- `-b`: name a version under a label (timestamp by default)
- `-B`: when updating, use a different label as a base version. Useful for rolling back updates or to branch out of a base version.

## Examples

### Downloading genomic sequences (.fna files) for the Complete Genome sequences from RefSeq for Bacteria and Archaea and keep them updated

	# Download (checking md5, 12 threads, with extended assembly accession report)
	./genome_updater.sh -d "refseq" -g "archaea,bacteria" -l "Complete Genome" -f "genomic.fna.gz" -o "arc_bac_refseq_cg" -t 12 -u -m
	
	# Downloading additional .gbff files for the current snapshot (adding genomic.gbff.gz to -f and adding -i command)
	./genome_updater.sh -d "refseq" -g "archaea,bacteria" -l "Complete Genome" -f "genomic.fna.gz,genomic.gbff.gz" -o "arc_bac_refseq_cg" -t 12 -u -m -i
	
	# Some days later, just check for updates but do not update
	./genome_updater.sh -d "refseq" -g "archaea,bacteria" -l "Complete Genome" -f "genomic.fna.gz,genomic.gbff.gz" -o "arc_bac_refseq_cg" -k

	# Perform update
	./genome_updater.sh -d "refseq" -g "archaea,bacteria" -l "Complete Genome" -f "genomic.fna.gz,genomic.gbff.gz" -o "arc_bac_refseq_cg" -t 12 -u -m

### Download all RNA Viruses (under the taxon Riboviria) on RefSeq

	./genome_updater.sh -d "refseq" -T "2559587" -f "genomic.fna.gz" -o "all_rna_virus" -t 12

### Download all genome sequences used in the latests GTDB release

	./genome_updater.sh -d "refseq,genbank" -f "genomic.fna.gz" -o "GTDB" -z -t 12

### Branching base version for specific filters

	# Download the complete bacterial refseq
	./genome_updater.sh -d "refseq" -g "bacteria" -f "genomic.fna.gz" -o "bac_refseq" -t 12 -m -b "all"

	# Branch the main files into two sub-versions (no new files will be downloaded or copied)
	./genome_updater.sh -d "refseq" -g "bacteria" -f "genomic.fna.gz" -o "bac_refseq" -t 12 -m -B "all" -b "complete" -l "complete genome"
	./genome_updater.sh -d "refseq" -g "bacteria" -f "genomic.fna.gz" -o "bac_refseq" -t 12 -m -B "all" -b "representative" -c "representative genome"

### Download one genome assembly for each bacterial species in genbank

	./genome_updater.sh -d "genbank" -g "bacteria" -f "genomic.fna.gz" -o "top1_bacteria_genbank" -t 12 -P 1

### Download all E. Coli assemblies available on GenBank and RefSeq under a label (v1)

	./genome_updater.sh -d "genbank,refseq" -S "562" -f "genomic.fna.gz" -o "all_ecoli" -t 12 -b v1

### Check amount of reference entries available for the set of Viral genomes on genbank

	./genome_updater.sh -d "genbank" -g "viral" -k

### Download Fungi RefSeq assembly information and generate sequence reports and URLs

	./genome_updater.sh -d "refseq" -g "fungi" -f "assembly_report.txt" -o "fungi" -t 12 -r -p

### Recovering fasta files from a previously obtained assembly_summary.txt

	./genome_updater.sh -e /my/path/assembly_summary.txt -f "genomic.fna.gz" -o "recovered_sequences" -b "january_2018"

### Use curl, change timeout and retries for download (default wget)

	retries=10 timeout=600 use_curl=1 ./genome_updater.sh -g "fungi" -o fungi -t 12 -f "genomic.fna.gz,assembly_report.txt"

## Top assemblies

The top assemblies (`-P`/`-A`) will be selected based on the species/taxid entries in the assembly_summary.txt and not for the taxids provided with  (`-S`/`-T`). They are selected sorted by categories in the following order of importance:
	
	A) RefSeq Category: 
		1) reference genome
		2) representative genome
		3) na
	B) Assembly level:
		1) Complete genome
		2) Chromosome
		3) Scaffold
		4) Contig
	C) Relation to type material:
		1) assembly from type material
		2) assembly from synonym type material
		3) assembly from pathotype material
		4) assembly designated as neotype
		5) assembly designated as reftype
		6) ICTV species exemplar
		7) ICTV additional isolate
	D) Date:
		1) Most recent first

## Extended reports

### assembly accessions

The parameter `-u` activates the output of a list of updated assembly accessions for the entries with all files (`-f`) successfully downloaded. The file `updated_assembly_accession.txt` has the following fields (tab separated):

	Added [A] or Removed [R], assembly accession, url

Example:

	A	GCF_000146045.2	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/146/045/GCF_000146045.2_R64
	A	GCF_000002515.2	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/002/515/GCF_000002515.2_ASM251v1
	R	GCF_000091025.4	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/091/025/GCF_000091025.4_ASM9102v4

### sequence accessions

The parameter `-r` activates the output of a list of updated sequence accessions for the entries with all files (`-f`) successfully downloaded. It is only available when `assembly_report.txt` is one of the file types. The file `updated_sequence_accession.txt` has the following fields (tab separated):

	Added [A] or Removed [R], assembly accession, genbank accession, refseq accession, sequence length, taxonomic id

Example:

	A	GCA_000243255.1	CM001436.1	NZ_CM001436.1	3200946	937775
	R	GCA_000275865.1	CM001555.1	NZ_CM001555.1	2475100	28892

* genome_updater fixes the current version of the database before updating (or just fix with `-i`). In this step if some entry is fixed and the reports are active, all lines are going to be reported as Added.

### URLs (and files)

The parameter `-p` activates the output of a list of failed and successfully downloaded urls to the files `{timestamp}_url_downloaded.txt` and `{timestamp}_url_failed.txt` (failed list will only be complete if command runs until the end, without errors or breaks).

To obtain a list of successfully downloaded files from this report (useful to get only new files after updating):

	sed 's#.*/##' {timestamp}_url_list_downloaded.txt
	
or

	find output_folder/version/files/ -type f

## Parameters

	┌─┐┌─┐┌┐┌┌─┐┌┬┐┌─┐    ┬ ┬┌─┐┌┬┐┌─┐┌┬┐┌─┐┬─┐
	│ ┬├┤ ││││ ││││├┤     │ │├─┘ ││├─┤ │ ├┤ ├┬┘
	└─┘└─┘┘└┘└─┘┴ ┴└─┘────└─┘┴  ─┴┘┴ ┴ ┴ └─┘┴└─
	                                     v0.4.1 

	Database options:
	 -d Database (comma-separated entries) [genbank, refseq]

	Organism options:
	 -g Organism group (comma-separated entries) [archaea, bacteria, fungi, human, invertebrate, metagenomes, other, plant, protozoa, vertebrate_mammalian, vertebrate_other, viral]. Example: archaea,bacteria.
		Default: ""
	 -S Species level taxonomic ids (comma-separated entries). Example: 622,562
		Default: ""
	 -T Any taxonomic ids - children lineage will be generated (comma-separated entries). Example: 620,649776
		Default: ""

	File options:
	 -f files to download [genomic.fna.gz,assembly_report.txt, ...] check ftp://ftp.ncbi.nlm.nih.gov/genomes/all/README.txt for all file formats
		Default: assembly_report.txt

	Filter options:
	 -c refseq category (comma-separated entries, empty for all) [reference genome, representative genome, na]
		Default: ""
	 -l assembly level (comma-separated entries, empty for all) [complete genome, chromosome, scaffold, contig]
		Default: ""
	 -P Number of top references for each species nodes to download. 0 for all. Selection order: RefSeq Category, Assembly level, Relation to type material, Date (most recent first)
		Default: 0
	 -A Number of top references for each taxids (leaf nodes) to download. 0 for all. Selection order: RefSeq Category, Assembly level, Relation to type material, Date (most recent first)
		Default: 0
	 -F custom filter for the assembly summary in the format colA:val1|colB:valX,valY (case insensitive). Example: -F "2:PRJNA12377,PRJNA670754|14:Partial" for column infos check ftp://ftp.ncbi.nlm.nih.gov/genomes/README_assembly_summary.txt
		Default: ""
	 -D Start date to keep sequences (>=), based on the sequence release date. Format YYYYMMDD. Example: 20201030
		Default: ""
	 -E End date to keep sequences (<=), based on the sequence release date. Format YYYYMMDD. Example: 20201231
		Default: ""
	 -z Keep only assemblies present on the latest GTDB release

	Report options:
	 -u Report of updated assembly accessions (Added/Removed, assembly accession, url)
	 -r Report of updated sequence accessions (Added/Removed, assembly accession, genbank accession, refseq accession, sequence length, taxid). Only available when file format assembly_report.txt is selected and successfully downloaded
	 -p Output list of URLs for downloaded and failed files

	Run options:
	 -o Output/Working directory 
		Default: ./tmp.XXXXXXXXXX
	 -b Version label
		Default: current timestamp (YYYY-MM-DD_HH-MM-SS)
	 -e External "assembly_summary.txt" file to recover data from. Mutually exclusive with -d / -g 
		Default: ""
	 -R Number of attempts to retry to download files in batches 
		Default: 3
	 -B Base label to use as the current version. Can be used to rollback to an older version or to create multiple branches from a base version. It only applies for updates. 
		Default: ""
	 -k Dry-run, no data is downloaded or updated - just checks for available sequences and changes
	 -i Fix failed downloads or any incomplete data from a previous run, keep current version
	 -m Check MD5 of downloaded files
	 -t Threads to parallelize download and some file operations
		Default: 1

	Misc. options:
	 -x Allow the deletion of regular extra files if any found in the files folder. Symbolic links that do not belong to the current version will always be deleted.
	 -a Download the current version of the NCBI taxonomy database (taxdump.tar.gz)
	 -s Silent output
	 -w Silent output with download progress (%) and download version at the end
	 -n Conditional exit status. Exit Code = 1 if more than N files failed to download (integer for file number, float for percentage, 0 -> off)
		Default: 0
	 -V Verbose log to report successful file downloads
	 -Z Print debug information and run in debug mode


## References:

[1] ftp://ftp.ncbi.nlm.nih.gov/genomes/

[2] O. Tange (2018): GNU Parallel 2018, March 2018, https://doi.org/10.5281/zenodo.1146014.

[3] https://gtdb.ecogenomic.org/
