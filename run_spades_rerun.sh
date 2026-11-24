#!/bin/bash
# Re-run SPAdes with the parameters reported in Section 2.3 to recover the UNFILTERED contigs (only needed if the original spades_output cannot be found).
# Setup once (python pinned: SPAdes 3.15.3 breaks with Python >=3.10):  conda create -n spades2 -c conda-forge -c bioconda --solver libmamba spades=3.15.3 "python=3.9" -y
# Submit from the microbacterium_analysis folder:   mkdir -p spades_rerun && bsub < run_spades_rerun.sh
#
#BSUB -J spades_rerun
#BSUB -q medium
#BSUB -n 8
#BSUB -R "span[hosts=1]"
#BSUB -R "rusage[mem=2048]"
#BSUB -M 2048
#BSUB -o spades_rerun/spades_rerun.%J.out
#BSUB -e spades_rerun/spades_rerun.%J.err

set -euo pipefail
cd "$LS_SUBCWD" 2>/dev/null || cd "$(dirname "$0")"
source "$(conda info --base)/etc/profile.d/conda.sh"
module purge 2>/dev/null || true
unset PYTHONPATH PYTHONHOME
conda activate spades2
PY=$CONDA_PREFIX/bin/python
echo "python used: $PY ($($PY --version 2>&1))"
export PYTHONNOUSERSITE=1

OUT=spades_rerun
$PY $CONDA_PREFIX/bin/spades.py --version
# same command as in the report: spades.py -1 reads_R1.fq.gz -2 reads_R2.fq.gz -o spades_output --careful -t 8 -m 16
$PY $CONDA_PREFIX/bin/spades.py -1 reads_R1.fastq.gz -2 reads_R2.fastq.gz -o $OUT/spades_output --careful -t 8 -m 16

# ---- how many contigs, and which would the filter remove? ----
F=$OUT/spades_output/contigs.fasta
echo "Contigs produced by SPAdes: $(grep -c '>' $F)"
echo -e "contig\tlength\tcoverage\tkept_in_submitted_assembly" > $OUT/contigs_all_summary.tsv
grep '>' $F | sed 's/>//' | awk -F_ '{print $0"\t"$4"\t"$6}' | awk -F'\t' '{print $1"\t"$2"\t"$3}' >> $OUT/contigs_all_summary.tsv
column -t $OUT/contigs_all_summary.tsv | head -40
echo DONE
