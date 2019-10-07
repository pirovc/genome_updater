# genome_updater

[![install with bioconda](https://img.shields.io/badge/install%20with-bioconda-brightgreen.svg?style=flat)](http://bioconda.github.io/recipes/genome_updater/README.html)

Bash script to download and update snapshots of the NCBI genomes (refseq/genbank) [1] keeping all files and detailed log for each update, with file integrity check (MD5) and parallel [2] download support.

## Description:

- genome_updater runs on a working directory (**-o**) and creates snapshots/versions (**-b**) of refseq/genbank repositories based on selected parameters (database (**-d**), organism group or species/taxids (**-g**), RefSeq category (**-c**), assembly level (**-l**) and file type(s) (**-f**))
- it can update the selected repository by executing the same command again. genome_updater will identify previous files and update the working directory with the most recente version, keeping track of changes and just downloading/removing updated files

## Installation:

	conda install -c bioconda genome_updater 

or

	git clone https://github.com/pirovc/genome_updater.git

or

	wget https://raw.githubusercontent.com/pirovc/genome_updater/master/genome_updater.sh

 - genome_updater depends mainly on the GNU Core Utilities and some additional tools (`parallel`, `wget`, `awk`, `sed`, ...) which are commonly available in most distributions
 - To test genome_updater basic functions, run the script `tests/tests.sh`. It should print "All tests finished successfully" at the end.
 - Make sure you have access to the NCBI ftp folders: `ftp://ftp.ncbi.nlm.nih.gov/genomes/` and `ftp://ftp.ncbi.nih.gov/pub/taxonomy/`

## Simple example:

Downloading Archaeal complete genome sequences from RefSeq:

	./genome_updater.sh -g "archaea" -d "refseq" -l "Complete Genome" -f "genomic.fna.gz" -o "arc_refseq_cg" -t 12 -m

The same command executed again (some days later), will create a second snapshot of the requested dataset, checking for new, updated and removed sequences.

## Main functionalities:

Data selection:
- **-g**: selection of sequences by organism groups (**-g "archaea,bacteria"**) or species (**-g "species:562,623"**) or taxonomic id including all children nodes (**-g "taxids:620,1643685"**)
- **-d**: database selection (genbank and/or refeseq)
- **-f**: suffix of files to be downloaded for each entry [genomic.fna.gz,assembly_report.txt, ... - check ftp://ftp.ncbi.nlm.nih.gov/genomes/all/README.txt for all file formats]
- **-l**: filter by Assembly level [Complete Genome, Chromosome, Scaffold, Contig]

Utilities:
- **-i**: fixes current snapshot in case of network or any other failure during download
- **-k**: dry-run - do not perform any download or update, but shows number of files to be downloaded or updated
- **-t**: run many parallel downloads
- **-m**: checks for file integrity (MD5) with the option
- **-e**: re-downloads entries from any "assembly_summary.txt" obtained from external sources. Easy way to share snapshots of exact database version used.
- **-a**: downloads the current taxdump, matching downloaded files

Reports:
- **-u**: Added/Removed assembly accessions
- **-r**: Added/Removed sequence accessions 
- **-p**: Output list of URLs for downloaded and failed files

## Examples:

### Downloading genomic sequences (.fna files) for the Complete Genome sequences from RefSeq for Bacteria and Archaea and keep them updated

	# Download (checking md5, 12 threads, with extended assembly accession report)
	./genome_updater.sh -d "refseq" -g "archaea,bacteria" -c "all" -l "Complete Genome" -f "genomic.fna.gz" -o "arc_bac_refseq_cg" -t 12 -u -m
	
	# Downloading additional .gbff files for the current snaptshow (adding genomic.gbff.gz to -f and adding -i command)
	./genome_updater.sh -d "refseq" -g "archaea,bacteria" -c "all" -l "Complete Genome" -f "genomic.fna.gz,genomic.gbff.gz" -o "arc_bac_refseq_cg" -t 12 -u -m -i
	
	# Some days later, just check for updates but do not update
	./genome_updater.sh -d "refseq" -g "archaea,bacteria" -c "all" -l "Complete Genome" -f "genomic.fna.gz,genomic.gbff.gz" -o "arc_bac_refseq_cg" -k

	# Perform update
	./genome_updater.sh -d "refseq" -g "archaea,bacteria" -c "all" -l "Complete Genome" -f "genomic.fna.gz,genomic.gbff.gz" -o "arc_bac_refseq_cg" -t 12 -u -m

### Download all RNA Viruses (under the taxon Riboviria) on RefSeq

	./genome_updater.sh -d "refseq" -g "taxids:2559587" -f "genomic.fna.gz" -o "all_rna_virus" -t 12

### Download all E. Coli assemblies available on GenBank and RefSeq with a named label (v1)

	./genome_updater.sh -d "genbank,refseq" -g "species:562" -f "genomic.fna.gz" -o "all_ecoli" -t 12 -b v1

### Check amount of refence entries available for the set of Viral genomes on genbank

	./genome_updater.sh -d "genbank" -g "viral" -c "all" -l "all" -k

### Download Fungi RefSeq assembly information and generate sequence reports and urls

	./genome_updater.sh -d "refseq" -g "fungi" -c "all" -l "all" -f "assembly_report.txt" -o "fungi" -t 12 -r -p

### Recovering fasta files from a previously obtained assembly_summary.txt

	./genome_updater.sh -e /my/path/assembly_summary.txt -f "genomic.fna.gz" -o "recovered_sequences" -b january_2018

### Changing timeout and tries of the downloads (wget)

	wget_tries=10 wget_timeout=600 ./genome_updater.sh -g "fungi" -o fungi -t 12 -f "genomic.fna.gz,assembly_report.txt"

## Extended reports:

### assembly accessions

The parameter **-u** activates the output of a list of updated assembly accessions for the entries with all files (**-f**) successfully downloaded. The file `updated_assembly_accession.txt` has the following fields (tab separated):

	Added [A] or Removed [R], assembly accession, url

Example:

	A	GCF_000146045.2	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/146/045/GCF_000146045.2_R64
	A	GCF_000002515.2	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/002/515/GCF_000002515.2_ASM251v1
	R	GCF_000091025.4	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/091/025/GCF_000091025.4_ASM9102v4

### sequence accessions

The parameter **-r** activates the output of a list of updated sequence accessions for the entries with all files (**-f**) successfully downloaded. It is only available when `assembly_report.txt` is one of the file types. The file `updated_sequence_accession.txt` has the following fields (tab separated):

	Added [A] or Removed [R], assembly accession, genbank accession, refseq accession, sequence length, taxonomic id

Example:

	A	GCA_000243255.1	CM001436.1	NZ_CM001436.1	3200946	937775
	R	GCA_000275865.1	CM001555.1	NZ_CM001555.1	2475100	28892

* genome_updater fixes the current version of the database before updating (or just fix with **-i**). In this step if some entry is fixed and the reports are active, all lines are going to be reported as Added.

### URLs (and files)

The parameter **-p** activates the output of a list of failed and successfully downloaded urls to the files `{timestamp}_url_downloaded.txt` and `{timestamp}_url_failed.txt` (failed list will only be complete if command runs until the end, without errors or breaks).

To obtain a list of successfully downloaded files from this report (useful to get only new files after updating):

	sed 's#.*/##' {timestamp}_url_list_downloaded.txt

## Parameters:

	genome_updater v0.2.0 by Vitor C. Piro (vitorpiro@gmail.com, http://github.com/pirovc)

	 -g Organism group (one or more comma-separated entries) [archaea, bacteria, fungi, human (also contained in vertebrate_mammalian), invertebrate, metagenomes (genbank), other (synthetic genomes - only genbank), plant, protozoa, vertebrate_mammalian, vertebrate_other, viral (only refseq)]. Example: archaea,bacteria
	    or Species level taxids (one or more comma-separated entries). Example: species:622,562
	    or Any level taxids - lineage will be generated (one or more comma-separated entries). Example: taxids:620,649776

	 -d Database [genbank, refseq]
	        Default: refseq
	 -c RefSeq Category [all, reference genome, representative genome, na]
	        Default: all
	 -l Assembly level [all, Complete Genome, Chromosome, Scaffold, Contig]
	        Default: all
	 -f File formats [genomic.fna.gz,assembly_report.txt, ... - check ftp://ftp.ncbi.nlm.nih.gov/genomes/all/README.txt for all file formats]
	        Default: assembly_report.txt

	 -k Do not perform any new download or update - just checks for sequences and changes
	 -i Fix failed downloads or any incomplete data from a previous run, keep current version
	 -x Allow the deletion of extra files if some are found in the repository folder

	 -u Report of updated assembly accessions (Added/Removed, assembly accession, url)
	 -r Report of updated sequence accessions (Added/Removed, assembly accession, genbank accession, refseq accession, sequence length, taxid). Only available when file assembly_report.txt selected and successfully downloaded
	 -p Output list of URLs for downloaded and failed files
	 -a Download the current version of the Taxonomy database (taxdump.tar.gz)

	 -o Working output directory
	        Default: ./tmp.XXXXXXXXXX
	 -b Version label
	        Default: current timestamp (YYYY-MM-DD_HH-MM-SS)
	 -e External "assembly_summary.txt" file to recover data from
	        Default: ""
	 -t Threads
	        Default: 1

	 -m Check MD5 for downloaded files
	 -s Silent output
	 -w Silent output with download progress (%) and download version at the end
	 -n Conditional exit status. Exit Code = 1 if more than N files failed to download (integer for file number, float for percentage, 0 -> off)
	        Default: 0

## References:

[1] ftp://ftp.ncbi.nlm.nih.gov/genomes/

[2] Tange (2011): GNU Parallel - The Command-Line Power Tool, ;login: The USENIX Magazine, February 2011:42-47.
