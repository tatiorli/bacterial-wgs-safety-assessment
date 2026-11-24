#!/bin/bash
# ABRicate rerun at the lowest coverage threshold (EFSA WGS statement 2024, section 2.5.3):
# 4 AMR databases + VFDB, --minid 80 --mincov 1 so that fragments (>=80% identity, <70% coverage) are also reported.
# Submit from the microbacterium_analysis folder:   mkdir -p abricate_lowcov && bsub < run_abricate_lowcov.sh
#
#BSUB -J abricate_lowcov
#BSUB -q short
#BSUB -n 4
#BSUB -R "rusage[mem=4096]"
#BSUB -M 4096
#BSUB -o abricate_lowcov/abricate_lowcov.%J.out
#BSUB -e abricate_lowcov/abricate_lowcov.%J.err

set -uo pipefail
cd "$LS_SUBCWD" 2>/dev/null || cd "$(dirname "$0")"

OUT=abricate_lowcov
ASM=Microbacterium_arborescens_spp._assembled_genome.fasta
# Optional: unfiltered SPAdes contigs (to also screen the contigs removed by the post-assembly filter); leave empty to skip.
SPADES_ALL=
MINID=80
MINCOV=1
DBS="ncbi card argannot resfinder vfdb"

mkdir -p "$OUT"
# the "abricate" conda environment must be active when you submit (bsub keeps your environment)
which abricate || { echo "ERROR: abricate not found, run 'conda activate abricate' before bsub"; exit 1; }

run_set () {   # $1 = fasta, $2 = label
  for db in $DBS; do
    abricate --db $db --minid $MINID --mincov $MINCOV --threads 4 "$1" > "$OUT/abricate_${db}_$2.txt"
  done
}
run_set "$ASM" assembly
if [ -n "$SPADES_ALL" ] && [ -s "$SPADES_ALL" ]; then run_set "$SPADES_ALL" all_spades_contigs; fi

{
  echo "ABRicate low-coverage rerun"
  echo "Run date : $(date +%Y-%m-%d)"
  echo "Version  : $(abricate --version)"
  echo "Command  : abricate --db <db> --minid $MINID --mincov $MINCOV <fasta>"
  echo "Databases:"; abricate --list | awk 'NR==1 || /ncbi|card|argannot|resfinder|vfdb/'
} > "$OUT/abricate_run_info.txt"

# ---- summary: hits meeting 80/70, and fragments below 70% coverage ----
SUM="$OUT/abricate_lowcov_summary.txt"
{
  echo "Hits per database (rows in the raw files, excluding header), identity >= $MINID, coverage >= $MINCOV%"
  for f in "$OUT"/abricate_*_assembly.txt; do
    n=$(tail -n +2 "$f" | wc -l)
    full=$(tail -n +2 "$f" | awk -F'\t' '$10>=70 && $11>=80' | wc -l)
    echo "$(basename $f): total=$n   meeting 80% identity / 70% coverage=$full   fragments (<70% coverage)=$((n-full))"
  done
  echo
  echo "Fragments (identity >=80%, coverage <70%), grouped by gene; 2 or more fragments of one gene must be checked for the full gene:"
  for f in "$OUT"/abricate_*_assembly.txt; do
    tail -n +2 "$f" | awk -F'\t' -v d=$(basename $f) '$10<70 && $11>=80{print d"\t"$6"\t"$2"\t"$3"-"$4"\tcov="$10"\tid="$11"\t"$14"\t"$13}'
  done | sort -k2,2
} > "$SUM"
cat "$SUM"
echo DONE
