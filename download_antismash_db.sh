#!/bin/bash
#BSUB -J antismash_db
#BSUB -q short
#BSUB -n 1
#BSUB -R "rusage[mem=8000]"
#BSUB -M 8000
#BSUB -W 04:00
#BSUB -o antismash_db.%J.out
#BSUB -e antismash_db.%J.err

set -euo pipefail

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate antismash

echo "Start: $(date)"
echo "antiSMASH: $(antismash --version)"

download-antismash-databases

echo "Databases checked/downloaded:"
antismash --check-prereqs

echo "SUCCESS: antiSMASH database download finished $(date)"
