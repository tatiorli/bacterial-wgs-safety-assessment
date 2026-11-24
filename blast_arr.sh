#!/bin/bash
# Is the arr-like gene (Bakta KFAPLB_04590, contig_1:968318-968725, minus strand) a real arr gene?
# ABRicate matched only 129 bp (29.9% coverage, 80.6% identity).
# Compares the gene (translated, tblastx) with all arr reference sequences of the ABRicate CARD and NCBI databases,
# and lists the neighbouring genes (is it next to a mobile element?).
# Submit from the microbacterium_analysis folder:   mkdir -p arr_blast && bsub < blast_arr.sh
#
#BSUB -J blast_arr
#BSUB -q short
#BSUB -n 2
#BSUB -R "rusage[mem=1024]"
#BSUB -M 1024
#BSUB -W 00:30
#BSUB -o arr_blast/blast_arr.%J.out
#BSUB -e arr_blast/blast_arr.%J.err

set -euo pipefail
cd "$LS_SUBCWD" 2>/dev/null || cd "$(dirname "$0")"
OUT=arr_blast
GB=Assembly_annotated_Microbacterium_arborescens_spp.gb
ASM=Microbacterium_arborescens_spp._assembled_genome.fasta
mkdir -p "$OUT"
source "$(conda info --base)/etc/profile.d/conda.sh"
export PYTHONNOUSERSITE=1

# 1) arr reference sequences from the ABRicate databases (same version as the screening, 14 Jan 2025)
conda activate abricate
ABRDB=$(dirname "$(dirname "$(readlink -f "$(which abricate)")")")/db
[ -d "$ABRDB/card" ] || ABRDB=$CONDA_PREFIX/db
for db in card ncbi; do
  awk -v db=$db 'BEGIN{RS=">";ORS=""} NR>1{h=$0; sub(/\n.*/,"",h); l=tolower(h); if((l ~ /(^|[^a-z])arr[-_ 0-9a-z]*/ && l !~ /array|arrb|barr|carr|parr|tarr/) || l ~ /rifampin adp|rifampicin adp|rifamycin adp/) print ">"db"~"$0}' "$ABRDB/$db/sequences"
done > $OUT/arr_references.fasta
echo "arr reference sequences: $(grep -c '>' $OUT/arr_references.fasta)"
grep '>' $OUT/arr_references.fasta | cut -c1-120 > $OUT/arr_references_list.txt
cat $OUT/arr_references_list.txt

# 2) the gene itself, cut from the assembly (NODE_1 968318-968725, minus strand -> reverse complement)
awk '/^>/{p=($1 ~ /^>NODE_1_/); next} p{printf "%s",$0}' "$ASM" > $OUT/node1.seq
{ echo ">KFAPLB_04590_arr-like_NODE_1:968318-968725_revcomp";
  cut -c968318-968725 $OUT/node1.seq | rev | tr 'ACGTacgt' 'TGCAtgca' | fold -w 70; } > $OUT/query_KFAPLB_04590.fna
rm $OUT/node1.seq
echo "Query: $(grep -v '>' $OUT/query_KFAPLB_04590.fna | tr -d '\n' | wc -c) bp"

# 3) tblastx (both sides translated = protein-level identity)
conda activate blast
makeblastdb -in $OUT/arr_references.fasta -dbtype nucl -out $OUT/arr_refdb > /dev/null
tblastx -query $OUT/query_KFAPLB_04590.fna -db $OUT/arr_refdb -evalue 1e-3 -max_hsps 1 \
  -outfmt "6 qseqid sseqid pident length qlen slen qstart qend sstart send evalue bitscore" > $OUT/tblastx_arr_raw.tsv
{
  echo -e "query\tsubject\tprotein_identity_%\taln_len_aa\tquery_len_nt\tsubject_len_nt\tquery_coverage_%\tsubject_coverage_%\tevalue\tbitscore"
  awk -F'\t' '{qc=100*(($8>$7?$8-$7:$7-$8)+1)/$5; sc=100*(($10>$9?$10-$9:$9-$10)+1)/$6; printf "%s\t%s\t%.1f\t%d\t%d\t%d\t%.0f\t%.0f\t%s\t%s\n",$1,$2,$3,$4,$5,$6,qc,sc,$11,$12}' $OUT/tblastx_arr_raw.tsv | sort -t$'\t' -k3,3nr
} > $OUT/tblastx_arr_results.tsv
column -t -s$'\t' $OUT/tblastx_arr_results.tsv | cut -c1-220

# 4) neighbouring genes (+/- 6 CDS) to see whether the gene sits in a mobile-element context
awk '
  /^LOCUS/ {ctg=$2}
  /^     CDS  / {n++; loc[n]=$2; c[n]=ctg}
  /\/locus_tag=/ {split($0,q,"\""); tag[n]=q[2]}
  /\/product=/ {split($0,q,"\""); prod[n]=q[2]}
  END{for(i=1;i<=n;i++) if(tag[i]=="KFAPLB_04590"){for(j=i-6;j<=i+6;j++) if(j>=1 && c[j]==c[i]) printf "%s%s\t%s\t%s\t%s\n",(j==i?"*":" "),c[j],loc[j],tag[j],prod[j]}}' "$GB" > $OUT/neighbouring_genes.tsv
echo; echo "Neighbouring genes (* = arr-like gene):"; cat $OUT/neighbouring_genes.tsv
echo DONE
