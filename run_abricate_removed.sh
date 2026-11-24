#!/bin/bash
# ABRicate (4 AMR databases + VFDB, --minid 80 --mincov 1) on the contigs REMOVED by the post-assembly filter (NODE_10 to NODE_270 of the SPAdes rerun).
# Same settings as run_abricate_lowcov.sh (EFSA WGS statement 2024, section 2.5.3). Does not touch the earlier results.
# Submit from the microbacterium_analysis folder:   mkdir -p abricate_removed_contigs && bsub < run_abricate_removed.sh
# (the "abricate" conda environment must be active when you submit)
#
#BSUB -J abricate_removed
#BSUB -q short
#BSUB -n 4
#BSUB -R "rusage[mem=1024]"
#BSUB -M 1024
#BSUB -o abricate_removed_contigs/abricate_removed.%J.out
#BSUB -e abricate_removed_contigs/abricate_removed.%J.err

set -uo pipefail
module purge 2>/dev/null || true
unset PERL5LIB PERL_LOCAL_LIB_ROOT PERL_MB_OPT PERL_MM_OPT PERLLIB
cd "$LS_SUBCWD" 2>/dev/null || cd "$(dirname "$0")"

OUT=abricate_removed_contigs
ALL=spades_rerun/spades_output/contigs.fasta
MINID=80
MINCOV=1
DBS="ncbi card argannot resfinder vfdb"
mkdir -p "$OUT"
which abricate && abricate --version || { echo "ERROR: abricate not working (activate the abricate conda env before bsub)"; exit 1; }

# contigs NODE_1..9 = submitted assembly; NODE_10 onwards = removed by the filter
awk '/^>/{split($1,a,"_"); keep=(a[2]+0>=10)} keep' "$ALL" > $OUT/removed_contigs.fasta
echo "Removed contigs: $(grep -c '>' $OUT/removed_contigs.fasta); total bp: $(grep -v '>' $OUT/removed_contigs.fasta | tr -d '\n' | wc -c)"

for db in $DBS; do
  abricate --db $db --minid $MINID --mincov $MINCOV --threads 4 $OUT/removed_contigs.fasta > $OUT/abricate_${db}_removed_contigs.txt || { echo "ERROR: abricate failed for $db"; exit 1; }
done

{
  echo "ABRicate on the contigs removed by the post-assembly filter"
  echo "Run date : $(date +%Y-%m-%d)"
  echo "Version  : $(abricate --version)"
  echo "Command  : abricate --db <db> --minid $MINID --mincov $MINCOV removed_contigs.fasta"
  echo "Input    : NODE_10 to NODE_270 of the SPAdes rerun (spades_rerun/spades_output/contigs.fasta)"
  abricate --list | awk 'NR==1 || /ncbi|card|argannot|resfinder|vfdb/'
} > $OUT/abricate_run_info.txt

SUM=$OUT/abricate_removed_summary.txt
{
  echo "Hits per database on the removed contigs (identity >= $MINID, coverage >= $MINCOV%):"
  for f in $OUT/abricate_*_removed_contigs.txt; do
    n=$(tail -n +2 "$f" | wc -l)
    full=$(tail -n +2 "$f" | awk -F'\t' '$10>=70 && $11>=80' | wc -l)
    echo "$(basename $f): total=$n   meeting 80% identity / 70% coverage=$full   fragments (<70% coverage)=$((n-full))"
  done
  echo; echo "All hits (database, gene, contig, position, coverage, identity, product, accession):"
  for f in $OUT/abricate_*_removed_contigs.txt; do
    tail -n +2 "$f" | awk -F'\t' -v d=$(basename $f) '{print d"\t"$6"\t"$2"\t"$3"-"$4"\tcov="$10"\tid="$11"\t"$14"\t"$13}'
  done
} > $SUM
cat $SUM
echo DONE
