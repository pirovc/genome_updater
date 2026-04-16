# genome_updater [![Build Status](https://app.travis-ci.com/pirovc/genome_updater.svg?branch=main)](https://app.travis-ci.com/pirovc/genome_updater) [![codecov](https://codecov.io/gh/pirovc/genome_updater/branch/master/graph/badge.svg)](https://codecov.io/gh/pirovc/genome_updater) [![Anaconda-Server Badge](https://anaconda.org/bioconda/genome_updater/badges/downloads.svg)](https://anaconda.org/bioconda/genome_updater) [![install with bioconda](https://img.shields.io/badge/install%20with-bioconda-brightgreen.svg?style=flat)](http://bioconda.github.io/recipes/genome_updater/README.html)

genome_updater is a bash script that downloads and updates (non-redundant) snapshots of the NCBI Genomes repository (RefSeq/GenBank) [[1](https://ftp.ncbi.nlm.nih.gov/genomes/)] with advanced filters, detailed logs and reports, file integrity checks (MD5, gzip), NCBI taxonomy and GTDB [[2](https://gtdb.ecogenomic.org/)] integration and support for parallel [[3](https://doi.org/10.5281/zenodo.1146014)] downloads. genome_updater uses the [assembly_summary.txt](https://ftp.ncbi.nlm.nih.gov/genomes/README_assembly_summary.txt) to retrieve data.

## Quick usage guide

### Download

```bash
# Download script, allow execution
wget --quiet --show-progress https://raw.githubusercontent.com/pirovc/genome_updater/master/genome_updater.sh
chmod +x genome_updater.sh

# Download archaeal complete genome sequences from RefSeq (-t parallel downloads, -G check gz integrity)
./genome_updater.sh -o "arc_refseq_cg" -d "refseq" -g "archaea" -l "complete genome" -f "genomic.fna.gz" -t 12 -G
```

### Update

Some time later, get a up-to-date version from NCBI, downloading only newly added files:

```bash
# Check if updates are available with a dry-run (-k)
./genome_updater.sh -o "arc_refseq_cg" -k
# Execute update
./genome_updater.sh -o "arc_refseq_cg" -G
```

- Note that boolean flags are not kept between versions (e.g. `-G`) and have to be repeated on the update command to be included.

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

- genome_updater requires bash version 4 and above.
- genome_updater is portable and depends on the GNU Core Utilities + few additional tools (`awk` `bc` `find` `fmt` `gzip` `join` `md5sum` `parallel` `sed` `tar` `wget` and optionally `curl`) which are commonly available and installed in most distributions.
- If you are not sure if you have them all, just run `genome_updater.sh` and it will tell you if something is missing (otherwise the it will show the help page).

To test if all genome_updater functions are running properly on your system:

```bash
git clone --recurse-submodules https://github.com/pirovc/genome_updater.git
cd genome_updater
tests/test.sh
```

## Parameters

```
./genome_updater -h

┌─┐┌─┐┌┐┌┌─┐┌┬┐┌─┐    ┬ ┬┌─┐┌┬┐┌─┐┌┬┐┌─┐┬─┐
│ ┬├┤ ││││ ││││├┤     │ │├─┘ ││├─┤ │ ├┤ ├┬┘
└─┘└─┘┘└┘└─┘┴ ┴└─┘────└─┘┴  ─┴┘┴ ┴ ┴ └─┘┴└─
                                     v0.8.0 

Source:
 -d Database(s) (comma-separated, mandatory)
        Options: "genbank, refseq"
        Default: ""
 -f File type(s) to download (comma-separated, mandatory)
        Options: "genomic.fna.gz, assembly_report.txt, protein.faa.gz, genomic.gbff.gz, ..." all available formats
        are described at https://ftp.ncbi.nlm.nih.gov/genomes/all/README.txt
        Default: "assembly_report.txt"

Organism/Taxa:
 -g Organism group(s) (comma-separated, empty for all)
        Options: "archaea, bacteria, fungi, human, invertebrate, metagenomes, other, plant, protozoa,
        vertebrate_mammalian, vertebrate_other, viral"
        Default: ""
 -T Taxonomic group(s) (comma-separated, empty for all)
        Optional negation using the ^ prefix.
        Example: "543,^562" (for -M ncbi) or "f__Enterobacteriaceae,^s__Escherichia coli" (for -M gtdb)
        Default: ""

Filter:
 -c RefSeq category (comma-separated, empty for all)
        Options: "reference genome, na"
        Default: ""
 -l Assembly level (comma-separated, empty for all)
        Options: "Complete Genome, Chromosome, Scaffold, Contig"
        Default: ""
 -D Start date (empty for no filter)
        Keep assemblies with sequence release date greater then or equal (>=) to value. Format YYYYMMDD.
        Default: ""
 -E End date (empty for no filter)
        Keep assemblies with sequence release date less then or equal (<=) to value. Format YYYYMMDD.
        Default: ""
 -F Custom assembly summary filter (empty for no filter)
        Use awk syntax, e.g.: $ for column index, || "or", && "and", ! "not", parentheses for nesting. Case
        sensitive. Columns info at https://ftp.ncbi.nlm.nih.gov/genomes/README_assembly_summary.txt
        Examples:
          Single: -F '$14 == "Full"'
          Multi: -F '($2 == "PRJNA12377" || $2 == "PRJNA670754") && $4 != "Partial"'
          Regex: -F '$8 ~ /bacterium/'
          Whole-file: -F '$0 ~ "plasmid"'
        Default: ""

Taxonomy:
 -M Taxonomy
        "gtdb[-*]" filters assemblies present in the GTDB version, which contains archaea and bacteria only. "gtdb"
        uses latest GTDB release. "ncbi" filters latest assemblies (version_status=latest). This option changes
        the behavior of -T -A -a.
        Options: "ncbi, gtdb, gtdb-80, gtdb-83, gtdb-89, gtdb-232, gtdb-214.1, gtdb-207, gtdb-202, gtdb-86.2,
        gtdb-95, gtdb-226, gtdb-220"
        Default: "ncbi"
 -A Top assemblies (0 for all)
        Option to keep a limited number of assemblies for each taxa leaf nodes. Selection by tax. ranks are supported
        in the format "rank:number", e.g.: "genus:3" to keep only 3 assemblies for each genus. Top choice based
        on sorted fields: RefSeq Category, Assembly level, Relation to type material, Date (most recent).
        Options (ranks): "species, genus, family, order, class, phylum, domain"
        Default: 0
 -a (boolean flag)
        Download and keep taxonomy database files in the output folder

Run:
 -k Dry-run mode
        Only checks for possible actions, no real data is downloaded, deleted or updated
 -i Fix mode
        Re-download incomplete or failed data from a previous run. Can also be used to change files (-f).
 -t Threads
        Number of processes to parallelize downloads and some file operations
        Default: 1
 -L Downloader program
        Options: "wget, curl"
        Default: "wget"
 -G gzip check (boolean flag)
        Check integrity of downloaded gzipped files with "gzip -t". Downloaded files are removed if test fail.
 -m MD5 check (boolean flag)
        Download, compute and check the MD5 checksum for all downloaded files. Downloaded files are removed if
        checksum can be downloaded but does not match.

Output:
 -o Output directory
        Default: "./tmp.XXXXXXXXXX" (random folder)
 -b Version label
        Name for the downloaded version. Will generate a directory inside the output directory (-o).
        Default: "YYYY-MM-DD_HH-MM-SS" (current timestamp)
 -N Files directory structure
        The "split" structure store files in sub-directories based on the assembly accession, e.g.:
        files/GCF/000/499/605/GCF_000499605.1_genomic.fna.gz. The "flat" will store everything under one dir,
        e.g.: files/GCF_000499605.1_genomic.fna.gz
        Options: "split, flat"
        Default: "split"

Report:
 -u Assembly accession report (boolean flag)
        Generate a report (*_assembly_accession.txt) with updated assembly accessions with the fields (tab-separated):
        Added/Removed, assembly accession, url
 -r Sequence accession report (boolean flag)
        Generate a report (*_sequence_accession.txt) with updated sequence accessions with the fields (tab-separated):
        Added/Removed, assembly accession, genbank accession, refseq accession, sequence length, taxid. Only
        available when file format (-f) "assembly_report.txt" is selected and successfully downloaded.
 -p URL report (boolean flag)
        Generate two files with successful and failed URLs (url_downloaded.txt, url_failed.txt)

Misc.:
 -e Local assembly_summary.txt
        Use provided "assembly_summary.txt" instead of downloading. Mutually exclusive with -d and -g
        Default: ""
 -B Alternative version label
        Use a previous version label instead of the latest as base version. Can be also used to rollback to an
        older version or to create multiple branches from a base version. Mutually exclusive with -i.
        Default: ""
 -H Link mode
        Change link type for files kept between versions. Hard links save inodes (useful on HPC systems) and allow
        version deletion.
        Options: "hard, soft"
        Default: "hard"
 -R Retry batches
        Number of attempts to retry failed downloads in batches.
        Default: "5"
 -n Conditional exit status
        Change exit code based on number of failures accepted, otherwise will Exit Code = 1. For example: -n 10
        will exit code 1 if 10 or more files failed to download
        Options: integer for file number, float for percentage, 0 = off
        Default: "0"
 -x Delete extra files (boolean flag)
        Search and delete files that do not belong to the current version inside "files/" directory.
 -s Silent output
 -w Silent output with download progress
 -V Verbose log
 -Z Print debug information and run in debug mode
```

## Details on local updates

When updating an existing local repository:

- Newly added sequences will be downloaded, creating a new version.
  - `-b` can be used to change the version name, otherwise will use the current timestamp by default.
- Removed or old sequences will be retained, but not transferred to the new version.
- Repeated/unchanged files are linked to the new version.
  - Hard links are used by default, soft links can be enforced with `-H soft`.
- Arguments can be added to or changed.
  - Based on the quick start example, use the command `./genome_updater.sh -o "arc_refseq_cg" -t 2` to specify a different number of threads, or `./genome_updater.sh -o "arc_refseq_cg" -l ""` to remove the `complete genome` filter.
- The file `history.tsv` will be created in the output folder (`-o`), tracking the versions and arguments used. Please note that boolean flags/arguments are not tracked (e.g. `-m`).
  - The `history.tsv` has the columns (tab-separated):
    - `current_label`: empty for new downloads, or refering to previous version
    - `new_label`: the current label. It is empty for fix runs `-i`
    - `timestamp`: time and date of the execution
    - `assembly_summary_entries`: number of assemblies for the `new_label` version
    - `arguments`: used arguments without boolean flags

## Complete examples

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

### All genomes from the latests GTDB release

```bash 
./genome_updater.sh -d "refseq,genbank" -g "archaea,bacteria" -f "genomic.fna.gz" -o "GTDB_complete" -M "gtdb" -t 12 -m
```

### All genomes from a specific GTDB release

```bash 
./genome_updater.sh -d "refseq,genbank" -g "archaea,bacteria" -f "genomic.fna.gz" -o "GTDB_R220_complete" -M "gtdb-220" -t 12 -m
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
# Defaults: retries=3 timeout=120
retries=10 timeout=600 ./genome_updater.sh -g "fungi" -o fungi -t 12 -f "genomic.fna.gz,assembly_report.txt" -L curl -R 10
```

### Use a local taxdump file

```bash 
new_taxdump_file="my/local/new_taxdump.tar.gz" ./genome_updater.sh -T 562 -o 562assemblies -t 12
```

- Note that the [new_taxdump](https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/new_taxdump/) is required, not the more common `taxdump.tar.gz`.

### Alternative download URL

```bash
# NCBI
ncbi_base_url="https://ftp.ncbi.nih.gov/" ./genome_updater.sh -d refseq -g bacteria

# GTDB
gtdb_base_url="https://data.ace.uq.edu.au/public/gtdb/data/releases/" ./genome_updater.sh -d refseq,genbank -g bacteria,archaea
```

## Reports

### assembly accessions (-u)

The `-u` parameter activates the output of a list of updated assembly accessions for entries where all files have been successfully downloaded. The file `{timestamp}_assembly_accession.txt` contains the following tab-separated fields: `Added/Removed [A/R]`, `assembly accession`, `url`

Example:

```txt
A	GCF_000146045.2	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/146/045/GCF_000146045.2_R64
A	GCF_000002515.2	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/002/515/GCF_000002515.2_ASM251v1
R	GCF_000091025.4	ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/091/025/GCF_000091025.4_ASM9102v4
```

### sequence accessions (-r)

The `-r` parameter activates the output of a list of updated sequence accessions for entries for which all files have been successfully downloaded. This option is only available when the file type contains `assembly_report.txt` . The file `{timestamp}_sequence_accession.txt` contains the following tab-separated fields:  `Added/Removed [A/R]`, `assembly accession`, `genbank accession`, `refseq accession`, `sequence length`, `taxonomic id`

Example:

```txt
A	GCA_000243255.1	CM001436.1	NZ_CM001436.1	3200946	937775
R	GCA_000275865.1	CM001555.1	NZ_CM001555.1	2475100	28892
```

- Note: if the run breaks or does not finish successfuly, some files may be missing from the assembly and sequence accession reports.

### URLs (-p)

The `-p` parameter activates the output of a list of failed and successfully downloaded URLs to the files `{timestamp}_url_downloaded.txt` and `{timestamp}_url_failed.txt`. The failed list will only be complete if the command runs to completion without errors or interruptions.

## Top assemblies (-A)

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

## References:

[1] https://ftp.ncbi.nlm.nih.gov/genomes/

[2] https://gtdb.ecogenomic.org/

[3] O. Tange (2018): GNU Parallel 2018, March 2018, https://doi.org/10.5281/zenodo.1146014.
