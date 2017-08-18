# genome_updater

Vitor C. Piro (vitorpiro@gmail.com)


Script to download and update files from NCBI genomes [1] keeping log and version for each update, with file check (md5) and multi-thread support.

Usage:
------

- On the first run, genome_updater creates a folder (-o) and downloads the current version (with timestamp) based on selected parameters (database, organism group, refseq category, assembly level and file type(s))
- The same command executed again will identify previous files and update the folder with the current version, keeping track of changes and just downloading updated files

genome_updater also:
- checks for MD5 with the option -m
- checks only for updates with the -k option (first time or update) without changing the current version
- re-downloads missing files and removes extra files from the database folder (-x)
- fixes current version without looking for updates with -i
- downloads the taxonomic database version on each run by activating the parameter -a
- provides extended reports for better integration in other tools (-u and -r)

Running examples:
-----------------
	# Download bacterial complete genomes sequences on refseq (checking md5)
	./genome_updater.sh -d "refseq" -g "bacteria" -c "all" -l "Complete Genome" -f "genomic.fna.gz" -o refseq_bacteria/ -t 12 -m

	# Download bacterial and fungal reference genome sequences, annotations and assembly reports on refseq with extended reports
	./genome_updater.sh -d "refseq" -g "archaea,bacteria,fungi" -c "reference genome" -l "all" -f "genomic.fna.gz,genomic.gff.gz,assembly_report.txt" -u -r -o sequences/ -t 12 -r -u
	
	# Just check for archaeal entries on refseq/genbank
	./genome_updater.sh -d "all" -g "archaea" -c "all" -l "all" -f "genomic.fna.gz" -k

Extended reports:
-----------------

Parameter -u activates the report of added and removed files from the current download/update (based on assemblies) with the following fields (tab separated):

	Added [A] or removed [R], Assembly Accession, url

Example:

	A	GCF_000146045.2	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/146/045/GCF_000146045.2_R64
	A	GCF_000002515.2	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/002/515/GCF_000002515.2_ASM251v1
	R	GCF_000091025.4	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/091/025/GCF_000091025.4_ASM9102v4

	
Parameter -r activates the report of added and removed files based on sequences (it is only available when assembly_report.txt is one of the file types) with the following fields (tab separated)s:

	Added [A] or removed [R], RefSeq accession, Genbank accession, sequence length, taxonomic id

Example:

	A	BK006948.2	NC_001147.6	1091291	559292
	A	BK006949.2	NC_001148.4	948066	559292
	R	CP003013.1	NC_016461.1	4396881	578455
	R	CP003014.1	NC_016462.1	3570487	578455
	A	CP014501.1	NC_031672.1	5930846	796027
	
Parameters:
-----------

	genome_updater v0.06 by Vitor C. Piro (vitorpiro@gmail.com, http://github.com/pirovc)

	 -d Database [all, genbank, refseq]
			Default: refseq
	 -g Organism group [archaea, bacteria, fungi, invertebrate, metagenomes (only genbank), other (synthetic genomes - only genbank), plant, protozoa, vertebrate_mammalian, vertebrate_other, viral (only refseq)]
			Default: bacteria
	 -c RefSeq Category [all, reference genome, representative genome, na]
			Default: all
	 -l Assembly level [all, Complete Genome, Chromosome, Scaffold, Contig]
			Default: all
	 -f File formats [genomic.fna.gz,assembly_report.txt, ... - check ftp://ftp.ncbi.nlm.nih.gov/genomes/all/README.txt for all file formats]
			Default: genomic.fna.gz

	 -a Download current version of the Taxonomy database (taxdump.tar.gz)
	 -k Just check for updates, keep current version
	 -i Just fix files based on the current version, do not look for updates
	 -x Delete any extra files inside the folder
	 -m Check md5 (after download only)

	 -u Output list of updated assembly accessions (Added/Removed, assembly accession, url)
	 -r Output list of updated sequence accessions (Added/Removed, refseq accession, genbank accession, sequence length, taxid). Only available when file assembly_report.txt is downloaded

	 -o Output folder
			Default: db/
	 -t Threads
			Default: 1
	
References:
-----------

[1] ftp://ftp.ncbi.nlm.nih.gov/genomes/
