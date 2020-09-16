#!/bin/bash
set -euxo pipefail
rm -rf tests/tst_*
threads=${1:-1}
####################### Basic tests

# Download
out_direct="tests/tst_fungi_refseq_cg"
out_mod="tests/tst_fungi_refseq_cg_mod"
./genome_updater.sh -o "${out_direct}" -f "assembly_report.txt" -g "fungi" -d "refseq" -l "Complete Genome" -u -r -p -m -b v1 -t ${threads}
# Donwload with external assembly summary (outdated entry, extra entries, deleted entries)
./genome_updater.sh -o "${out_mod}" -f "assembly_report.txt" -g "fungi" -d "refseq" -l "Complete Genome" -u -r -p -m -b v1 -e tests/assembly_summary_fungi_refseq_cg_mod.txt -t ${threads}
# Fix + Update (modified to the "standard")
find "${out_mod}"/v1/files/ -xtype f | shuf -n 2 | xargs rm
touch "${out_mod}"/v1/files/random_file_1
touch "${out_mod}"/v1/files/random_file_2
./genome_updater.sh -o "${out_mod}" -f "assembly_report.txt" -g "fungi" -d "refseq" -l "Complete Genome" -u -r -p -m -b v2 -x -t ${threads}

# Fix (delete random files)
find "${out_mod}"/v2/files/ -xtype f | shuf -n 2 | xargs rm
./genome_updater.sh -o "${out_mod}" -f "assembly_report.txt" -i -u -r -p -m -t ${threads}

# Comparisons
diff <(sort "${out_direct}"/v1/updated_assembly_accession.txt) <(sort "${out_mod}"/v2/updated_assembly_accession.txt)
diff <(sort "${out_direct}"/v1/updated_sequence_accession.txt) <(sort "${out_mod}"/v2/updated_sequence_accession.txt)
diff <(find "${out_direct}"/v1/files/ -xtype f -printf "%f\n" | sort) <(find "${out_mod}"/v2/files/ -xtype f -printf "%f\n" | sort )

####################### All fail
out_fail="tests/tst_failed"
./genome_updater.sh -o "${out_fail}" -e "tests/assembly_summary_fungi_refseq_cg_err.txt" -m -b v1 -t ${threads} -p
# test if folder is empty
test $(find "${out_fail}/v1/files/" -xtype f | wc -l) -eq 0
# test if both are reported as failed
test $(cat "${out_fail}/v1/"*_url_failed.txt | wc -l) -eq 2
# and none as successful
test $(cat "${out_fail}/v1/"*_url_downloaded.txt | wc -l) -eq 0


####################### Species tests
# Species tests (genbank)
out_all="tests/tst_species"
out_1="tests/tst_species1686310"
out_2="tests/tst_species64571"
./genome_updater.sh -o "${out_all}" -g "species:1686310,64571" -d "genbank" -f "assembly_report.txt" -m -b v1 -t ${threads}
# download them separated
./genome_updater.sh -o "${out_1}" -g "species:1686310" -d "genbank" -f "assembly_report.txt" -m -b v1 -t ${threads}
./genome_updater.sh -o "${out_2}" -g "species:64571" -d "genbank" -f "assembly_report.txt" -m -b v1 -t ${threads}
# check if both runs have the same files
diff <(find "${out_all}"/v1/files/ -xtype f -printf "%f\n" | sort) <(find "${out_1}"/v1/files/ "${out_2}"/v1/files/ -xtype f  -printf "%f\n" | sort)


####################### Taxid tests
# Taxids tests (multi file)
out_all="tests/tst_taxids"
out_1="tests/tst_taxids1910924"
out_2="tests/tst_taxids2493627"
./genome_updater.sh -o "${out_all}" -g "taxids:1910924,2493627" -d "refseq" -f "genomic.fna.gz,assembly_report.txt" -m -b v1 -t ${threads}
# download them separated
./genome_updater.sh -o "${out_1}" -g "taxids:1910924" -d "refseq" -f "genomic.fna.gz,assembly_report.txt" -m -b v1 -t ${threads}
./genome_updater.sh -o "${out_2}" -g "taxids:2493627" -d "refseq" -f "genomic.fna.gz,assembly_report.txt" -m -b v1 -t ${threads}
# check if both runs have the same files
diff <(find "${out_all}"/v1/files/ -xtype f -printf "%f\n" | sort) <(find "${out_1}"/v1/files/ "${out_2}"/v1/files/ -xtype f  -printf "%f\n" | sort)


#####################
#GCF_014522265.1	PRJNA224116	SAMN05607105		na	237610	237610	Pseudomonas psychrotolerans	strain=KNF2016		latest	Complete Genome	Major	Full2020/09/10	ASM1452226v1	Korea University	GCA_014522265.1	identical	na


echo ""
echo "All tests finished successfully"
