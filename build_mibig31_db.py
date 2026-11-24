#!/usr/bin/env python
"""Build an antiSMASH KnownClusterBlast database from MIBiG 3.1 files, in a NEW directory.

Reads mibig_prot_seqs_3.1.fasta and mibig_json_3.1/ and writes
<outdir>/knownclusterblast/3.1/{clusters.txt,proteins.fasta}
(proteins.dmnd is made afterwards with diamond). The original antiSMASH databases are not touched.
"""
import glob
import json
import os
import sys
from collections import OrderedDict

fasta, json_dir, outdir = sys.argv[1:4]
target = os.path.join(outdir, "knownclusterblast", "3.1")
os.makedirs(target, exist_ok=True)

# compound names and classes per MIBiG accession
meta = {}
for path in glob.glob(os.path.join(json_dir, "BGC*.json")):
    with open(path) as handle:
        data = json.load(handle)
    cluster = data["cluster"]
    acc = cluster.get("mibig_accession") or os.path.basename(path)[:-5]
    names = [c.get("compound", "") for c in cluster.get("compounds", []) if c.get("compound")]
    classes = cluster.get("biosyn_class", []) or ["Other"]
    meta[acc] = ("/".join(names) or "Unknown", "+".join(classes))

clusters = OrderedDict()  # (acc, cnum) -> (locus_tags, protein_ids)
n_prot = 0
with open(fasta) as src, open(os.path.join(target, "proteins.fasta"), "w") as dst:
    for line in src:
        if line.startswith(">"):
            fields = line[1:].strip().split("|")
            key = (fields[0], fields[1])
            tags, prots = clusters.setdefault(key, ([], []))
            tags.append(fields[4])
            prots.append(fields[6])
            n_prot += 1
        dst.write(line)

with open(os.path.join(target, "clusters.txt"), "w") as out:
    for (acc, cnum), (tags, prots) in clusters.items():
        name, cls = meta.get(acc, ("Unknown", "Other"))
        out.write("\t".join([acc, name, cnum, cls, ";".join(tags), ";".join(prots)]) + "\n")

print("clusters: %d, proteins: %d, written to %s" % (len(clusters), n_prot, target))
