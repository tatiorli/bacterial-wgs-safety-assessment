#!/bin/bash
#BSUB -J antismash_mibig31
#BSUB -q short
#BSUB -n 8
#BSUB -R "rusage[mem=4000]"
#BSUB -R "span[hosts=1]"
#BSUB -M 4000
#BSUB -W 02:00
#BSUB -o antismash_mibig31.%J.out
#BSUB -e antismash_mibig31.%J.err

# Second antiSMASH run with MIBiG 3.1 as the KnownClusterBlast reference.
# Everything goes to NEW folders; the original databases and antismash_out are not modified.

set -euo pipefail

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate antismash
export PYTHONNOUSERSITE=1

ORIG_DB="$CONDA_PREFIX/lib/python3.11/site-packages/antismash/databases"
NEW_DB=antismash_db_mibig31
GENOME=Microbacterium_arborescens_spp._assembled_genome.fasta
OUTDIR=antismash_out_mibig31

# 1. new database folder: symlinks to all original databases except knownclusterblast
mkdir -p "$NEW_DB"
for d in "$ORIG_DB"/*; do
  name=$(basename "$d")
  if [ "$name" != "knownclusterblast" ] && [ ! -e "$NEW_DB/$name" ]; then
    ln -s "$d" "$NEW_DB/$name"
  fi
done

# 2. MIBiG 3.1 KnownClusterBlast data in the new folder
python build_mibig31_db.py mibig_prot_seqs_3.1.fasta mibig_json_3.1 "$NEW_DB"
diamond makedb --in "$NEW_DB/knownclusterblast/3.1/proteins.fasta" \
               --db "$NEW_DB/knownclusterblast/3.1/proteins" --quiet

echo "Start: $(date)"
echo "antiSMASH version: $(antismash --version)"
echo "KnownClusterBlast reference: MIBiG 3.1 ($NEW_DB)"

antismash \
  --taxon bacteria \
  --genefinding-tool prodigal \
  --databases "$NEW_DB" \
  --cb-general --cb-knownclusters --cb-subclusters \
  --asf --rre \
  --cpus 8 \
  --output-dir "$OUTDIR" \
  --output-basename Microbacterium_arborescens_mibig31 \
  "$GENOME"

test -s "$OUTDIR/index.html"
echo "Regions found: $(ls "$OUTDIR"/*region*.gbk 2>/dev/null | wc -l)"
echo "SUCCESS: antiSMASH (MIBiG 3.1) finished $(date)"
