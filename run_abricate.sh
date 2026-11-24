#!/bin/bash
#BSUB -J abricate_rerun
#BSUB -q short
#BSUB -n 4
#BSUB -R "rusage[mem=4000]"
#BSUB -M 4000
#BSUB -W 01:00
#BSUB -o abricate_rerun.%J.out
#BSUB -e abricate_rerun.%J.err

# Setup, once:
#   conda create -n abricate -c conda-forge -c bioconda --solver libmamba abricate=1.0.1
# NOTE: databases are whatever the install ships, so versions will differ from Galaxy (Dec 2024).

set -euo pipefail

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate abricate
export PYTHONNOUSERSITE=1

GENOME=Microbacterium_arborescens_spp._assembled_genome.fasta
OUTDIR=abricate_raw_outputs
mkdir -p "$OUTDIR"

{
  echo "Run date: $(date)"
  echo "ABRicate version: $(abricate --version)"
  echo "Input: $GENOME ($(md5sum "$GENOME" | cut -d' ' -f1))"
  echo "Parameters: --minid 80 --mincov 70"
  echo "Databases:"
  abricate --list
} > "$OUTDIR/abricate_run_info.txt"

for DB in ncbi card argannot resfinder vfdb; do
  # .tab = raw table (header only when there are no hits); .log = database version and "Found N genes"
  abricate --db "$DB" --minid 80 --mincov 70 "$GENOME" \
    > "$OUTDIR/abricate_${DB}.tab" 2> "$OUTDIR/abricate_${DB}.log"
  echo "$DB: $(tail -n +2 "$OUTDIR/abricate_${DB}.tab" | wc -l) hits"
done

abricate --summary "$OUTDIR"/abricate_*.tab > "$OUTDIR/abricate_summary.tab"

echo "SUCCESS: abricate finished $(date)"
