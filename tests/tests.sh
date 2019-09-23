#!/bin/bash
set -euxo pipefail
rm -rf tests/tst_*
threads=2
####################### Basic tests

# Download
out_direct="tests/tst_fungi_refseq_cg"
out_mod="tests/tst_fungi_refseq_cg_mod"
./genome_updater.sh -o "${out_direct}" -f "assembly_report.txt" -g "fungi" -d "refseq" -l "Complete Genome" -u -r -p -m -b v1 -t ${threads}
# Donwload with external assembly summary (outdated entry, extra entries, deleted entries)
./genome_updater.sh -o "${out_mod}" -f "assembly_report.txt" -g "fungi" -d "refseq" -l "Complete Genome" -u -r -p -m -b v1 -e tests/assembly_summary_fungi_refseq_cg_mod.txt -t ${threads}
# Update (modified to the "standard")
./genome_updater.sh -o "${out_mod}" -f "assembly_report.txt" -g "fungi" -d "refseq" -l "Complete Genome" -u -r -p -m -b v2 -t ${threads}
# Fix (delete random files)
find "${out_mod}"/v2/files/ -type f | shuf -n 2 | xargs rm
./genome_updater.sh -o "${out_mod}" -f "assembly_report.txt" -i -u -r -p -m -t ${threads}

# Comparisons
diff <(sort "${out_direct}"/v1/updated_assembly_accession.txt) <(sort "${out_mod}"/v2/updated_assembly_accession.txt)
diff <(sort "${out_direct}"/v1/updated_sequence_accession.txt) <(sort "${out_mod}"/v2/updated_sequence_accession.txt)
diff <(ls "${out_direct}"/v1/files | sort ) <(ls "${out_mod}"/v2/files | sort )

####################### Taxid tests

# Taxids tests (multi file)
./genome_updater.sh -o tests/tst_taxids -g "taxids:1910924,2493627" -d "refseq" -f "genomic.fna.gz,assembly_report.txt" -m -b v1 -t ${threads}
# download them separated
./genome_updater.sh -o tests/tst_taxids1910924 -g "taxids:1910924" -d "refseq" -f "genomic.fna.gz,assembly_report.txt" -m -b v1 -t ${threads}
./genome_updater.sh -o tests/tst_taxids2493627 -g "taxids:2493627" -d "refseq" -f "genomic.fna.gz,assembly_report.txt" -m -b v1 -t ${threads}
# check if both runs have the same files
diff <(ls tests/tst_taxids/v1/files | sort) <(ls tests/tst_taxids1910924/v1/files tests/tst_taxids2493627/v1/files | sort)

