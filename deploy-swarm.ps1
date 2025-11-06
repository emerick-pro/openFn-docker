# deploy-swarm.ps1 - PowerShell helper to create secrets and deploy the docker stack
# Usage: Run in an elevated PowerShell session on the manager node
# 1) Copy values into secrets files in ./secrets
# 2) ./deploy-swarm.ps1

param()

$stackName = "openfn"
$secretsDir = (Join-Path $PSScriptRoot "secrets")
if (-not (Test-Path $secretsDir)) { New-Item -ItemType Directory -Path $secretsDir | Out-Null }

# Files we expect: secrets/postgres_password.txt, secrets/app_secret.txt
$postgresSecretFile = Join-Path $secretsDir "postgres_password.txt"
$appSecretFile = Join-Path $secretsDir "app_secret.txt"

if (-not (Test-Path $postgresSecretFile) -or -not (Test-Path $appSecretFile)) {
    Write-Host "Please create the secret files first:" -ForegroundColor Yellow
    Write-Host "  $postgresSecretFile" -ForegroundColor Yellow
    Write-Host "  $appSecretFile" -ForegroundColor Yellow
    Write-Host "Each file should contain only the secret value and no trailing newline if possible." -ForegroundColor Yellow
    exit 1
}

# Create Docker secrets (idempotent - will fail if already exists)
function Ensure-Secret($name, $file) {
    $exists = docker secret ls --format "{{.Name}}" | Where-Object { $_ -eq $name }
    if ($exists) {
        Write-Host "Secret $name already exists. Skipping." -ForegroundColor Cyan
    } else {
        docker secret create $name $file | Out-Null
        Write-Host "Created secret: $name" -ForegroundColor Green
    }
}

Ensure-Secret -name postgres_password -file $postgresSecretFile
Ensure-Secret -name app_secret -file $appSecretFile

# Deploy the stack
Write-Host "Deploying stack $stackName..." -ForegroundColor Cyan
docker stack deploy -c "docker-stack.yml" $stackName

Write-Host "Deployment command issued. Monitor with: docker stack ps $stackName and docker service ls" -ForegroundColor Green
