
 -- Genome Updater - v0.01 --

 -d Database [all, genbank, refseq]
        Default: refseq
        
 -g Organism group [archaea, bacteria, fungi, invertebrate, metagenomes (only genbank), other (synthetic genomes - only genbank), plant, protozoa, vertebrate_mammalian, vertebrate_other, viral (only refseq)]
        Default: bacteria
        
 -c RefSeq Category [all, reference genome, representative genome, na]
        Default: all
        
 -l Assembly lebal [all, Complete Genome, Chromosome, Scaffold, Contig]
        Default: all
        
 -f File formats [genomic.fna.gz,assembly_report.txt, ... - check ftp://ftp.ncbi.nlm.nih.gov/genomes/all/README.txt for all file formats]
        Default: genomic.fna.gz
        
 -x Delete any extra files inside the folder
 
 -o Output folder
        Default: db/
        
 -t Threads
        Default: 1

