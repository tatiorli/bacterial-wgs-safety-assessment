#!/bin/bash
# blastn of the 155 bp removed contig NODE_263 (535x coverage, at the rRNA operon junction) against the NCBI nt database.
# Same setup as your working BLAST jobs (Safe_pipeline/verification/blast_agreement/submit_blast_jobs.sh):
#   module BLAST+/2.15.0-gompi-2023a, db /shareDB/blastdb/nt/latest/nt, taxdb.btd/.bti found through BLASTDB (copied into this folder),
#   -use_index false, -max_hsps 1, outfmt 6 std + staxid sskingdoms sscinames sblastnames (+ stitle = description / gene name).
# Submit from the microbacterium_analysis folder:   bsub < Blast_short_contig/run_blast_node263.sh
#
#BSUB -J blast_node263
#BSUB -q short
#BSUB -n 4
#BSUB -R "rusage[mem=16000]"
#BSUB -o Blast_short_contig/blast_node263.%J.out
#BSUB -e Blast_short_contig/blast_node263.%J.err

set -uo pipefail
cd "$LS_SUBCWD" 2>/dev/null || cd "$(dirname "$0")/.."
module purge 2>/dev/null || true
module load BLAST+/2.15.0-gompi-2023a

OUT=Blast_short_contig
QUERY=$OUT/NODE_263_removed_contig.fasta
DB=/shareDB/blastdb/nt/latest/nt
export BLASTDB="$PWD/$OUT${BLASTDB:+:$BLASTDB}"     # folder with taxdb.btd and taxdb.bti
[ -s $OUT/taxdb.btd ] && [ -s $OUT/taxdb.bti ] || { echo "ERROR: taxdb.btd/.bti missing in $OUT"; exit 1; }

echo "Start: $(date)"
blastn -version | head -2
# one search, saved as an ASN.1 archive, then written in the formats we need
blastn -query $QUERY -db $DB -use_index false -evalue 1e-5 -max_target_seqs 100 -max_hsps 1 -num_threads 4 \
       -outfmt 11 -out $OUT/NODE_263_blastn_nt.asn || { echo "ERROR: blastn failed"; exit 1; }

# 1) tabular, with species names (sscinames) and the hit description / gene name (stitle)
{
  echo -e "qseqid\tsseqid\tpident\tlength\tmismatch\tgapopen\tqstart\tqend\tsstart\tsend\tevalue\tbitscore\tstaxid\tsskingdoms\tsscinames\tsblastnames\tstitle"
  blast_formatter -archive $OUT/NODE_263_blastn_nt.asn \
    -outfmt "6 std staxid sskingdoms sscinames sblastnames stitle"
} > $OUT/NODE_263_blastn_nt.tsv
# 2) readable alignments (top 20)
blast_formatter -archive $OUT/NODE_263_blastn_nt.asn -outfmt 0 -num_alignments 20 > $OUT/NODE_263_blastn_nt_alignments.txt

echo "Hits: $(tail -n +2 $OUT/NODE_263_blastn_nt.tsv | wc -l)"
echo "Top 15 hits (identity, aln length, query range, e-value, organism | description):"
tail -n +2 $OUT/NODE_263_blastn_nt.tsv | sort -t$'\t' -k12,12nr | head -15 | awk -F'\t' '{printf "%s%%\t%s\t%s-%s\t%s\t%s | %s\n",$3,$4,$7,$8,$11,$15,substr($17,1,90)}'
echo "Done: $(date)"
