"""Continue only after the amended candidate's three fresh controls have completed."""
import hashlib,json,pathlib,shutil,subprocess,time
root=pathlib.Path.cwd()
v=root/'verification/case-curation-2026-10-20/ash-pr-3031'
work=root/'.local/ash-curation'
version='923f2acf250e8b9e79afbda9cd56fce6e383aed747224b1081a4806f4617d88b'
container='elixir-agent-benchmark-benchmark-1'
def run(args,**kw):
    return subprocess.run(args,check=True,text=True,**kw)
def rpc(code):
    run(['docker','compose','exec','-T','benchmark','bin/eab','rpc',code])
log=work/'qualification-amendment.log'
while True:
    body=log.read_text()
    if '** (' in body: raise RuntimeError('Qualification reported an error; inspect retained evidence')
    if 'THREE_FRESH_ROUNDS_VERIFIED' in body and 'Exported three functional qualification summaries' in body: break
    time.sleep(30)
print('Three fresh qualification rounds completed; validating export',flush=True)
rpc(f'ref=Eab.Store.read("curation/ash-pr-3031-current.json"); unless ref["version"] == "{version}", do: raise("Wrong candidate"); Code.eval_file("/tmp/ash-validation/export-qualified-case.exs")')
for n in range(1,4):
    dest=v/f'qualification-round-{n}.json'
    if dest.exists(): raise RuntimeError('Refusing to overwrite qualification evidence')
    run(['docker','cp',f'{container}:/tmp/ash-curation-evidence/qualification-round-{n}.json',str(dest)])
    evidence=json.loads(dest.read_text())
    assert evidence['candidate']['version']==version and evidence['fresh_controls'] and evidence['valid']
active=root/'cases/ash-pr-3031'
if active.exists(): raise RuntimeError('Active destination collision')
run(['docker','cp',f'{container}:/tmp/ash-admitted-{version}/ash-pr-3031',str(active)])
expected=json.loads((v/'final-draft-hashes.json').read_text())
actual={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in active.iterdir() if p.name!='admission.json'}
assert actual==expected
assert json.loads((active/'admission.json').read_text())['candidate']['version']==version
rpc('s=Eab.Runs.snapshot(); unless is_nil(s.active) and not s.cleaning and is_nil(s.cleanup_error), do: raise("Controller busy")')
with (work/'build-amended-singleton.log').open('w') as output:
    run(['docker','compose','up','--build','-d'],stdout=output,stderr=subprocess.STDOUT)
run(['docker','cp',str(v),f'{container}:/tmp/ash-validation'])
rpc('unless Eab.Inventory.all() == ["ash-pr-3031"], do: raise("Not singleton"); Code.eval_file("/tmp/ash-validation/install-validation-observer.exs")')
print('Admitted singleton rebuilt; disabled observer installed; starting blind pair',flush=True)
rpc('Code.eval_file("/tmp/ash-validation/run-fresh-pair.exs")')
for name in ['astra-success-1.patch','astra-success-2.patch','astra-results.json','validation-preflight.json','bundle-sha256.json']:
    dest=v/name
    if dest.exists(): raise RuntimeError('Refusing to overwrite model evidence')
    run(['docker','cp',f'{container}:/tmp/ash-astra-evidence/{name}',str(dest)])
print('Two new official passes and sealed evidence exported; independent patch review remains',flush=True)
