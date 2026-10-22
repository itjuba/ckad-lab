<#
.SYNOPSIS
  CKAD practice simulator: two k3d clusters, a build host and a Linux exam terminal.

.EXAMPLE
  .\sim.ps1 up       # create clusters, build host and terminal, set up every question
  .\sim.ps1 ui       # open the web UI (http://localhost:8090)
  .\sim.ps1 shell    # open the exam terminal
  .\sim.ps1 update   # bring the environment up to date after git pull; keeps your work
  .\sim.ps1 stop     # pause everything (keeps your progress)
  .\sim.ps1 start    # resume after stop
  .\sim.ps1 reset    # put every question back to its starting state
  .\sim.ps1 down     # delete clusters, registry, build host and terminal
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
$Cluster = 'ckad'                     # context ckad-c1: 1 control plane + 1 worker
$Cluster2 = 'ckad2'                   # context ckad-c2: 1 node, joined to the same network
$Registry = 'ckad-registry'          # k3d names the container k3d-ckad-registry
$Terminal = 'ckad-terminal'
$Image = 'ckad-terminal:latest'
$Node = 'ckad-build'                 # the build host you ssh into (podman, no kubectl)
$NodeImage = 'ckad-build:latest'
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

function Test-Cluster([string]$Name) { [bool]((k3d cluster list -o json | ConvertFrom-Json) | Where-Object { $_.name -eq $Name }) }
function Test-Registry { [bool]((k3d registry list -o json | ConvertFrom-Json) | Where-Object { $_.name -eq "k3d-$Registry" }) }
function Test-Container([string]$Name) { [bool](docker ps -a --filter "name=^$Name$" --format '{{.Names}}') }
function Test-Terminal { Test-Container $Terminal }

function Write-Utf8NoBom([string]$Path, [string]$Text) {
  [IO.File]::WriteAllText($Path, $Text.Replace("`r`n", "`n"), (New-Object Text.UTF8Encoding $false))
}

# Kubeconfig for the terminal, which reaches the API servers over the k3d Docker network.
function Write-Kubeconfig([string]$Name, [string]$File) {
  $kubeconfig = (k3d kubeconfig get $Name) -join "`n"
  $kubeconfig = $kubeconfig -replace 'server: https://\S+', "server: https://k3d-$Name-server-0:6443"
  Write-Utf8NoBom (Join-Path $State $File) $kubeconfig
}

function New-Cluster([string]$Name, [string[]]$Extra) {
  # Lets pods pull localhost:5000/<image>, the same name you push to from the build host.
  Write-Utf8NoBom (Join-Path $State 'registries.yaml') @"
mirrors:
  "localhost:5000":
    endpoint:
      - http://k3d-${Registry}:5000
"@
  Invoke-Native k3d cluster create $Name --image $K3sImage `
    --registry-use "k3d-${Registry}:5000" --registry-config (Join-Path $State 'registries.yaml') `
    --k3s-arg "--tls-san=k3d-$Name-server-0@server:0" `
    --kubeconfig-update-default=false --kubeconfig-switch-context=false --wait @Extra
}

function Start-Node {
  if (Test-Container $Node) { Invoke-Native docker rm -f $Node | Out-Null }
  # Privileged so podman can build images inside it. It shares /opt/course with the terminal
  # and writes the ssh key pair the terminal uses into .state\ssh.
  Invoke-Native docker run -d --name $Node --hostname $Node --network "k3d-$Cluster" --privileged `
    -v "${Course}:/opt/course" -v "${State}\ssh:/ckad-state/ssh" $NodeImage | Out-Null
}

function Start-Terminal {
  if (Test-Terminal) { Invoke-Native docker rm -f $Terminal | Out-Null }
  # Leftover from development, when the UI port was forwarded by a separate container.
  if (docker ps -aq --filter 'name=^ckad-ui-proxy$') { docker rm -f ckad-ui-proxy | Out-Null }
  # The web UI listens on $UiPort inside the terminal; publish it on localhost only.
  Invoke-Native docker run -d --name $Terminal --hostname ckad --network "k3d-$Cluster" `
    -p "127.0.0.1:${UiPort}:${UiPort}" `
    -v "${Root}\sim:/ckad" -v "${Course}:/opt/course" -v "${State}:/ckad-state:ro" $Image | Out-Null
}

# Everything but the questions: registry, both clusters, kubeconfigs, images, containers.
# Safe to re-run: existing clusters are kept, containers are recreated from the latest image.
function Confirm-Environment {
  New-Item -ItemType Directory -Force $State, $Course, (Join-Path $State 'ssh') | Out-Null

  if (-not (Test-Registry)) {
    Write-Host '==> Creating image registry (localhost:5000)'
    Invoke-Native k3d registry create $Registry --port 5000
  }
  if (-not (Test-Cluster $Cluster)) {
    Write-Host '==> Creating cluster 1 (1 control plane + 1 worker, Kubernetes v1.37)'
    New-Cluster $Cluster @('--agents', '1')
  }
  if (-not (Test-Cluster $Cluster2)) {
    Write-Host '==> Creating cluster 2 (1 node, Kubernetes v1.37)'
    # Same Docker network as cluster 1, so the terminal reaches both. No ingress controller
    # here: the Ingress questions live on cluster 1.
    New-Cluster $Cluster2 @('--agents', '0', '--network', "k3d-$Cluster", '--k3s-arg', '--disable=traefik@server:0')
  }
  Write-Kubeconfig $Cluster 'kubeconfig'
  Write-Kubeconfig $Cluster2 'kubeconfig-2'

  Write-Host '==> Building the build host image'
  Invoke-Native docker build -t $NodeImage (Join-Path $Root 'sim\node')
  Write-Host '==> Building the exam terminal image'
  Invoke-Native docker build -t $Image (Join-Path $Root 'sim')
  Start-Node
  Start-Terminal

  Write-Host '==> Waiting for the clusters'
  # The terminal builds its kubeconfig (one context per cluster) as it starts.
  Invoke-Native docker exec $Terminal bash -c 'for i in $(seq 60); do [ -s /root/.kube/config ] && break; sleep 1; done; for c in $(kubectl config get-contexts -o name); do kubectl --context $c wait --for=condition=Ready nodes --all --timeout=180s || exit 1; done'
  Invoke-Native docker exec $Terminal kubectl --context ckad-c1 -n kube-system rollout status deploy/traefik --timeout=300s
}

switch ($Command) {
  'up' {
    Confirm-Environment
    Write-Host '==> Setting up questions'
    docker exec $Terminal /ckad/bin/ckad reset all
    Write-Host ''
    Write-Host "Ready. Web UI: $UiUrl   (or the terminal only:  .\sim.ps1 shell)"
  }
  'ui' {
    if (-not (Test-Terminal)) { throw "No terminal yet. Run: .\sim.ps1 up" }
    Start-Process $UiUrl
  }
  'update' {
    if (-not (Test-Terminal)) { throw "No terminal yet. Run: .\sim.ps1 up" }
    $hadCluster2 = Test-Cluster $Cluster2
    Confirm-Environment
    Write-Host "Updated. Web UI: $UiUrl   (your answers and progress are unchanged)"
    if (-not $hadCluster2) {
      Write-Host 'This update added the second cluster: run `ckad reset all` in the terminal so every'
      Write-Host 'question is set up in its own context (passed questions stay passed).'
    }
  }
  'shell' {
    if (-not (Test-Terminal)) { throw "No terminal yet. Run: .\sim.ps1 up" }
    docker exec -it $Terminal bash
  }
  'status' {
    k3d cluster list
    docker ps -a --filter "name=$Terminal" --filter "name=$Node" --format 'table {{.Names}}\t{{.Status}}'
  }
  'stop' {
    foreach ($c in @($Terminal, $Node)) { if (Test-Container $c) { Invoke-Native docker stop $c | Out-Null } }
    foreach ($c in @($Cluster, $Cluster2)) { if (Test-Cluster $c) { Invoke-Native k3d cluster stop $c } }
    Invoke-Native docker stop "k3d-$Registry" | Out-Null
  }
  'start' {
    Invoke-Native docker start "k3d-$Registry" | Out-Null
    foreach ($c in @($Cluster, $Cluster2)) { if (Test-Cluster $c) { Invoke-Native k3d cluster start $c --wait } }
    if (Test-Container $Node) { Invoke-Native docker start $Node | Out-Null } else { Start-Node }
    if (Test-Terminal) { Invoke-Native docker start $Terminal | Out-Null } else { Start-Terminal }
    Write-Host "Started. Web UI: $UiUrl   (or the terminal only:  .\sim.ps1 shell)"
  }
  'reset' { docker exec $Terminal /ckad/bin/ckad reset all }
  'down' {
    foreach ($c in @($Terminal, $Node)) { if (Test-Container $c) { Invoke-Native docker rm -f $c | Out-Null } }
    foreach ($c in @($Cluster2, $Cluster)) { if (Test-Cluster $c) { Invoke-Native k3d cluster delete $c } }
    if (Test-Registry) { Invoke-Native k3d registry delete "k3d-$Registry" }
    Write-Host "Removed. Your answer files are still in $Course"
  }
}
