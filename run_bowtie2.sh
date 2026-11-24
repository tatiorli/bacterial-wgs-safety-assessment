#!/bin/bash
# Bowtie2 mapping of the paired reads onto the RefSeq chromosome-level genome of the closest strain (SSF12) (mapping rate, per-contig depth/coverage).
# Submit from the microbacterium_analysis folder:   mkdir -p bowtie2_results && bsub < run_bowtie2.sh
#
#BSUB -J bowtie2
#BSUB -q short
#BSUB -n 8
#BSUB -R "span[hosts=1]"
#BSUB -R "rusage[mem=16384]"
#BSUB -M 16384
#BSUB -o bowtie2_results/bowtie2.%J.out
#BSUB -e bowtie2_results/bowtie2.%J.err

set -euo pipefail
cd "$LS_SUBCWD" 2>/dev/null || cd "$(dirname "$0")"

OUT=bowtie2_results
REF=M_arborescens_SSF12_CP128474.1_reference.fasta   # RefSeq chromosome-level genome of strain SSF12 (as used in the report, Figure 3)
R1=reads_R1.fastq.gz
R2=reads_R2.fastq.gz
THREADS=8
PREFIX=$OUT/Microbacterium_arborescens_reads_vs_SSF12

mkdir -p "$OUT"
if [ ! -s "$REF" ]; then
  wget -q -O "$REF" "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=CP128474.1&rettype=fasta&retmode=text"
  head -1 "$REF"
fi
module load Bowtie2/2.5.1-GCC-12.3.0
# samtools is needed for sorting/statistics: if this module name does not exist, run "module avail samtools" and edit.
module load SAMtools 2>/dev/null || echo "WARNING: could not load a SAMtools module; edit the module name"

# ---- index ----
bowtie2-build --threads $THREADS "$REF" "$PREFIX.index" > "$OUT/bowtie2_build.log" 2>&1

# ---- mapping (end-to-end, default --sensitive; paired-end) ----
bowtie2 -x "$PREFIX.index" -1 "$R1" -2 "$R2" -p $THREADS \
        2> "$OUT/bowtie2_mapping_summary.txt" \
  | samtools sort -@ $THREADS -o "$PREFIX.sorted.bam" -
samtools index "$PREFIX.sorted.bam"

# ---- statistics ----
samtools flagstat "$PREFIX.sorted.bam" > "$OUT/flagstat.txt"
samtools coverage "$PREFIX.sorted.bam" > "$OUT/coverage_per_contig.tsv"   # contig, length, mean depth, % covered
samtools depth -a "$PREFIX.sorted.bam" | awk '{s+=$3; n++} END{printf "Mean depth over the whole assembly: %.1f x (%d positions)\n", s/n, n}' > "$OUT/mean_depth.txt"

{
  echo "Bowtie2 mapping"
  echo "Run date  : $(date +%Y-%m-%d)"
  echo "Bowtie2   : $(bowtie2 --version | head -1)"
  echo "Samtools  : $(samtools --version | head -1)"
  echo "Command   : bowtie2 -x <index of $REF> -1 $R1 -2 $R2 -p $THREADS (default --sensitive, end-to-end)"
  echo
  cat "$OUT/bowtie2_mapping_summary.txt"
  echo
  cat "$OUT/mean_depth.txt"
  echo
  column -t "$OUT/coverage_per_contig.tsv"
} > "$OUT/mapping_summary.txt"
cat "$OUT/mapping_summary.txt"
echo DONE
