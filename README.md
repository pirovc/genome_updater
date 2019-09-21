# genome_updater

Vitor C. Piro (vitorpiro@gmail.com)

Bash script to download and update snapshots from NCBI genomes (refseq/genbank) [1] keeping log a detailed log for each update, with file integrity check (MD5) and parallel [2] download support.

## Usage:

- genome_updater runs on a working directory (**-o**) and creates snapshots/versions (**-b**) of refseq/genbank repositories besed on selected parameters (database (**-d**), organism group  or species/taxids (**-g**), RefSeq category (**-c**), assembly level (**-l**) and file type(s) (**-f**))
- it can update the selected repository by executing the same command again. genome_updater will identify previous files and update the working directory with the most recente version, keeping track of changes and just downloading/removing updated files

genome_updater also:
- checks for MD5 with the option **-m**
- downloads complete organism groups (**-g "archaea,bacteria"**), specific species groups (**-g "species:562,623"**) or any taxonomic group and any sequence in their lineage (**-g "taxids:620,1643685"**)
- re-downloads files from any "assembly_summary.txt" obtained from external sources (**-e**)
- checks only for available entries or updates with the **-k** option without downloading any file or changing the current version
- fix and re-downloads missing files from current version (**-i**)
- removes extra files from the output folder (**-x**)
- downloads the current taxonomic database version on each run by activating the parameter **-a**
- provides extended reports for better integration in other tools (**-u**, **-r** and **-p**)
- has configurable exit codes based on the number/percetage of files downloaded (**-n**)
- has silent (**-s**) and silent with download progress (**-w**) mode for easy integration in pipelines 

## Examples:

### Downloading genomic sequences (.fna files) for the Complete Genome sequences from RefSeq for Bacteria and Archaea and keep them updated

	# Download (checking md5, 12 threads, with extended assembly accession report)
	./genome_updater.sh -d "refseq" -g "archaea,bacteria" -c "all" -l "Complete Genome" -f "genomic.fna.gz" -o "arc_bac_refseq_cg" -t 12 -u -m
	
	# Downloading additional .gbff files for the current setup (adding genomic.gbff.gz to -f)
	./genome_updater.sh -d "refseq" -g "archaea,bacteria" -c "all" -l "Complete Genome" -f "genomic.fna.gz,genomic.gbff.gz" -o "arc_bac_refseq_cg" -t 12 -u -m -i
	
	# Some days later, just check for updates but do not update
	./genome_updater.sh -d "refseq" -g "archaea,bacteria" -c "all" -l "Complete Genome" -f "genomic.fna.gz,genomic.gbff.gz" -o "arc_bac_refseq_cg" -k

	# Perform update
	./genome_updater.sh -d "refseq" -g "archaea,bacteria" -c "all" -l "Complete Genome" -f "genomic.fna.gz,genomic.gbff.gz" -o "arc_bac_refseq_cg" -t 12 -u -m

### Download all RNA Viruses (under the taxon Riboviria) on RefSeq

	./genome_updater.sh -d "refseq" -g "taxids:2559587" -f "genomic.fna.gz" -o "all_rna_virus" -t 12

### Download all E. Coli assemblies available on GenBank and RefSeq

	./genome_updater.sh -d "genbank,refseq" -g "species:562" -f "genomic.fna.gz" -o "all_ecoli" -t 12

### Check amount of refence entries available for the set of Viral genomes on genbank

	./genome_updater.sh -d "genbank" -g "viral" -c "all" -l "all" -k

### Download Fungi RefSeq assembly information and generate sequence reports and urls

	./genome_updater.sh -d "refseq" -g "fungi" -c "all" -l "all" -f "assembly_report.txt" -o "fungi" -t 12 -r -p

### Recovering fasta files from a previously obtained assembly_summary.txt

	./genome_updater.sh -e /my/path/assembly_summary.txt -f "genomic.fna.gz"

## Extended reports:

### assembly accessions

The parameter **-u** activates the output of a list of updated assembly accessions for the entries with all files (**-f**) successfuly downloaded. The file `{timestamp}_updated_assembly_accession.txt` has the following fields (tab separated):

	Added [A] or Removed [R], assembly accession, url

Example:

	A	GCF_000146045.2	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/146/045/GCF_000146045.2_R64
	A	GCF_000002515.2	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/002/515/GCF_000002515.2_ASM251v1
	R	GCF_000091025.4	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/091/025/GCF_000091025.4_ASM9102v4

### sequence accessions

The parameter **-r** activates the output of a list of updated sequence accessions for the entries with all files (**-f**) successfuly downloaded. It is only available when `assembly_report.txt` is one of the file types. The file `{timestamp}_updated_sequence_accession.txt` has the following fields (tab separated):

	Added [A] or Removed [R], assembly accession, genbank accession, refseq accession, sequence length, taxonomic id

Example:

	A	GCA_000243255.1	CM001436.1	NZ_CM001436.1	3200946	937775
	R	GCA_000275865.1	CM001555.1	NZ_CM001555.1	2475100	28892

* genome_updater fixes the current version of the database before updating (or just fix with **-i**). In this step if some entry is fixed with all files (**-f**) successfuly downloaded, the following files will also be created: `{timestamp}_missing_assembly_accession.txt` and `{timestamp}_missing_sequence_accession.txt`, making it possible to keep track of every change on the downloaded files.

### URLs (and files)

The parameter **-p** activates the output of a list of failed and successfuly downloaded urls to the files `{timestamp}_url_list_downloaded.txt` and `{timestamp}_url_list_failed.txt` (failed list will only be complete if command runs until the end, without errors or breaks).

To obtain a list of successfuly downloaded files from this report (useful to get only new files after updating):

	sed 's#.*/##' {timestamp}_url_list_downloaded.txt

## Parameters:

	genome_updater v0.1.3 by Vitor C. Piro (vitorpiro@gmail.com, http://github.com/pirovc)

	 -g Organism group (one or more comma-separated entries) [archaea, bacteria, fungi, human (also contained in vertebrate_mammalian), invertebrate, metagenomes (only genbank), other (synthetic genomes - only genbank), plant, protozoa, vertebrate_mammalian, vertebrate_other, viral (only refseq)]. Example: archaea,bacteria
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

	 -a Download the current version of the Taxonomy database (taxdump.tar.gz)
	 -k Just check for updates, keep current version
	 -i Fix or recover files based on the current version or external file (assembly_summary.txt), do not look for updates
	 -x Delete any extra files inside the output folder
	 -m Check md5 (after download only)

	 -u Output list of updated assembly accessions (Added/Removed, assembly accession, url)
	 -r Output list of updated sequence accessions (Added/Removed, assembly accession, genbank accession, refseq accession, sequence length, taxid). Only available when file assembly_report.txt selected and successfuly downloaded
	 -p Output list of URLs for downloaded and failed files

	 -n Conditional exit status. Exit Code = 1 if more than N files failed to download (integer for file number, float for percentage, 0 -> off)
		Default: 0

	 -s Silent output
	 -w Silent output with download progress (%) and download version at the end
	 -o Output folder
		Default: ./tmp.XXXXXXXXXX
	 -t Threads
		Default: 1
## References:

[1] ftp://ftp.ncbi.nlm.nih.gov/genomes/

[2] Tange (2011): GNU Parallel - The Command-Line Power Tool, ;login: The USENIX Magazine, February 2011:42-47.
