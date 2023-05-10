# genome_updater [![Build Status](https://travis-ci.com/pirovc/genome_updater.svg?branch=master)](https://travis-ci.com/pirovc/genome_updater) [![codecov](https://codecov.io/gh/pirovc/genome_updater/branch/master/graph/badge.svg)](https://codecov.io/gh/pirovc/genome_updater) [![Anaconda-Server Badge](https://anaconda.org/bioconda/genome_updater/badges/downloads.svg)](https://anaconda.org/bioconda/genome_updater)

Bash script to download ***and update*** snapshots of the NCBI genomes repository (refseq/genbank) [1] with filters, detailed log, reports, file integrity check (MD5) and parallel [2] download support.

## Quick usage guide

### Get genome_updater

	wget --quiet --show-progress https://raw.githubusercontent.com/pirovc/genome_updater/master/genome_updater.sh
	chmod +x genome_updater.sh

### Download

Download Archaeal complete genome sequences from the refseq repository (`-t` number parallel downloads):

	./genome_updater.sh -o "arc_refseq_cg" -d "refseq" -g "archaea" -l "complete genome" -f "genomic.fna.gz" -t 12

### Update

Some days later, update the repository:

	./genome_updater.sh -o "arc_refseq_cg"

 - Add `-k` to perform a dry-run, showing how many files will be downloaded/updated without any changes.

 - Newly added sequences will be downloaded and a new version (`-b`, timestamp by default) will be created. Removed or old sequences will be kept but not carried to the new version.

 - Arguments can be added or changed in the update. For example `./genome_updater.sh -o "arc_refseq_cg" -t 2` to use a different number of threads or `./genome_updater.sh -o "arc_refseq_cg" -l ""` to remove the "complete genome" filter.

 - `history.tsv` will be created in the output folder (`-o`), tracking versions and arguments used (obs: boolean flags/arguments are not tracked - e.g. `-m`).

## Details

genome_updater downloads and keeps several snapshots of a certain sub-set of the genomes repository, without redundancy and with incremental track of changes.

- it runs on a working directory (defined with `-o`) and creates a snapshot (optionally named with `-b`, timestamp by default) of refseq and/or genbank (`-d`) genome repositories based on selected organism groups (`-g`) and/or taxonomic ids (`-T`) with the desired files type(s) (`-f`)
- files are downloaded to a single folder by default ("{prefix}files/") but can be also saved in the NCBI ftp file structure (`-N`)
- filters can be applied to refine the selection: refseq category (`-c`), assembly level (`-l`), dates (`-D`/`-E`), custom filters (`-F`), [top assemblies](#Top-assemblies) (`-A`)
- `-M gtdb` enables GTDB [3] compability. Only assemblies from the latest GTDB release will be kept and taxonomic filters will work based on GTDB nodes (e.g. `-T "c__Hydrothermarchaeia"` or `-A genus:3`)
- the repository can be updated or changed with incremental changes. outdated files are kept in their respective version and repeated files linked to the new version. genome_updater keepts track of all changes and just downloads what is necessary

## Installation

With conda:

	conda install -c bioconda genome_updater 

or direct file download:

	wget https://raw.githubusercontent.com/pirovc/genome_updater/master/genome_updater.sh
	chmod +x genome_updater.sh

 - genome_updater is portable and depends on the GNU Core Utilities + few additional tools (`awk` `bc` `find` `join` `md5sum` `parallel` `sed` `tar` `wget`/`curl`) which are commonly available and installed in most distributions. If you are not sure if you have them all, just run `genome_updater.sh` and it will tell you if something is missing (otherwise the it will show the help page).

To test if all genome_updater functions are running properly on your system:

	git clone --recurse-submodules https://github.com/pirovc/genome_updater.git
	cd genome_updater
	tests/test.sh

## Examples

### Archaea, Bacteria, Fungi and Viral complete genome sequences from refseq

	# Download (-m to check integrity of downloaded files)
	./genome_updater.sh -d "refseq" -g "archaea,bacteria,fungi,viral" -f "genomic.fna.gz" -o "arc_bac_fun_vir_refseq_cg" -t 12 -m
	
	# Update (e.g. some days later)
	./genome_updater.sh -o "arc_bac_fun_vir_refseq_cg" -m
	
### All RNA Viruses (under the taxon Riboviria) on refseq

	./genome_updater.sh -d "refseq" -T "2559587" -f "genomic.fna.gz" -o "all_rna_virus" -t 12 -m
	
### One genome assembly for each bacterial taxonomic node (leaves) in genbank
    
    ./genome_updater.sh -d "genbank" -g "bacteria" -f "genomic.fna.gz" -o "top1_bacteria_genbank" -A 1 -t 12 -m 
    
### One genome assembly for each bacterial species in genbank
    
    ./genome_updater.sh -d "genbank" -g "bacteria" -f "genomic.fna.gz" -o "top1species_bacteria_genbank" -A "species:1" -t 12 -m 
    
### All genome sequences used in the latests GTDB release

	./genome_updater.sh -d "refseq,genbank" -g "archaea,bacteria" -f "genomic.fna.gz" -o "GTDB_complete" -M "gtdb" -t 12 -m
	
### Two genome assemblies for every genus in GTDB
    
    ./genome_updater.sh -d "refseq,genbank" -g "archaea,bacteria" -f "genomic.fna.gz" -o "GTDB_top2genus" -M "gtdb" -A "genus:2" -t 12 -m

### All assemblies from a specific family in GTDB
    
    ./genome_updater.sh -d "refseq,genbank" -g "archaea,bacteria" -f "genomic.fna.gz" -o "GTDB_family_Gastranaerophilaceae" -M "gtdb" -T "f__Gastranaerophilaceae" -t 12 -m

### Recovering fasta files from a previously obtained assembly_summary.txt

	./genome_updater.sh -e /my/path/assembly_summary.txt -f "genomic.fna.gz" -o "recovered_sequences"

## Advanced examples

### Downloading genomic sequences (.fna files) for the Complete Genome sequences from RefSeq for Bacteria and Archaea and keep them updated

	# Dry-run to check files available
	./genome_updater.sh -d "refseq" -g "archaea,bacteria" -l "complete genome" -f "genomic.fna.gz" -k
	
	# Download (-o output folder, -t threads, -m checking md5, -u extended assembly accession report)
	./genome_updater.sh -d "refseq" -g "archaea,bacteria" -l "complete genome" -f "genomic.fna.gz" -o "arc_bac_refseq_cg" -t 12 -u -m
	
	# Downloading additional .gbff files for the current snapshot (adding genomic.gbff.gz to -f , -i to just add files and not update)
	./genome_updater.sh -f "genomic.fna.gz,genomic.gbff.gz" -o "arc_bac_refseq_cg" -i
	
	# Some days later, just check for updates but do not update
	./genome_updater.sh -o "arc_bac_refseq_cg" -k

	# Perform update
	./genome_updater.sh -o "arc_bac_refseq_cg" -u -m

### Branching base version for specific filters

	# Download the complete bacterial refseq
	./genome_updater.sh -d "refseq" -g "bacteria" -f "genomic.fna.gz" -o "bac_refseq" -t 12 -m -b "all"

	# Branch the main files into two sub-versions (no new files will be downloaded or copied)
	./genome_updater.sh -o "bac_refseq" -B "all" -b "complete" -l "complete genome"
	./genome_updater.sh -o "bac_refseq" -B "all" -b "represen" -c "representative genome"

### Download Fungi RefSeq assembly information and generate sequence reports and URLs

	./genome_updater.sh -d "refseq" -g "fungi" -f "assembly_report.txt" -o "fungi" -t 12 -rpu

### Use curl (default wget), change timeout and retries for download, increase retries

	retries=10 timeout=600 ./genome_updater.sh -g "fungi" -o fungi -t 12 -f "genomic.fna.gz,assembly_report.txt" -L curl -R 6

## Reports

### assembly accessions

The parameter `-u` activates the output of a list of updated assembly accessions for the entries with all files (`-f`) successfully downloaded. The file `{timestamp}_assembly_accession.txt` has the following fields (tab separated):

	Added [A] or Removed [R], assembly accession, url

Example:

	A	GCF_000146045.2	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/146/045/GCF_000146045.2_R64
	A	GCF_000002515.2	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/002/515/GCF_000002515.2_ASM251v1
	R	GCF_000091025.4	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/091/025/GCF_000091025.4_ASM9102v4

### sequence accessions

The parameter `-r` activates the output of a list of updated sequence accessions for the entries with all files (`-f`) successfully downloaded. It is only available when `assembly_report.txt` is one of the file types. The file `{timestamp}_sequence_accession.txt` has the following fields (tab separated):

	Added [A] or Removed [R], assembly accession, genbank accession, refseq accession, sequence length, taxonomic id

Example:

	A	GCA_000243255.1	CM001436.1	NZ_CM001436.1	3200946	937775
	R	GCA_000275865.1	CM001555.1	NZ_CM001555.1	2475100	28892

Obs: if genome_updater breaks or do not finish completely some files may be missing from the assembly and sequence accession reports

### URLs (and files)

The parameter `-p` activates the output of a list of failed and successfully downloaded urls to the files `{timestamp}_url_downloaded.txt` and `{timestamp}_url_failed.txt` (failed list will only be complete if command runs until the end, without errors or breaks).

To obtain a list of successfully downloaded files from this report (useful to get only new files after updating):

	sed 's#.*/##' {timestamp}_url_list_downloaded.txt
	
or

	find output_folder/version/files/ -type f

## Top assemblies

`-A` will selected the "best" assemblies for each taxonomic nodes (leaves or specific rank) according to 4 categories (A-D), in the following order of importance:

	A) refseq Category: 
		1) reference genome
		2) representative genome
		3) na
	B) Assembly level:
		1) Complete Genome
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


## Parameters

```

┌─┐┌─┐┌┐┌┌─┐┌┬┐┌─┐    ┬ ┬┌─┐┌┬┐┌─┐┌┬┐┌─┐┬─┐
│ ┬├┤ ││││ ││││├┤     │ │├─┘ ││├─┤ │ ├┤ ├┬┘
└─┘└─┘┘└┘└─┘┴ ┴└─┘────└─┘┴  ─┴┘┴ ┴ ┴ └─┘┴└─
                                     v0.6.2 

Database options:
 -d Database (comma-separated entries)
	[genbank, refseq]

Organism options:
 -g Organism group(s) (comma-separated entries, empty for all)
	[archaea, bacteria, fungi, human, invertebrate, metagenomes, 
	other, plant, protozoa, vertebrate_mammalian, vertebrate_other, viral]
	Default: ""
 -T Taxonomic identifier(s) (comma-separated entries, empty for all).
	Example: "562" (for -M ncbi) or "s__Escherichia coli" (for -M gtdb)
	Default: ""

File options:
 -f file type(s) (comma-separated entries)
	[genomic.fna.gz, assembly_report.txt, protein.faa.gz, genomic.gbff.gz]
	More formats at https://ftp.ncbi.nlm.nih.gov/genomes/all/README.txt
	Default: assembly_report.txt

Filter options:
 -c refseq category (comma-separated entries, empty for all)
	[reference genome, representative genome, na]
	Default: ""
 -l assembly level (comma-separated entries, empty for all)
	[complete genome, chromosome, scaffold, contig]
	Default: ""
 -D Start date (>=), based on the sequence release date. Format YYYYMMDD.
	Default: ""
 -E End date (<=), based on the sequence release date. Format YYYYMMDD.
	Default: ""
 -F custom filter for the assembly summary in the format colA:val1|colB:valX,valY (case insensitive).
	Example: -F "2:PRJNA12377,PRJNA670754|14:Partial" (AND between cols, OR between values)
	Column info at https://ftp.ncbi.nlm.nih.gov/genomes/README_assembly_summary.txt
	Default: ""

Taxonomy options:
 -M Taxonomy. gtdb keeps only assemblies in GTDB (latest). ncbi keeps only latest assemblies (version_status). 
	[ncbi, gtdb]
	Default: "ncbi"
 -A Keep a limited number of assemblies for each selected taxa (leaf nodes). 0 for all. 
	Selection by ranks are also supported with rank:number (e.g genus:3)
	[species, genus, family, order, class, phylum, kingdom, superkingdom]
	Selection order based on: RefSeq Category, Assembly level, Relation to type material, Date.
	Default: 0
 -a Keep the current version of the taxonomy database in the output folder

Run options:
 -o Output/Working directory 
	Default: ./tmp.XXXXXXXXXX
 -t Threads to parallelize download and some file operations
	Default: 1
 -k Dry-run mode. No sequence data is downloaded or updated - just checks for available sequences and changes
 -i Fix only mode. Re-downloads incomplete or failed data from a previous run. Can also be used to change files (-f).
 -m Check MD5 of downloaded files

Report options:
 -u Updated assembly accessions report
	(Added/Removed, assembly accession, url)
 -r Updated sequence accessions report
	(Added/Removed, assembly accession, genbank accession, refseq accession, sequence length, taxid)
	Only available when file format assembly_report.txt is selected and successfully downloaded
 -p Reports URLs successfuly downloaded and failed (url_failed.txt url_downloaded.txt)

Misc. options:
 -b Version label
	Default: current timestamp (YYYY-MM-DD_HH-MM-SS)
 -e External "assembly_summary.txt" file to recover data from. Mutually exclusive with -d / -g 
	Default: ""
 -B Alternative version label to use as the current version. Mutually exclusive with -i.
	Can be used to rollback to an older version or to create multiple branches from a base version.
	Default: ""
 -R Number of attempts to retry to download files in batches 
	Default: 3
 -n Conditional exit status based on number of failures accepted, otherwise will Exit Code = 1.
	Example: -n 10 will exit code 1 if 10 or more files failed to download
	[integer for file number, float for percentage, 0 = off]
	Default: 0
 -N Output files in folders like NCBI ftp structure (e.g. files/GCF/000/499/605/GCF_000499605.1_EMW001_assembly_report.txt)
 -L Downloader
	[wget, curl]
	Default: wget
 -x Allow the deletion of regular extra files (not symbolic links) found in the output folder
 -s Silent output
 -w Silent output with download progress only
 -V Verbose log
 -Z Print debug information and run in debug mode

```

## References:

[1] ftp://ftp.ncbi.nlm.nih.gov/genomes/

[2] O. Tange (2018): GNU Parallel 2018, March 2018, https://doi.org/10.5281/zenodo.1146014.

[3] https://gtdb.ecogenomic.org/
