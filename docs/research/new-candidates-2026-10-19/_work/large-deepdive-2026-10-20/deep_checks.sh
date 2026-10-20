#!/usr/bin/env bash
set -uo pipefail
WORK=/tmp/large-dd/repos

echo "################ BEACON deep check ################"
cd "$WORK/beacon"
echo "-- relation of claimed_base 78c0fef to merge first parent 86c9ffd --"
git log --oneline 78c0fef0f88a4b83a397533e0ad35224dbb246a9..86c9ffd2c46558313725fa7ffddbf72bd926b2b3 | head -30
echo "count: $(git rev-list --count 78c0fef0f88a4b83a397533e0ad35224dbb246a9..86c9ffd2c46558313725fa7ffddbf72bd926b2b3)"
echo "is claimed_base ancestor of first_parent? $(git merge-base --is-ancestor 78c0fef0f88a4b83a397533e0ad35224dbb246a9 86c9ffd2c46558313725fa7ffddbf72bd926b2b3 && echo YES || echo NO)"
echo "is first_parent ancestor of claimed_base? $(git merge-base --is-ancestor 86c9ffd2c46558313725fa7ffddbf72bd926b2b3 78c0fef0f88a4b83a397533e0ad35224dbb246a9 && echo YES || echo NO)"

echo "-- commits touching sitemap-related files AFTER merge 1aa1135 --"
for f in lib/beacon/web/controllers/sitemap_controller.ex lib/beacon/web/sitemap_xml.ex lib/beacon/web/sitemap/sitemap.xml.eex lib/beacon/web/sitemap/sitemap_index.xml.eex lib/beacon/router.ex lib/beacon/loader/routes.ex test/beacon_web/controllers/sitemap_controller_test.exs; do
  echo "==== $f ===="
  git log --oneline 1aa11357746073f0f9e321e1cdf2ba1e62a51682..HEAD -- "$f" | head -20
done

echo "-- any commits mentioning sitemap after merge --"
git log --oneline 1aa11357746073f0f9e321e1cdf2ba1e62a51682..HEAD --grep=sitemap -i | head -20

echo "-- PR#687 related later issues/PRs in log --"
git log --oneline 1aa11357746073f0f9e321e1cdf2ba1e62a51682..HEAD --grep='687\|sitemap\|169' -i | head -20

echo
echo "################ CRAFTPLAN deep check ################"
cd "$WORK/craftplan"
echo "-- is head ff52fcab related to merge? --"
git log -1 --format='%H %P %s' ff52fcab4e9b804c426b0dea09ac049ff663c2fe
git log -1 --format='%H %P %s' 46c0a6fa88ed5bd195531460129ddddbe055b663
echo "same tree as merge? $(git diff --stat ff52fcab4e9b804c426b0dea09ac049ff663c2fe 46c0a6fa88ed5bd195531460129ddddbe055b663 | tail -1)"
echo "same patch as parent..merge? $(git diff ad9fb484e9e19076aae2c8c4dc48a736535e3a3c 46c0a6fa88ed5bd195531460129ddddbe055b663 | md5sum) vs parent..head $(git diff ad9fb484e9e19076aae2c8c4dc48a736535e3a3c ff52fcab4e9b804c426b0dea09ac049ff663c2fe | md5sum)"

echo "-- commits touching cancel-related files AFTER merge 46c0a6fa --"
for f in lib/craftplan/orders/production_batch.ex lib/craftplan/orders/changes/batch_cancel.ex lib/craftplan/orders.ex lib/craftplan/production/batching.ex lib/craftplan_web/live/manage/production_batch_live/show.ex test/craftplan/production_batching_test.exs test/craftplan_web/production_batch_live_actions_test.exs; do
  echo "==== $f ===="
  git log --oneline 46c0a6fa88ed5bd195531460129ddddbe055b663..HEAD -- "$f" | head -20
done

echo "-- commits mentioning cancel after merge --"
git log --oneline 46c0a6fa88ed5bd195531460129ddddbe055b663..HEAD --grep=cancel -i | head -20

echo
echo "################ ABSINTHE deep check ################"
cd "$WORK/absinthe"
echo "-- relation of claimed_base 8e451950 to merge first parent 8fba7023 --"
git log --oneline 8e451950ea87083f50a06abf7b4246284bbe347d..8fba7023f944e093036b89131b9e47a4ad2f7ecc | head -30
echo "count: $(git rev-list --count 8e451950ea87083f50a06abf7b4246284bbe347d..8fba7023f944e093036b89131b9e47a4ad2f7ecc)"
echo "is claimed_base ancestor of first_parent? $(git merge-base --is-ancestor 8e451950ea87083f50a06abf7b4246284bbe347d 8fba7023f944e093036b89131b9e47a4ad2f7ecc && echo YES || echo NO)"

echo "-- commits touching description-related files AFTER merge c029a611 --"
for f in src/absinthe_parser.yrl lib/absinthe/language/operation_definition.ex lib/absinthe/language/fragment.ex lib/absinthe/language/render.ex lib/absinthe/blueprint/document/operation.ex lib/absinthe/blueprint/document/fragment/named.ex test/absinthe/document_description_test.exs; do
  echo "==== $f ===="
  git log --oneline c029a611640a764b687f6e3b5ce647880eff99fd..HEAD -- "$f" | head -20
done

echo "-- commits mentioning description / 1404 after merge --"
git log --oneline c029a611640a764b687f6e3b5ce647880eff99fd..HEAD --grep='description\|1404' -i | head -20

echo "-- Inspect protocol on Language nodes? --"
grep -n "Inspect\|inspect\|defimpl" lib/absinthe/language/*.ex lib/absinthe/language/render.ex 2>/dev/null | head -40
grep -rn "defimpl Inspect\|Protocol" lib/absinthe/ --include='*.ex' | head -20
