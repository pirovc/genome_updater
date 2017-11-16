# genome_updater

Vitor C. Piro (vitorpiro@gmail.com)

Script to download and update files from NCBI genomes [1] keeping log and version for each update, with file check (md5) and parallel [2] download support.

Usage:
------

- On the first run, genome_updater creates a folder (**-o**) and downloads the current version based on selected parameters (database, organism group, refseq category, assembly level and file type(s))
- All file will be marked with a timestamp in the format `YYYY-MM-DD_HH-MM-SS` (e.g. 2017-11-30_16-09-15) and the files will be downloaded to the `output_folder/files/`
- The same command executed again will identify previous files and update the folder with the current version, keeping track of changes and just downloading updated files

genome_updater also:
- checks for MD5 with the option **-m**
- checks only for updates with the **-k** option (first time or update) without changing the current version
- re-downloads missing files from current version (**-i**) without looking for updates
- removes extra files from the output folder (**-x**)
- downloads the taxonomic database version on each run by activating the parameter **-a**
- provides extended reports for better integration in other tools (**-u** and **-r**)

Running examples:
-----------------

Downloading genomic sequences (.fna files) for the Complete Genome sequences from RefSeq for Bacteria and Archaea

	# Download (checking md5, 12 threads, with extended assembly accession report)
	./genome_updater.sh -d "refseq" -g "archaea,bacteria" -c "all" -l "Complete Genome" -f "genomic.fna.gz" -o "arc_bac_refseq_cg" -t 12 -u -m
	
	# Downloading .gbff files for the current setup (adding genomic.gbff.gz to -f)
	./genome_updater.sh -d "refseq" -g "archaea,bacteria" -c "all" -l "Complete Genome" -f "genomic.fna.gz,genomic.gbff.gz" -o "arc_bac_refseq_cg" -t 12 -u -m -i
	
	# Some days later, just check for updates but do not update
	./genome_updater.sh -d "refseq" -g "archaea,bacteria" -c "all" -l "Complete Genome" -f "genomic.fna.gz,genomic.gbff.gz" -o "arc_bac_refseq_cg" -k

	# Perform update
	./genome_updater.sh -d "refseq" -g "archaea,bacteria" -c "all" -l "Complete Genome" -f "genomic.fna.gz,genomic.gbff.gz" -o "arc_bac_refseq_cg" -t 12 -u -m

Just check for the set of Viral entries on genbank

	./genome_updater.sh -d "genbank" -g "viral" -c "all" -l "all" -o "check_viral" -k

Download Fungi RefSeq sequence reports 

	./genome_updater.sh -d "refseq" -g "fungi" -c "all" -l "all" -f "assembly_report.txt" -r -o "fungi" -t 12 -r

Extended reports:
-----------------

Parameter **-u** output the list of updated assembly accessions. It does not account for unsuccessful downloads. The file `{timestamp}_updated_assembly_accession.txt` has the following fields (tab separated):

	Added [A] or Removed [R], assembly accession, url

Example:

	A	GCF_000146045.2	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/146/045/GCF_000146045.2_R64
	A	GCF_000002515.2	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/002/515/GCF_000002515.2_ASM251v1
	R	GCF_000091025.4	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/091/025/GCF_000091025.4_ASM9102v4

	
Parameter **-r** output the list of updated sequence accessions. It is only available when `assembly_report.txt` is one of the file types. This report will be based on such files, not accounting for other type of downloaded files. The file `{timestamp}_updated_sequence_accession.txt` (and `{timestamp}_missing_sequence_accession.txt` for missing files) has the following fields (tab separated):

	Added [A] or Removed [R], assembly accession, genbank accession, refseq accession, sequence length, taxonomic id

Example:

	A	GCA_000243255.1	CM001436.1	NZ_CM001436.1	3200946	937775
	R	GCA_000275865.1	CM001555.1	NZ_CM001555.1	2475100	28892

	
Parameters:
-----------

	genome_updater v0.08 by Vitor C. Piro (vitorpiro@gmail.com, http://github.com/pirovc)

	 -d Database [all, genbank, refseq]
	        Default: refseq
	 -g Organism group [archaea, bacteria, fungi, invertebrate, metagenomes (only genbank), other (synthetic genomes - only genbank), plant, protozoa, vertebrate_mammalian, vertebrate_other, viral (only refseq)]
	        Default: bacteria
	 -c RefSeq Category [all, reference genome, representative genome, na]
	        Default: all
	 -l Assembly level [all, Complete Genome, Chromosome, Scaffold, Contig]
	        Default: all
	 -f File formats [genomic.fna.gz,assembly_report.txt, ... - check ftp://ftp.ncbi.nlm.nih.gov/genomes/all/README.txt for all file formats]
	        Default: assembly_report.txt

	 -a Download current version of the Taxonomy database (taxdump.tar.gz)
	 -k Just check for updates, keep current version
	 -i Just fix files based on the current version, do not look for updates
	 -x Delete any extra files inside the output folder
	 -m Check md5 (after download only)

	 -u Output list of updated assembly accessions (Added/Removed, assembly accession, url)
	 -r Output list of updated sequence accessions (Added/Removed, assembly accession, genbank accession, refseq accession, sequence length, taxid). Only available when file assembly_report.txt selected and successfuly downloaded

	 -o Output folder
	        Default: db/
	 -t Threads
	        Default: 1

	
References:
-----------

[1] ftp://ftp.ncbi.nlm.nih.gov/genomes/
[2] Tange (2011): GNU Parallel - The Command-Line Power Tool, ;login: The USENIX Magazine, February 2011:42-47.