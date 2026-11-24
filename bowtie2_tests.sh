#!/bin/bash
# Bowtie2 parameter test, one array element per parameter set (called by submit_bowtie2_tests.sh).
# Not meant to be submitted on its own.
#
#BSUB -q short
#BSUB -n 8
#BSUB -R "span[hosts=1]"
#BSUB -R "rusage[mem=1536]"
#BSUB -M 1536

set -euo pipefail
cd "$LS_SUBCWD" 2>/dev/null || cd "$(dirname "$0")"

OUT=bowtie2_tests_DSM20754
IDX=$OUT/DSM20754_index/DSM20754
R1=reads_R1.fastq.gz
R2=reads_R2.fastq.gz
THREADS=8
SAVE_BAM=${SAVE_BAM:-0}      # 1 = also write a sorted BAM (needs SAMtools), default: only the Bowtie2 report

module purge
module load Bowtie2/2.5.1-GCC-12.3.0

case "$LSB_JOBINDEX" in
  1) NAME=A_geneious_like
     DESC="end-to-end, ~95% minimum identity (score-min L,0,-0.3), max insert 500 (reads map 'nearby'), random best hit"
     PARAMS="--end-to-end --sensitive --score-min L,0,-0.3 --maxins 500" ;;
  2) NAME=B_end_to_end_very_sensitive
     DESC="end-to-end, very sensitive, default (permissive) score threshold, max insert 800"
     PARAMS="--end-to-end --very-sensitive --maxins 800" ;;
  3) NAME=C_local_very_sensitive
     DESC="local alignment (soft-clipping), very sensitive-local, max insert 800"
     PARAMS="--local --very-sensitive-local --maxins 800" ;;
  *) echo "bad index $LSB_JOBINDEX"; exit 1 ;;
esac

REPORT=$OUT/${NAME}_bowtie2_report.txt
echo "Test      : $NAME" > "$REPORT"
echo "Settings  : $DESC" >> "$REPORT"
echo "Command   : bowtie2 -x DSM20754 -1 $R1 -2 $R2 -p $THREADS $PARAMS" >> "$REPORT"
echo "Bowtie2   : $(bowtie2 --version | head -1)" >> "$REPORT"
echo "Run date  : $(date +%Y-%m-%d)" >> "$REPORT"
echo "----------" >> "$REPORT"

# mapping (alignments discarded unless SAVE_BAM=1; the Bowtie2 report on stderr has the statistics)
bowtie2 -x "$IDX" -1 "$R1" -2 "$R2" -p $THREADS $PARAMS -S "$OUT/${NAME}.sam" 2>> "$REPORT"

if [ "$SAVE_BAM" = "1" ]; then
  module purge
  module load SAMtools/1.21-GCC-13.2.0
  samtools sort -@ $THREADS -o "$OUT/${NAME}.sorted.bam" "$OUT/${NAME}.sam"
  samtools index "$OUT/${NAME}.sorted.bam"
  samtools flagstat "$OUT/${NAME}.sorted.bam" > "$OUT/${NAME}_flagstat.txt"
fi
rm -f "$OUT/${NAME}.sam"
cat "$REPORT"
