# genome_updater

Vitor C. Piro (vitorpiro@gmail.com)


Script to download and update files from NCBI genomes [1] keeping log and version for each update.

On the first run, genome_updater creates a folder (-o) for the database files and downloads the current version.
The same command executed again will identify previous files and update the database.
Check for updates with the -k option (new download or existing folder).
genome_updater also can re-download missing files and remove extra files from the database folder (-x).


Running examples:
-----------------
	# Download bacterial complete genomes sequences on refseq
	./genome_updater.sh -d "refseq" -g "bacteria" -c "all" -l "Complete Genome" -f "genomic.fna.gz" -o refseq_bacteria/ -t 12

	# Download bacterial and fungal reference genome sequences, annotations and assembly reports on refseq
	./genome_updater.sh -d "refseq" -g "archaea,bacteria,fungi" -c "reference genome" -l "all" -f "genomic.fna.gz,genomic.gff.gz,assembly_report.txt" -u -r -o sequences/ -t 12
	
	# Just check for archaeal entries on refseq/genbank
	./genome_updater.sh -d "all" -g "archaea" -c "all" -l "all" -f "genomic.fna.gz" -k

Parameters:
-----------

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

 -u Output list of updated entries (Added/Removed, assembly accession, url)
 -r Output list of updated entries (Added/Removed, refseq accession, genbank accession, sequence length, taxid). Only available when the file format assembly_report.txt is chosen.

 -o Output folder
        Default: db/
 -t Threads
        Default: 1
	
References:
-----------

[1] ftp://ftp.ncbi.nlm.nih.gov/genomes/
