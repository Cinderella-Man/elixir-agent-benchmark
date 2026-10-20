#!/bin/bash
# Cachex #306 vs #341 lineage: shared files, ordering
echo "======== LINEAGE #306 and #341 ========"
cd /tmp/elx-exp/cachex-341

echo "--- shared files between the two PRs ---"
echo "#306 files:"
echo "lib/cachex/policy.ex lib/cachex/policy/lrw.ex lib/cachex/policy/lrw/evented.ex lib/cachex/policy/lrw/scheduled.ex lib/cachex/services.ex test/..."
echo "#341 files:"
echo "lib/cachex.ex lib/cachex/actions/warm.ex lib/cachex/services.ex lib/cachex/services/incubator.ex lib/cachex/services/informant.ex lib/cachex/services/steward.ex lib/cachex/spec.ex lib/cachex/spec/validator.ex test/..."
echo "SHARED: lib/cachex/services.ex"

echo
echo "--- is #306 landing (7b4062b) ancestor of #341 landing (3a0d7a9)? ---"
git merge-base --is-ancestor 7b4062bd8d139114ac865535a151165bc0c7d28d 3a0d7a9dbf8dd7c9217fa6521e3c87227708445f && echo YES_306_before_341 || echo NO

echo
echo "--- services.ex at #341 base (b22cb1f) vs after #306 (7b4062b) ---"
git diff 7b4062bd8d139114ac865535a151165bc0c7d28d b22cb1ffcd0763f011f1ed3868b8589147050052 --stat -- lib/cachex/services.ex

echo
echo "--- what #306 changed in services.ex ---"
git show 7b4062bd8d139114ac865535a151165bc0c7d28d -- lib/cachex/services.ex | head -80

echo
echo "--- what #341 changed in services.ex ---"
git diff b22cb1ffcd0763f011f1ed3868b8589147050052 3f6283852e3cbdd335431f90f36fd2ea725bef34 -- lib/cachex/services.ex | head -100

echo
echo "--- dates ---"
echo "#306 merge: 2023-01-09"
echo "#341 land:  2024-03-24"
echo "Gap: ~14 months. #341 base already contains #306."
