#!/bin/bash
# Kubernetes Deployment Script for Astronomy Shop
# This script automates the deployment of the astronomy shop to Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="astronomy-shop"
REGISTRY="${DOCKER_REGISTRY:-docker.io}"
IMAGE_NAME="${IMAGE_NAME:-astronomy-shop-lite-app}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

echo -e "${GREEN}Astronomy Shop Kubernetes Deployment Script${NC}"
echo "=============================================="

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print info
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Function to print warning
warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Function to print error
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    if ! command_exists kubectl; then
        error "kubectl is not installed"
        exit 1
    fi
    
    if ! command_exists docker; then
        warn "docker is not installed (required to build image)"
    fi
    
    info "✓ Prerequisites check passed"
}

# Check cluster connectivity
check_cluster() {
    info "Checking Kubernetes cluster connectivity..."
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        error "Cannot connect to Kubernetes cluster"
        echo "Make sure kubectl is configured correctly"
        exit 1
    fi
    
    CLUSTER_VERSION=$(kubectl version --short 2>/dev/null | grep Server)
    info "Connected to cluster: $CLUSTER_VERSION"
}

# Build Docker image
build_image() {
    if [ "$SKIP_BUILD" == "true" ]; then
        warn "Skipping image build (SKIP_BUILD=true)"
        return
    fi
    
    info "Building Docker image..."
    
    if ! command_exists docker; then
        error "docker is required to build the image"
        exit 1
    fi
    
    # Check if Dockerfile exists
    if [ ! -f "Dockerfile" ]; then
        error "Dockerfile not found in current directory"
        exit 1
    fi
    
    docker build -t "$IMAGE_NAME:$IMAGE_TAG" .
    
    if [ "$REGISTRY" != "local" ]; then
        info "Tagging image for registry: $REGISTRY"
        docker tag "$IMAGE_NAME:$IMAGE_TAG" "$REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
        
        info "Pushing image to registry..."
        docker push "$REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
    fi
    
    info "✓ Image built successfully"
}

# Create namespace
create_namespace() {
    info "Creating namespace: $NAMESPACE"
    
    kubectl apply -f kubernetes/00-namespace/namespace.yaml
    
    # Wait for namespace to be created
    kubectl wait --for condition=Active namespace/$NAMESPACE --timeout=10s 2>/dev/null || true
    
    info "✓ Namespace created"
}

# Deploy ConfigMaps
deploy_configmaps() {
    info "Deploying ConfigMaps..."
    
    kubectl apply -f kubernetes/01-configmaps/
    
    # Wait for ConfigMaps to be created
    sleep 2
    
    info "✓ ConfigMaps deployed"
}

# Deploy observability stack
deploy_observability() {
    info "Deploying observability stack..."
    
    # Create PVCs first
    info "Creating persistent volume claims..."
    kubectl apply -f kubernetes/02-observability/pvcs.yaml
    
    # Wait for PVCs to be bound
    info "Waiting for PVCs to be bound..."
    kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc -n $NAMESPACE --all --timeout=60s 2>/dev/null || {
        warn "PVCs not bound yet, proceeding anyway"
    }
    
    # Deploy each component
    info "Deploying OpenTelemetry Collector..."
    kubectl apply -f kubernetes/02-observability/otel-collector.yaml
    
    info "Deploying Prometheus..."
    kubectl apply -f kubernetes/02-observability/prometheus.yaml
    
    info "Deploying Loki..."
    kubectl apply -f kubernetes/02-observability/loki.yaml
    
    info "Deploying Tempo..."
    kubectl apply -f kubernetes/02-observability/tempo.yaml
    
    info "Deploying Grafana..."
    kubectl apply -f kubernetes/02-observability/grafana.yaml
    
    info "Waiting for observability stack to be ready (this may take 2-3 minutes)..."
    kubectl wait --for=condition=ready pod \
        -l app in (loki,tempo,prometheus,otel-collector,grafana) \
        -n $NAMESPACE --timeout=300s 2>/dev/null || {
        warn "Timeout waiting for observability stack"
    }
    
    info "✓ Observability stack deployed"
}

# Deploy applications
deploy_applications() {
    info "Deploying application services..."
    
    info "Deploying Product Catalog..."
    kubectl apply -f kubernetes/03-applications/product-catalog.yaml
    
    info "Deploying Cart..."
    kubectl apply -f kubernetes/03-applications/cart.yaml
    
    info "Deploying Checkout..."
    kubectl apply -f kubernetes/03-applications/checkout.yaml
    
    info "Deploying Frontend..."
    kubectl apply -f kubernetes/03-applications/frontend.yaml
    
    info "Waiting for application services to be ready..."
    kubectl wait --for=condition=ready pod \
        -l app in (frontend,product-catalog,cart,checkout) \
        -n $NAMESPACE --timeout=300s 2>/dev/null || {
        warn "Timeout waiting for application services"
    }
    
    info "✓ Application services deployed"
}

# Deploy networking
deploy_networking() {
    info "Deploying networking and auto-scaling..."
    
    kubectl apply -f kubernetes/04-networking/ingress.yaml
    kubectl apply -f kubernetes/04-networking/hpa.yaml
    
    info "✓ Networking and auto-scaling deployed"
}

# Display status and access information
display_status() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Deployment Completed Successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    
    echo "Pod Status:"
    kubectl get pods -n $NAMESPACE
    
    echo ""
    echo "Service Status:"
    kubectl get svc -n $NAMESPACE
    
    echo ""
    echo "Ingress Status:"
    kubectl get ingress -n $NAMESPACE
    
    echo ""
    echo -e "${YELLOW}Access Instructions:${NC}"
    echo ""
    echo "1. Port Forwarding (Quick Access):"
    echo "   Frontend:   kubectl port-forward svc/frontend 8080:8080 -n $NAMESPACE"
    echo "   Grafana:    kubectl port-forward svc/grafana 3000:3000 -n $NAMESPACE"
    echo "   Prometheus: kubectl port-forward svc/prometheus 9090:9090 -n $NAMESPACE"
    echo ""
    echo "2. Ingress (DNS Required):"
    
    INGRESS_IP=$(kubectl get ingress astronomy-shop-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "PENDING")
    INGRESS_HOST=$(kubectl get ingress astronomy-shop-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "PENDING")
    
    if [ "$INGRESS_IP" != "PENDING" ]; then
        echo "   Ingress IP: $INGRESS_IP"
        echo "   Add to /etc/hosts: $INGRESS_IP astronomy-shop.local"
    elif [ "$INGRESS_HOST" != "PENDING" ]; then
        echo "   Ingress Host: $INGRESS_HOST"
    else
        echo "   Ingress Address: PENDING (may take a few minutes)"
    fi
    
    echo ""
    echo "   URLs:"
    echo "   - Frontend:   http://astronomy-shop.local"
    echo "   - Grafana:    http://grafana.astronomy-shop.local"
    echo "   - Prometheus: http://prometheus.astronomy-shop.local"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Generate telemetry: Browse products, add to cart, checkout"
    echo "2. View traces in Grafana > Explore > Tempo"
    echo "3. View metrics in Grafana > Explore > Prometheus"
    echo "4. View logs in Grafana > Explore > Loki"
    echo ""
}

# Main execution
main() {
    echo "Configuration:"
    echo "  Namespace: $NAMESPACE"
    echo "  Registry: $REGISTRY"
    echo "  Image: $IMAGE_NAME:$IMAGE_TAG"
    echo ""
    
    check_prerequisites
    check_cluster
    build_image
    create_namespace
    deploy_configmaps
    deploy_observability
    deploy_applications
    deploy_networking
    display_status
    
    info "Deployment script completed successfully!"
}

# Run main function
main
