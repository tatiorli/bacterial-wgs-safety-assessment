# antiSMASH 8.0.4 — preliminary results (job 102238, run 3 Nov 2026)

Input: `Microbacterium_arborescens_spp._assembled_genome.fasta` (9 contigs). Bacterial mode, Prodigal, KnownClusterBlast, ClusterBlast, SubClusterBlast, ActiveSiteFinder, RREFinder. 7 regions, none on a contig edge (`contig_edge=False` in every region).

| Region | Contig | Location (bp) | Type (category) | MIBiG known-cluster hits (KnownClusterBlast) |
|---|---|---|---|---|
| 1.1 | NODE_1 | 2,226–43,443 | T3PKS (PKS) | hygromycin A, herbimycin A, collismycin A, formicamycin: 2 genes each, 0 core |
| 1.2 | NODE_1 | 472,105–494,726 | lanthipeptide class III (RiPP) | none |
| 1.3 | NODE_1 | 764,074–796,027 | furan + lipolanthine (other / RiPP) | none |
| 1.4 | NODE_1 | 812,840–849,679 | betalactone + terpene-precursor (other) | microansamycin: 2 genes, 0 core |
| 1.5 | NODE_1 | 1,044,408–1,068,577 | terpene | carotenoid (BGC0000636/637/644): 2–3 genes, 1 core; esmeraldin, diastaphenazine |
| 1.6 | NODE_1 | 1,405,612–1,446,766 | T3PKS (PKS) | merochlorin, endophenazine, diazepinomicin, others: up to 5 genes, 1 core |
| 3.1 | NODE_3 | 369,872–391,272 | RRE-containing (RiPP) | none |

## Overview table in index.html
The "Similarity Confidence" and "Most similar known cluster" cells are empty for all 7 regions (regions 1.2, 1.3 and 3.1 have no hits at all). No region was reported with a most-similar known cluster, which means that no MIBiG match reached antiSMASH's reporting level. The page has no % values, because none was assigned.

## Preliminary reading (based on gene-hit counts, to be checked against the % values)
- No region has a strong match to a known toxin or antimicrobial cluster. Most known-cluster hits are only 2 genes with no core biosynthetic gene.
- Region 1.5 matches carotenoid clusters, which are pigments, not compounds of concern.
- Regions 1.4 and 1.6 are the ones to read in detail. Both have partial matches (microansamycin, merochlorin and phenazine hits) that are probably driven by shared enzyme families.
- Flag any region with a high similarity to a cluster of concern before writing it up.
