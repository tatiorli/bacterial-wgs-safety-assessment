#!/bin/bash
# Do the reads still link or extend the contig ends?  (evidence for "cannot be closed with these reads")
# Maps the reads back to the assembly, then reports for every contig end: read-pairs bridging to other contigs,
# soft-clipped/unpaired reads, and depth in the last 500 bp. Also exports files to look at in IGV and Bandage.
# Submit from the microbacterium_analysis folder:   mkdir -p contig_ends && bsub < check_contig_ends.sh
#
#BSUB -J contig_ends
#BSUB -q short
#BSUB -n 8
#BSUB -R "span[hosts=1]"
#BSUB -R "rusage[mem=1536]"
#BSUB -M 1536
#BSUB -o contig_ends/contig_ends.%J.out
#BSUB -e contig_ends/contig_ends.%J.err

set -euo pipefail
cd "$LS_SUBCWD" 2>/dev/null || cd "$(dirname "$0")"
OUT=contig_ends
ASM=Microbacterium_arborescens_spp._assembled_genome.fasta
R1=reads_R1.fastq.gz; R2=reads_R2.fastq.gz

module purge
module load Bowtie2/2.5.1-GCC-12.3.0
bowtie2-build --threads 8 "$ASM" $OUT/asm > $OUT/build.log 2>&1
bowtie2 -x $OUT/asm -1 $R1 -2 $R2 -p 8 --end-to-end --very-sensitive -S $OUT/asm.sam 2> $OUT/mapping_report.txt

module purge
module load SAMtools/1.21-GCC-13.2.0
samtools faidx "$ASM"
samtools sort -@ 8 -o $OUT/asm.sorted.bam $OUT/asm.sam && samtools index $OUT/asm.sorted.bam && rm $OUT/asm.sam

# 1) pairs whose mates map on different contigs (links between contigs), MAPQ>=20
samtools view -q 20 -F 0x904 $OUT/asm.sorted.bam | awk '$7!="=" && $7!="*"{k=($3<$7)?$3"\t"$7:$7"\t"$3; n[k]++} END{for(k in n) print n[k]"\t"k}' \
  | sort -k1,1nr > $OUT/links_between_contigs.tsv

# 2) per contig end: depth in last 500 bp and number of pairs linking out of the contig from that end
samtools depth -a $OUT/asm.sorted.bam > $OUT/depth.tsv
{
 printf "contig\tlength\tmean_depth\tmean_depth_first500\tmean_depth_last500\n"
 while read c l rest; do
   awk -v c=$c -v l=$l 'BEGIN{OFS="\t"} $1==c{t+=$3;n++; if($2<=500){a+=$3;na++} if($2>l-500){b+=$3;nb++}} END{printf "%s\t%d\t%.0f\t%.0f\t%.0f\n",c,l,t/n,a/na,b/nb}' $OUT/depth.tsv
 done < "$ASM.fai"
} > $OUT/depth_at_contig_ends.tsv

# 3) reads with large soft-clips (unmatched sequence) at contig ends, i.e. where the assembly stops but reads continue
samtools view $OUT/asm.sorted.bam | awk '$6 ~ /^[0-9]+S/ || $6 ~ /[0-9]+S$/{print $3}' | sort | uniq -c | sort -k1,1nr > $OUT/softclipped_reads_per_contig.txt

{
 echo "Contig links (pairs, contigA, contigB):"; cat $OUT/links_between_contigs.tsv; echo
 echo "Depth at contig ends:"; column -t $OUT/depth_at_contig_ends.tsv; echo
 echo "Mapping report:"; cat $OUT/mapping_report.txt
} > $OUT/contig_ends_summary.txt
cat $OUT/contig_ends_summary.txt
echo DONE
