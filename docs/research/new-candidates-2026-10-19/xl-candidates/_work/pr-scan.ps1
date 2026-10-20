param(
  [string]$Repo = "",
  [string]$Query = "is:pr is:closed is:merged feat sort:created-desc",
  [int]$Pages = 3,
  [int]$MinFiles = 10,
  [int]$MaxFiles = 20,
  [int]$MaxBig = 50
)

function Get-PrList($repo, $q, $pages) {
  $all = @()
  $ownerRepo = $repo
  for ($p = 1; $p -le $pages; $p++) {
    $url = "https://github.com/$repo/pulls?q=" + [uri]::EscapeDataString($q) + "&page=$p"
    try {
      $r = Invoke-WebRequest -Uri $url -UserAgent "Mozilla/5.0" -UseBasicParsing -TimeoutSec 30
      $pattern = '"number":(\d+),"permalink":"https://github.com/' + [regex]::Escape($ownerRepo) + '/pull/\d+"[^}]*?"title":"([^"]+)"'
      $ms = [regex]::Matches($r.Content, $pattern)
      foreach ($m in $ms) {
        $all += [pscustomobject]@{
          Num   = [int]$m.Groups[1].Value
          Title = $m.Groups[2].Value
        }
      }
    }
    catch {
      Write-Output "ERR $repo p$p : $($_.Exception.Message)"
    }
    Start-Sleep -Milliseconds 200
  }
  return $all | Sort-Object Num -Unique
}

function Get-DiffFileCount($repo, $num) {
  $url = "https://github.com/$repo/pull/$num.diff"
  try {
    $r = Invoke-WebRequest -Uri $url -UserAgent "Mozilla/5.0" -UseBasicParsing -TimeoutSec 30
    return ([regex]::Matches($r.Content, 'diff --git')).Count
  }
  catch { return -1 }
}

if (-not $Repo) { Write-Output "Need -Repo"; exit 1 }

$prs = Get-PrList $Repo $Query $Pages
Write-Output "SCAN $Repo q=$Query found=$($prs.Count)"

foreach ($pr in $prs) {
  $fc = Get-DiffFileCount $Repo $pr.Num
  if ($fc -ge $MinFiles -and $fc -le $MaxFiles) {
    Write-Output ("HIT #{0} files={1} {2}" -f $pr.Num, $fc, $pr.Title)
  }
  elseif ($fc -gt $MaxFiles -and $fc -lt $MaxBig) {
    Write-Output ("BIG #{0} files={1} {2}" -f $pr.Num, $fc, $pr.Title)
  }
  elseif ($fc -ge $MaxBig) {
    Write-Output ("MEGA #{0} files={1} {2}" -f $pr.Num, $fc, $pr.Title)
  }
  Start-Sleep -Milliseconds 120
}
