#!/usr/bin/env bash
set -uo pipefail

echo "################ BEACON key sources at first-parent+patch ################"
# use the successful apply workspace
cd /tmp/large-dd/classic-beacon 2>/dev/null || cd /tmp/large-dd/apply-beacon-first-parent
pwd
echo "-- sitemap_controller.ex --"
cat lib/beacon/web/controllers/sitemap_controller.ex 2>/dev/null | head -80
echo "-- sitemap_xml.ex --"
cat lib/beacon/web/sitemap_xml.ex 2>/dev/null
echo "-- sitemap.xml.eex --"
cat lib/beacon/web/sitemap/sitemap.xml.eex 2>/dev/null
echo "-- sitemap_index.xml.eex --"
cat lib/beacon/web/sitemap/sitemap_index.xml.eex 2>/dev/null
echo "-- router.ex helpers (beacon_sitemap_url / beacon_page_url) --"
grep -n -A15 'beacon_sitemap_url\|beacon_page_url\|sitemap' lib/beacon/router.ex | head -80
echo "-- sitemap_controller_test.exs (first 120 lines) --"
head -120 test/beacon_web/controllers/sitemap_controller_test.exs

echo
echo "################ CRAFTPLAN key sources ################"
cd /tmp/large-dd/classic-craftplan
pwd
echo "-- batch_cancel.ex --"
cat lib/craftplan/orders/changes/batch_cancel.ex
echo "-- production_batch.ex cancel/start/consume actions --"
grep -n -B2 -A20 'update :cancel\|update :start\|update :consume\|update :complete' lib/craftplan/orders/production_batch.ex | head -100
echo "-- batching.ex batch_consumed? --"
grep -n -B5 -A20 'batch_consumed' lib/craftplan/production/batching.ex | head -50
echo "-- show.ex cancel button + handle_event --"
grep -n -B2 -A25 'cancel-batch\|cancel_batch' lib/craftplan_web/live/manage/production_batch_live/show.ex | head -80

echo
echo "################ ABSINTHE key sources ################"
cd /tmp/large-dd/classic-absinthe
pwd
echo "-- render.ex description helper --"
grep -n -B2 -A15 'defp description\|description(' lib/absinthe/language/render.ex | head -50
echo "-- yrl put_description function definition --"
grep -n -A20 'put_description' src/absinthe_parser.yrl | head -40
echo "-- mix.exs version/elixir --"
grep -n 'elixir\|version\|@version' mix.exs | head -15
echo "-- LICENSE exists? --"
ls LICENSE* 2>/dev/null
echo "-- test count in document_description_test --"
grep -c 'test "' test/absinthe/document_description_test.exs
echo "-- render tests specifically --"
grep -n -A20 'SDL rendering' test/absinthe/document_description_test.exs | head -50
