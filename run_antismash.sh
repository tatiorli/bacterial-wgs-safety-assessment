#!/bin/bash
#BSUB -J antismash_run
#BSUB -q short
#BSUB -n 8
#BSUB -R "rusage[mem=4000]"
#BSUB -R "span[hosts=1]"
#BSUB -M 4000
#BSUB -W 02:00
#BSUB -o antismash_run.%J.out
#BSUB -e antismash_run.%J.err

set -euo pipefail

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate antismash
export PYTHONNOUSERSITE=1

GENOME=Microbacterium_arborescens_spp._assembled_genome.fasta
OUTDIR=antismash_out

echo "Start: $(date)"
echo "Host: $(hostname)"
echo "antiSMASH version: $(antismash --version)"
echo "Input: $GENOME"
grep -c '>' "$GENOME" | sed 's/^/Contigs: /'

antismash \
  --taxon bacteria \
  --genefinding-tool prodigal \
  --cb-general --cb-knownclusters --cb-subclusters \
  --asf --rre \
  --cpus 8 \
  --output-dir "$OUTDIR" \
  --output-basename Microbacterium_arborescens \
  "$GENOME"

test -s "$OUTDIR/index.html"
echo "Regions found: $(ls "$OUTDIR"/*region*.gbk 2>/dev/null | wc -l)"
zip -qr antismash_results.zip "$OUTDIR"

echo "SUCCESS: antiSMASH finished $(date)"
