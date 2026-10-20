<#
.SYNOPSIS
  CKAD practice simulator: a k3d cluster plus a Linux exam terminal.

.EXAMPLE
  .\sim.ps1 up       # create cluster + terminal and set up every question
  .\sim.ps1 ui       # open the web UI (http://localhost:8090)
  .\sim.ps1 shell    # open the exam terminal
  .\sim.ps1 update   # rebuild the terminal image (after git pull); keeps cluster and progress
  .\sim.ps1 stop     # pause everything (keeps your progress)
  .\sim.ps1 start    # resume after stop
  .\sim.ps1 reset    # put every question back to its starting state
  .\sim.ps1 down     # delete cluster, registry and terminal
#>
param(
  [Parameter(Position = 0)]
  [ValidateSet('up', 'ui', 'shell', 'update', 'status', 'stop', 'start', 'reset', 'down')]
  [string]$Command = 'shell'
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$State = Join-Path $Root '.state'
$Course = Join-Path $Root 'course'
$Cluster = 'ckad'
$Registry = 'ckad-registry'          # k3d names the container k3d-ckad-registry
$Terminal = 'ckad-terminal'
$Image = 'ckad-terminal:latest'
$K3sImage = 'rancher/k3s:v1.37.1-k3s1'   # CKAD exam runs v1.37 (LF FAQ, Oct 2026)
$UiPort = 8090
$UiUrl = "http://localhost:$UiPort"

# Runs a native command and throws on a non-zero exit code. Progress that docker/k3d
# print on stderr must not count as an error, so 'Stop' is relaxed for the call.
function Invoke-Native {
  $exe, $rest = $args
  $saved = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { & $exe @rest } finally { $ErrorActionPreference = $saved }
  if ($LASTEXITCODE -ne 0) { throw "Command failed ($LASTEXITCODE): $($args -join ' ')" }
}

function Test-Cluster { [bool]((k3d cluster list -o json | ConvertFrom-Json) | Where-Object { $_.name -eq $Cluster }) }
function Test-Registry { [bool]((k3d registry list -o json | ConvertFrom-Json) | Where-Object { $_.name -eq "k3d-$Registry" }) }
function Test-Terminal { [bool](docker ps -a --filter "name=^$Terminal$" --format '{{.Names}}') }

function Write-Utf8NoBom([string]$Path, [string]$Text) {
  [IO.File]::WriteAllText($Path, $Text.Replace("`r`n", "`n"), (New-Object Text.UTF8Encoding $false))
}

function Start-Terminal {
  if (Test-Terminal) { Invoke-Native docker rm -f $Terminal | Out-Null }
  # Leftover from development, when the UI port was forwarded by a separate container.
  if (docker ps -aq --filter 'name=^ckad-ui-proxy$') { docker rm -f ckad-ui-proxy | Out-Null }
  # The web UI listens on $UiPort inside the terminal; publish it on localhost only.
  Invoke-Native docker run -d --name $Terminal --hostname ckad --network "k3d-$Cluster" `
    -p "127.0.0.1:${UiPort}:${UiPort}" `
    -v "${Root}\sim:/ckad" -v "${Course}:/opt/course" -v "${State}:/ckad-state:ro" `
    -v /var/run/docker.sock:/var/run/docker.sock $Image | Out-Null
}

function Invoke-Up {
  New-Item -ItemType Directory -Force $State, $Course | Out-Null

  if (-not (Test-Registry)) {
    Write-Host '==> Creating image registry (localhost:5000)'
    Invoke-Native k3d registry create $Registry --port 5000
  }

  if (-not (Test-Cluster)) {
    Write-Host '==> Creating cluster (1 control plane + 1 worker, Kubernetes v1.37)'
    # Lets pods pull localhost:5000/<image>, the same name you push to from the terminal.
    Write-Utf8NoBom (Join-Path $State 'registries.yaml') @"
mirrors:
  "localhost:5000":
    endpoint:
      - http://k3d-${Registry}:5000
"@
    Invoke-Native k3d cluster create $Cluster --image $K3sImage --agents 1 `
      --registry-use "k3d-${Registry}:5000" --registry-config (Join-Path $State 'registries.yaml') `
      --k3s-arg "--tls-san=k3d-$Cluster-server-0@server:0" `
      --kubeconfig-update-default=false --kubeconfig-switch-context=false --wait
  }

  # Kubeconfig for the terminal, which reaches the API server over the k3d Docker network.
  $kubeconfig = (k3d kubeconfig get $Cluster) -join "`n"
  $kubeconfig = $kubeconfig -replace 'server: https://\S+', "server: https://k3d-$Cluster-server-0:6443"
  Write-Utf8NoBom (Join-Path $State 'kubeconfig') $kubeconfig

  Write-Host '==> Building exam terminal image'
  Invoke-Native docker build -t $Image (Join-Path $Root 'sim')
  Start-Terminal

  Write-Host '==> Waiting for nodes'
  Invoke-Native docker exec $Terminal kubectl wait --for=condition=Ready nodes --all --timeout=180s
  Invoke-Native docker exec $Terminal kubectl -n kube-system rollout status deploy/traefik --timeout=300s

  Write-Host '==> Setting up questions'
  docker exec $Terminal /ckad/bin/ckad reset all

  Write-Host ''
  Write-Host "Ready. Web UI: $UiUrl   (or the terminal only:  .\sim.ps1 shell)"
}

switch ($Command) {
  'up' { Invoke-Up }
  'ui' {
    if (-not (Test-Terminal)) { throw "No terminal yet. Run: .\sim.ps1 up" }
    Start-Process $UiUrl
  }
  'update' {
    if (-not (Test-Terminal)) { throw "No terminal yet. Run: .\sim.ps1 up" }
    Write-Host '==> Rebuilding the exam terminal image'
    Invoke-Native docker build -t $Image (Join-Path $Root 'sim')
    Start-Terminal
    Write-Host "Updated. Web UI: $UiUrl   (your cluster, answers and progress are unchanged)"
  }
  'shell' {
    if (-not (Test-Terminal)) { throw "No terminal yet. Run: .\sim.ps1 up" }
    docker exec -it $Terminal bash
  }
  'status' {
    k3d cluster list $Cluster
    docker ps -a --filter "name=$Terminal" --format 'table {{.Names}}\t{{.Status}}'
  }
  'stop' {
    if (Test-Terminal) { Invoke-Native docker stop $Terminal | Out-Null }
    Invoke-Native k3d cluster stop $Cluster
    Invoke-Native docker stop "k3d-$Registry" | Out-Null
  }
  'start' {
    Invoke-Native docker start "k3d-$Registry" | Out-Null
    Invoke-Native k3d cluster start $Cluster --wait
    if (Test-Terminal) { Invoke-Native docker start $Terminal | Out-Null } else { Start-Terminal }
    Write-Host "Started. Web UI: $UiUrl   (or the terminal only:  .\sim.ps1 shell)"
  }
  'reset' { docker exec $Terminal /ckad/bin/ckad reset all }
  'down' {
    if (Test-Terminal) { Invoke-Native docker rm -f $Terminal | Out-Null }
    if (Test-Cluster) { Invoke-Native k3d cluster delete $Cluster }
    if (Test-Registry) { Invoke-Native k3d registry delete "k3d-$Registry" }
    Write-Host "Removed. Your answer files are still in $Course"
  }
}
