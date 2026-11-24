#!/bin/bash
# Kraken2 read-contamination screen of the sequencing reads (EFSA WGS statement 2024, section 2.2.2).
# Submit from the microbacterium_analysis folder:   mkdir -p kraken2_results && bsub < run_kraken2.sh
#
#BSUB -J kraken2
#BSUB -q short
#BSUB -n 8
#BSUB -R "span[hosts=1]"
#BSUB -R "rusage[mem=16384]"
#BSUB -M 16384
#BSUB -o kraken2_results/kraken2.%J.out
#BSUB -e kraken2_results/kraken2.%J.err

set -euo pipefail
cd "$LS_SUBCWD" 2>/dev/null || cd "$(dirname "$0")"

OUT=kraken2_results
DBDIR=$PWD/kraken2_db_standard8
# Pre-built Kraken2 Standard-8 index (8 GB cap; RefSeq archaea, bacteria, viral, plasmid, human, UniVec_Core).
# Check https://benlangmead.github.io/aws-indexes/k2 for the newest "Standard-8" file and edit the URL if needed.
DBURL=https://genome-idx.s3.amazonaws.com/kraken/k2_standard_08gb_20240904.tar.gz
R1=reads_R1.fastq.gz
R2=reads_R2.fastq.gz
THREADS=8
CONF=0.0     # Kraken2 default, kept explicit

mkdir -p "$OUT"
module load Kraken2/2.1.2-gompi-2022a

# ---- database (downloaded once) ----
if [ ! -s "$DBDIR/hash.k2d" ]; then
  mkdir -p "$DBDIR"
  echo "Downloading database: $DBURL"
  wget -q -O "$DBDIR/db.tar.gz" "$DBURL"
  tar -xzf "$DBDIR/db.tar.gz" -C "$DBDIR"
  rm -f "$DBDIR/db.tar.gz"
  date +%Y-%m-%d > "$DBDIR/DOWNLOAD_DATE.txt"
fi
[ -s "$DBDIR/hash.k2d" ] || { echo "ERROR: database not found in $DBDIR"; exit 1; }

# ---- run ----
kraken2 --db "$DBDIR" --threads $THREADS --paired --gzip-compressed \
        --confidence $CONF --use-names \
        --report "$OUT/kraken2_report.txt" \
        --output "$OUT/kraken2_reads_classification.txt" \
        "$R1" "$R2" 2> "$OUT/kraken2_stderr.txt"

# ---- summary ----
REP="$OUT/kraken2_report.txt"
TOTAL=$(awk '$4=="U"||($4=="R" && $6=="root"){s+=$2} END{print s}' "$REP")
UNCL=$(awk '$4=="U"{print $2}' "$REP")
{
  echo "Kraken2 read-contamination screen"
  echo "Run date            : $(date +%Y-%m-%d)"
  echo "Kraken2 version     : $(kraken2 --version | head -1)"
  echo "Database            : $DBURL"
  echo "Database downloaded : $(cat $DBDIR/DOWNLOAD_DATE.txt 2>/dev/null)"
  echo "Command             : kraken2 --db <Standard-8> --threads $THREADS --paired --gzip-compressed --confidence $CONF --use-names $R1 $R2"
  echo "Read pairs analysed : $TOTAL"
  echo "Unclassified pairs  : $UNCL ($(awk -v u=$UNCL -v t=$TOTAL 'BEGIN{printf "%.2f",100*u/t}')%)"
  echo
  echo "Top 15 species (percent of read pairs | pairs in clade | species):"
  awk -F'\t' '$4=="S"{gsub(/^ +/,"",$6); printf "%s%%\t%s\t%s\n",$1,$2,$6}' "$REP" | sort -t$'\t' -k2,2nr | head -15
  echo
  echo "Genus Microbacterium:"
  awk -F'\t' '{n=$6; gsub(/^ +/,"",n)} n=="Microbacterium"{printf "%s%%\t%s\t%s\n",$1,$2,n}' "$REP"
} > "$OUT/kraken2_summary.txt"
cat "$OUT/kraken2_summary.txt"
echo "DONE"
