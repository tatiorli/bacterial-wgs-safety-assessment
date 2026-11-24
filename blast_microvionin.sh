#!/bin/bash
#BSUB -J blast_microvionin
#BSUB -q short
#BSUB -n 4
#BSUB -R "rusage[mem=4000]"
#BSUB -M 4000
#BSUB -W 01:00
#BSUB -o blast_microvionin.%J.out
#BSUB -e blast_microvionin.%J.err

# Input: microvionin_BGC0001669_proteins.faa (all protein sequences of MIBiG BGC0001669, from the MIBiG entry page)
# Setup, once: conda create -n blast -c conda-forge -c bioconda --solver libmamba blast

set -euo pipefail
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate blast
export PYTHONNOUSERSITE=1

QUERY=microvionin_BGC0001669_proteins.faa
SAMPLE=Microbacterium_arborescens_spp._assembled_genome.fasta
REF=GCA_003339645.1_ASM333964v1_genomic.fna
OUT=blast_microvionin
mkdir -p "$OUT"

echo "Start: $(date)"
echo "BLAST: $(tblastn -version | head -1)"
grep -c '>' "$QUERY" | sed 's/^/Query proteins: /'

for G in "$SAMPLE" "$REF"; do
  makeblastdb -in "$G" -dbtype nucl -out "$OUT/db_$(basename "$G")" > /dev/null
  tblastn -query "$QUERY" -db "$OUT/db_$(basename "$G")" -evalue 1e-5 -num_threads 4 \
    -outfmt "6 qseqid sseqid pident length qlen qcovs evalue bitscore sstart send" \
    > "$OUT/tblastn_$(basename "$G").tsv"
  echo "$G: $(wc -l < "$OUT/tblastn_$(basename "$G").tsv") hits (e<1e-5)"
done

echo "SUCCESS: finished $(date)"
