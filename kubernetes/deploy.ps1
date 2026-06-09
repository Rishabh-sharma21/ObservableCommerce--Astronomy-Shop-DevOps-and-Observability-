# PowerShell deployment script for Astronomy Shop on Kubernetes

param(
    [string]$Namespace = "astronomy-shop",
    [string]$Registry = "docker.io",
    [string]$ImageName = "astronomy-shop-lite-app",
    [string]$ImageTag = "latest",
    [switch]$SkipBuild = $false
)

# Colors for output
function Write-Info {
    Write-Host "[INFO] $args" -ForegroundColor Green
}

function Write-Warn {
    Write-Host "[WARN] $args" -ForegroundColor Yellow
}

function Write-Error {
    Write-Host "[ERROR] $args" -ForegroundColor Red
}

# Check prerequisites
function Check-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    $prereqs = @("kubectl", "docker")
    foreach ($cmd in $prereqs) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            if ($cmd -eq "docker" -and -not $SkipBuild) {
                Write-Error "$cmd is not installed"
                exit 1
            } elseif ($cmd -eq "kubectl") {
                Write-Error "$cmd is not installed"
                exit 1
            }
        }
    }
    
    Write-Info "Prerequisites check passed"
}

# Check cluster connectivity
function Check-Cluster {
    Write-Info "Checking Kubernetes cluster connectivity..."
    
    $clusterInfo = kubectl cluster-info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Cannot connect to Kubernetes cluster"
        exit 1
    }
    
    Write-Info "Connected to cluster"
}

# Build Docker image
function Build-Image {
    if ($SkipBuild) {
        Write-Warn "Skipping image build"
        return
    }
    
    Write-Info "Building Docker image..."
    
    if (-not (Test-Path "Dockerfile")) {
        Write-Error "Dockerfile not found in current directory"
        exit 1
    }
    
    docker build -t "${ImageName}:${ImageTag}" .
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build Docker image"
        exit 1
    }
    
    if ($Registry -ne "local") {
        Write-Info "Tagging image for registry: $Registry"
        docker tag "${ImageName}:${ImageTag}" "${Registry}/${ImageName}:${ImageTag}"
        
        Write-Info "Pushing image to registry..."
        docker push "${Registry}/${ImageName}:${ImageTag}"
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to push Docker image"
            exit 1
        }
    }
    
    Write-Info "Image built successfully"
}

# Create namespace
function Create-Namespace {
    Write-Info "Creating namespace: $Namespace"
    
    kubectl apply -f kubernetes/00-namespace/namespace.yaml
    
    Write-Info "Namespace created"
}

# Deploy ConfigMaps
function Deploy-ConfigMaps {
    Write-Info "Deploying ConfigMaps..."
    
    kubectl apply -f kubernetes/01-configmaps/
    
    Start-Sleep -Seconds 2
    
    Write-Info "ConfigMaps deployed"
}

# Deploy observability stack
function Deploy-Observability {
    Write-Info "Deploying observability stack..."
    
    Write-Info "Creating persistent volume claims..."
    kubectl apply -f kubernetes/02-observability/pvcs.yaml
    
    Write-Info "Deploying OpenTelemetry Collector..."
    kubectl apply -f kubernetes/02-observability/otel-collector.yaml
    
    Write-Info "Deploying Prometheus..."
    kubectl apply -f kubernetes/02-observability/prometheus.yaml
    
    Write-Info "Deploying Loki..."
    kubectl apply -f kubernetes/02-observability/loki.yaml
    
    Write-Info "Deploying Tempo..."
    kubectl apply -f kubernetes/02-observability/tempo.yaml
    
    Write-Info "Deploying Grafana..."
    kubectl apply -f kubernetes/02-observability/grafana.yaml
    
    Write-Info "Waiting for observability stack to be ready (this may take 2-3 minutes)..."
    kubectl wait --for=condition=ready pod `
        -l "app in (loki,tempo,prometheus,otel-collector,grafana)" `
        -n $Namespace --timeout=300s 2>$null
    
    Write-Info "Observability stack deployed"
}

# Deploy applications
function Deploy-Applications {
    Write-Info "Deploying application services..."
    
    Write-Info "Deploying Product Catalog..."
    kubectl apply -f kubernetes/03-applications/product-catalog.yaml
    
    Write-Info "Deploying Cart..."
    kubectl apply -f kubernetes/03-applications/cart.yaml
    
    Write-Info "Deploying Checkout..."
    kubectl apply -f kubernetes/03-applications/checkout.yaml
    
    Write-Info "Deploying Frontend..."
    kubectl apply -f kubernetes/03-applications/frontend.yaml
    
    Write-Info "Waiting for application services to be ready..."
    kubectl wait --for=condition=ready pod `
        -l "app in (frontend,product-catalog,cart,checkout)" `
        -n $Namespace --timeout=300s 2>$null
    
    Write-Info "Application services deployed"
}

# Deploy networking
function Deploy-Networking {
    Write-Info "Deploying networking and auto-scaling..."
    
    kubectl apply -f kubernetes/04-networking/ingress.yaml
    kubectl apply -f kubernetes/04-networking/hpa.yaml
    
    Write-Info "Networking and auto-scaling deployed"
}

# Display status and access information
function Display-Status {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Deployment Completed Successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Pod Status:" -ForegroundColor Yellow
    kubectl get pods -n $Namespace
    
    Write-Host ""
    Write-Host "Service Status:" -ForegroundColor Yellow
    kubectl get svc -n $Namespace
    
    Write-Host ""
    Write-Host "Ingress Status:" -ForegroundColor Yellow
    kubectl get ingress -n $Namespace
    
    Write-Host ""
    Write-Host "Access Instructions:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Port Forwarding (Quick Access):"
    Write-Host "   Frontend:   kubectl port-forward svc/frontend 8080:8080 -n $Namespace"
    Write-Host "   Grafana:    kubectl port-forward svc/grafana 3000:3000 -n $Namespace"
    Write-Host "   Prometheus: kubectl port-forward svc/prometheus 9090:9090 -n $Namespace"
    Write-Host ""
    Write-Host "2. Ingress (DNS Required):"
    Write-Host "   Add to hosts file: <INGRESS_IP> astronomy-shop.local"
    Write-Host ""
    Write-Host "   URLs:"
    Write-Host "   - Frontend:   http://astronomy-shop.local"
    Write-Host "   - Grafana:    http://grafana.astronomy-shop.local"
    Write-Host "   - Prometheus: http://prometheus.astronomy-shop.local"
    Write-Host ""
}

# Main execution
Write-Host ""
Write-Host "Astronomy Shop Kubernetes Deployment Script" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

Write-Host "Configuration:"
Write-Host "  Namespace: $Namespace"
Write-Host "  Registry: $Registry"
Write-Host "  Image: ${ImageName}:${ImageTag}"
Write-Host ""

Check-Prerequisites
Check-Cluster
Build-Image
Create-Namespace
Deploy-ConfigMaps
Deploy-Observability
Deploy-Applications
Deploy-Networking
Display-Status

Write-Info "Deployment script completed successfully!"
