#!/bin/bash
# Run from the microbacterium_analysis folder:   bash submit_bowtie2_tests.sh
# Reference: M. arborescens DSM 20754 (GCA_003339645.1). Submits: 1) index, 2) three Bowtie2 tests (A, B, C), 3) collector.
cd "$(dirname "$0")"
OUT=bowtie2_tests_DSM20754
REF=GCA_003339645.1_ASM333964v1_genomic.fna
mkdir -p $OUT/DSM20754_index

bsub -J bt2_index -q short -n 2 -R "span[hosts=1]" -R "rusage[mem=1024]" -M 1024 \
     -o $OUT/index.%J.out -e $OUT/index.%J.err <<EOT
set -euo pipefail
cd "$PWD"
module purge
module load Bowtie2/2.5.1-GCC-12.3.0
bowtie2-build --threads 2 $REF $OUT/DSM20754_index/DSM20754 > $OUT/bowtie2_build.log 2>&1
grep -c '>' $REF
EOT

bsub -J "bt2_test[1-3]" -w "done(bt2_index)" \
     -o $OUT/test.%J.%I.out -e $OUT/test.%J.%I.err < bowtie2_tests.sh

bsub -J bt2_collect -q short -w "ended(bt2_test)" -o $OUT/collect.%J.out -e $OUT/collect.%J.err <<EOT
cd "$PWD/$OUT"
{
  printf "%-30s %-14s %-22s %-22s\n" "Test" "Overall rate" "Pairs aligned conc. 1x" "Pairs aligned conc. >1x"
  for f in A_*_report.txt B_*_report.txt C_*_report.txt; do
    n=\${f%%_bowtie2_report.txt}
    ov=\$(grep "overall alignment rate" \$f | awk '{print \$1}')
    c1=\$(grep "aligned concordantly exactly 1 time" \$f | sed 's/.*(\(.*\)).*/\1/')
    c2=\$(grep "aligned concordantly >1 times" \$f | sed 's/.*(\(.*\)).*/\1/')
    printf "%-30s %-14s %-22s %-22s\n" "\$n" "\$ov" "\$c1" "\$c2"
  done
} > comparison.txt
cat comparison.txt
EOT
echo "Submitted. Results: $OUT/comparison.txt"
