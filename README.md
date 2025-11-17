# genome_updater [![Build Status](https://app.travis-ci.com/pirovc/genome_updater.svg?branch=main)](https://app.travis-ci.com/pirovc/genome_updater) [![codecov](https://codecov.io/gh/pirovc/genome_updater/branch/master/graph/badge.svg)](https://codecov.io/gh/pirovc/genome_updater) [![Anaconda-Server Badge](https://anaconda.org/bioconda/genome_updater/badges/downloads.svg)](https://anaconda.org/bioconda/genome_updater)

genome_updater is a bash script that downloads and updates (non-redundant) snapshots of the NCBI Genomes repository (RefSeq/GenBank) [[1](https://ftp.ncbi.nlm.nih.gov/genomes/)] with advanced filters, detailed logs and reports, file integrity checks (MD5) and support for parallel [[2](https://doi.org/10.5281/zenodo.1146014)] downloads. genome_updater uses the [assembly_summary.txt](https://ftp.ncbi.nlm.nih.gov/genomes/README_assembly_summary.txt) to retrieve data.

## Quick usage guide

### Download 

```bash
wget --quiet --show-progress https://raw.githubusercontent.com/pirovc/genome_updater/master/genome_updater.sh
chmod +x genome_updater.sh
```

### Usage

Downloading archaeal complete genome genomic sequences from RefSeq (`-t` number parallel downloads):

```bash
./genome_updater.sh -o "arc_refseq_cg" -d "refseq" -g "archaea" -l "complete genome" -f "genomic.fna.gz" -t 12
```

Some days later, update the local repository to download newly added files:

```bash
./genome_updater.sh -o "arc_refseq_cg"
```

 - `-k` performs a dry-run, showing how many files can be downloaded/updated.

## Important parameters

A list of all parameters can be found [here](#genome_updater--h)


### Database/Organism/Taxa

- `-d`: Database/repository
  - Options: `refseq`, `genbank`
- `-g`: Whole organims groups
  - Options: `archaea`, `bacteria`, `fungi`, `human`, `invertebrate`, `metagenomes`, `other`, `plant`, `protozoa`, `vertebrate_mammalian`, `vertebrate_other`, `viral`
- `-T`: for taxonomy groups with optional negation using the `^` prefix
  - Examples: `-T '562'`, `-T '543,^562'`, `-T 'f__Enterobacteriaceae,^s__Escherichia coli'` (with `-M gtdb`)

### Output

- `-o`: Output directory
  - Every run generates a snapshot, which can be named using the `-b {snapshot}` option (a timestamp is used by default).
  - Downloaded files are stored in a single folder (`{working_dir}/{snapshot}/files/`), but the NCBI FTP file structure can be enforced using the `-N` option (e.g. `{working_dir}/{snapshot}/files/GCF/019/968/985/`).
- `-f`: File types. All file types are listed [here](ttps://ftp.ncbi.nlm.nih.gov/genomes/all/README.txt).
  - Example: `-f 'genomic.fna.gz,assembly_report.txt'`. 

### Filters

- `-c`: RefSeq category
  - Options: `reference genome`, `na`
- `-l`: Assembly level
  - Options: `Complete Genome`, `Chromosome`, `Scaffold`, `Contig`
- `-D`/`-E`: Start and end sequence release dates, respectivelly
  - Example: `-D 20201231 -E 20251231`
- `-F`: Custom filters for the [assembly_summary.txt](https://ftp.ncbi.nlm.nih.gov/genomes/README_assembly_summary.txt). Can be applied by column (e.g. `$4`) or in the whole file (`$0`). Uses [awk](https://www.gnu.org/software/gawk/manual/gawk.html) conditionals syntax.
  - Examples:
    - Single: `-F '$14 = "Full"'`
    - Multi:  `-F '($2 == "PRJNA12377" || $2 == "PRJNA670754") && $4 != "Partial"'`
    - Regex:  `-F '$8 ~ /bacterium/'`
    - Whole-file: `-F '$0 ~ "plasmid"'`


### Taxonomy

- `-A`: limits the number of assemblies for a specific taxonomy rank. [More infos](#Top-assemblies).
  - `-A 3` to keep 3 assemblies for each taxonomic leaf.
  - `-A 'genus:3'` 3 assemblies for each genus.
- `-M`: taxonomy
  - Options: `ncbi` (default), `gtdb`
  - The `-M gtdb` option enables GTDB compatibility, keeping only assemblies from the [most recent GTDB release](https://data.gtdb.aau.ecogenomic.org/releases/latest/). The taxonomy filter uses the GTDB format (e.g. `-T 's__Escherichia coli'`).
  
## Update details

When updating an existing local repository:

 - Newly added sequences will be downloaded, creating a new version (`-b`, timestamp by default).
 - Removed or old sequences will be retained, but not transferred to the new version.
 - Repeated/unchanged files are linked to the new version.
 - Arguments can be added to or changed in the update. For example, use the command `./genome_updater.sh -o "arc_refseq_cg" -t 2` to specify a different number of threads, or use the command `./genome_updater.sh -o "arc_refseq_cg" -l ""` to remove the `complete genome` filter.
 - The file `history.tsv` will be created in the output folder (`-o`), tracking the versions and arguments used. Please note that boolean flags/arguments are not tracked (e.g. `-m`).

## Installation

### conda/mamba

```bash
conda install -c bioconda genome_updater 
```

### direct file download

```bash
wget https://raw.githubusercontent.com/pirovc/genome_updater/master/genome_updater.sh
chmod +x genome_updater.sh
```

- genome_updater is portable and depends on the GNU Core Utilities + few additional tools (`awk` `bc` `find` `join` `md5sum` `parallel` `sed` `tar` `wget`/`curl`) which are commonly available and installed in most distributions. 

- If you are not sure if you have them all, just run `genome_updater.sh` and it will tell you if something is missing (otherwise the it will show the help page).

### tests

To test if all genome_updater functions are running properly on your system:

```bash
git clone --recurse-submodules https://github.com/pirovc/genome_updater.git
cd genome_updater
tests/test.sh
```

## Examples

### Archaea, Bacteria, Fungi and Viral complete genome sequences (RefSeq)

```bash
# Download (-m to check integrity of downloaded files)
./genome_updater.sh -d "refseq" -g "archaea,bacteria,fungi,viral" -f "genomic.fna.gz" -o "arc_bac_fun_vir_refseq_cg" -t 12 -m

# Update (e.g. some days later)
./genome_updater.sh -o "arc_bac_fun_vir_refseq_cg" -m
```

### All Riboviria RNA Viruses txid:2559587

```bash
# -t 12 for using 12 threads to download in parallel
./genome_updater.sh -d "refseq" -T "2559587" -f "genomic.fna.gz" -o "all_rna_virus" -t 12 -m
```

### One genome assembly for each bacterial taxonomic leaf node

```bash   
./genome_updater.sh -d "genbank" -g "bacteria" -f "genomic.fna.gz" -o "top1_bacteria_genbank" -A 1 -t 12 -m 
```

### One genome assembly for each bacterial species

```bash   
./genome_updater.sh -d "genbank" -g "bacteria" -f "genomic.fna.gz" -o "top1species_bacteria_genbank" -A "species:1" -t 12 -m 
```

### All genomes for the latests GTDB release

```bash 
./genome_updater.sh -d "refseq,genbank" -g "archaea,bacteria" -f "genomic.fna.gz" -o "GTDB_complete" -M "gtdb" -t 12 -m
```

### Two genome assemblies for every genus in GTDB

```bash 
./genome_updater.sh -d "refseq,genbank" -g "archaea,bacteria" -f "genomic.fna.gz" -o "GTDB_top2genus" -M "gtdb" -A "genus:2" -t 12 -m
```

### All assemblies from a specific family in GTDB

```bash 
./genome_updater.sh -d "refseq,genbank" -g "archaea,bacteria" -f "genomic.fna.gz" -o "GTDB_family_Gastranaerophilaceae" -M "gtdb" -T "f__Gastranaerophilaceae" -t 12 -m
```

### All assemblies from a specific family (excluding a genus) in GTDB

```bash 
./genome_updater.sh -d "refseq,genbank" -g "archaea,bacteria" -f "genomic.fna.gz" -o "GTDB_Mycobacteriacea_minus_Mycobacterium" -M "gtdb" -T "f__Mycobacteriacea,^g__Mycobacterium" -t 12 -m
```

## Advanced examples

### Download, change and update a repository

```bash 
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
```

### Branch from base version with specific filters

```bash 
# Download the complete bacterial refseq
./genome_updater.sh -d "refseq" -g "bacteria" -f "genomic.fna.gz" -o "bac_refseq" -t 12 -m -b "all"

# Branch the main files into two sub-versions (no new files will be downloaded or copied)
./genome_updater.sh -o "bac_refseq" -B "all" -b "complete" -l "complete genome"
./genome_updater.sh -o "bac_refseq" -B "all" -b "reference" -c "reference genome"
```

### Generate sequence reports and URLs

```bash 
./genome_updater.sh -d "refseq" -g "fungi" -f "assembly_report.txt" -o "fungi" -t 12 -rpu
```

### Recovering genomic assemblies from an external assembly_summary.txt

```bash 
./genome_updater.sh -e /my/path/assembly_summary.txt -f "genomic.fna.gz" -o "recovered_sequences"
```

### Use curl instead of wget, change timeout and retries for download, increase retries

```bash 
retries=10 timeout=600 ./genome_updater.sh -g "fungi" -o fungi -t 12 -f "genomic.fna.gz,assembly_report.txt" -L curl -R 10
```

### Use a local taxdump file

```bash 
new_taxdump_file="my/local/new_taxdump.tar.gz" ./genome_updater.sh -T 562 -o 562assemblies -t 12
```

- the [new_taxdump](https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/new_taxdump/) is required.


### Alternative download URL

```bash
# NCBI
ncbi_base_url="https://ftp.ncbi.nih.gov/" ./genome_updater.sh -d refseq -g bacteria

# GTDB
gtdb_base_url="https://data.gtdb.ecogenomic.org/releases/latest/" ./genome_updater.sh -d refseq,genbank -g bacteria,archaea
```

## Reports

### assembly accessions

The `-u` parameter activates the output of a list of updated assembly accessions for entries where all files have been successfully downloaded. The file `{timestamp}_assembly_accession.txt` contains the following tab-separated fields:

    Added [A] or Removed [R], assembly accession, url

Example:

    A	GCF_000146045.2	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/146/045/GCF_000146045.2_R64
    A	GCF_000002515.2	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/002/515/GCF_000002515.2_ASM251v1
    R	GCF_000091025.4	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/091/025/GCF_000091025.4_ASM9102v4

### sequence accessions

The `-r` parameter activates the output of a list of updated sequence accessions for entries for which all files have been successfully downloaded. This option is only available when the file type contains `assembly_report.txt` . The file `{timestamp}_sequence_accession.txt` contains the following tab-separated fields:

    Added [A] or Removed [R], assembly accession, genbank accession, refseq accession, sequence length, taxonomic id

Example:

    A	GCA_000243255.1	CM001436.1	NZ_CM001436.1	3200946	937775
    R	GCA_000275865.1	CM001555.1	NZ_CM001555.1	2475100	28892

- Note: if genome_updater breaks or does not finish completely, some files may be missing from the assembly and sequence accession reports.

### URLs (and files)

The `-p` parameter activates the output of a list of failed and successfully downloaded URLs to the files `{timestamp}_url_downloaded.txt` and `{timestamp}_url_failed.txt`. The failed list will only be complete if the command runs to completion without errors or interruptions.

To obtain a list of successfully downloaded files from this report, use the command below to get only new files after updating.

```bash
sed 's#.*/##' {timestamp}_url_list_downloaded.txt   
#or
find output_folder/version/files/ -type f
```

## Top assemblies

The `-A`  option will select the 'best' assemblies for each taxonomic node (leaf or specific rank) according to four categories (A–D), in order of importance:

    A) refseq Category: 
        1) reference genome
        2) na
    B) Assembly level:
        3) Complete Genome
        4) Chromosome
        5) Scaffold
        6) Contig
    C) Relation to type material:
        7) assembly from type material
        8) assembly from synonym type material
        9) assembly from pathotype material
        10) assembly designated as neotype
        11) assembly designated as reftype
        12) ICTV species exemplar
        13) ICTV additional isolate
    D) Date:
        14) Most recent first


## `genome_updater -h`

```

┌─┐┌─┐┌┐┌┌─┐┌┬┐┌─┐    ┬ ┬┌─┐┌┬┐┌─┐┌┬┐┌─┐┬─┐
│ ┬├┤ ││││ ││││├┤     │ │├─┘ ││├─┤ │ ├┤ ├┬┘
└─┘└─┘┘└┘└─┘┴ ┴└─┘────└─┘┴  ─┴┘┴ ┴ ┴ └─┘┴└─
                                     v0.7.0 

Database options:
 -d Database (comma-separated entries)
        [genbank, refseq]

Organism options:
 -g Organism group(s) (comma-separated entries, empty for all)
        [archaea, bacteria, fungi, human, invertebrate, metagenomes, 
        other, plant, protozoa, vertebrate_mammalian, vertebrate_other, viral]
        Default: ""
 -T Taxonomic identifier(s) with optional negation using the ^ prefix (comma-separated entries, empty for all).
        Example: "543,^562" (for -M ncbi) or "f__Enterobacteriaceae,^s__Escherichia coli" (for -M gtdb)
        Default: ""

File options:
 -f file type(s) (comma-separated entries)
        [genomic.fna.gz, assembly_report.txt, protein.faa.gz, genomic.gbff.gz]
        More formats at https://ftp.ncbi.nlm.nih.gov/genomes/all/README.txt
        Default: assembly_report.txt

Filter options:
 -c refseq category (comma-separated entries, empty for all)
        [reference genome, na]
        Default: ""
 -l assembly level (comma-separated entries, empty for all)
        [Complete Genome, Chromosome, Scaffold, Contig]
        Default: ""
 -D Start date (>=), based on the sequence release date. Format YYYYMMDD.
        Default: ""
 -E End date (<=), based on the sequence release date. Format YYYYMMDD.
        Default: ""
 -F Custom filter for the assembly summary. 
        Examples:
          Single: -F '$14 = "Full"'
          Multi:  -F '($2 == "PRJNA12377" || $2 == "PRJNA670754") && $4 != "Partial"'
          Regex:  -F '$8 ~ /bacterium/'
          Whole-file: -F '$0 ~ "plasmid"'
        Uses awk syntax: $ for column index, || "or", && "and", ! "not", parentheses for nesting. Case sensitive.
        Columns info at https://ftp.ncbi.nlm.nih.gov/genomes/README_assembly_summary.txt
        Default: ""

Taxonomy options:
 -M Taxonomy. gtdb keeps only assemblies in the latest GTDB release. ncbi keeps only latest assemblies (version_status=latest). 
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
        Default: 5
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

[1] https://ftp.ncbi.nlm.nih.gov/genomes/

[2] O. Tange (2018): GNU Parallel 2018, March 2018, https://doi.org/10.5281/zenodo.1146014.
