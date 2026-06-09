# Kubernetes Manifests Overview

This directory contains all Kubernetes manifests for deploying the Astronomy Shop Lite application with a complete observability stack.

## Directory Structure

```
kubernetes/
├── 00-namespace/           # Kubernetes namespace setup
│   └── namespace.yaml      # Creates 'astronomy-shop' namespace
├── 01-configmaps/          # Configuration management
│   ├── app-environment.yaml
│   ├── otel-collector-config.yaml
│   ├── prometheus-config.yaml
│   ├── loki-config.yaml
│   └── tempo-config.yaml
├── 02-observability/       # Observability stack
│   ├── pvcs.yaml           # Persistent volumes for storage
│   ├── otel-collector.yaml # OpenTelemetry collector
│   ├── prometheus.yaml     # Metrics collection
│   ├── loki.yaml           # Log aggregation
│   ├── tempo.yaml          # Distributed tracing
│   └── grafana.yaml        # Visualization dashboards
├── 03-applications/        # Microservices
│   ├── product-catalog.yaml
│   ├── cart.yaml
│   ├── checkout.yaml
│   └── frontend.yaml
├── 04-networking/          # Networking and scaling
│   ├── ingress.yaml        # External access
│   └── hpa.yaml            # Auto-scaling rules
├── DEPLOYMENT_GUIDE.md     # Detailed deployment instructions
├── deploy.sh               # Bash deployment script
├── deploy.ps1              # PowerShell deployment script
├── ARCHITECTURE.md         # System architecture overview
└── README.md               # This file
```

## Quick Deploy

### Option 1: Using Bash Script (Linux/macOS)

```bash
cd kubernetes
chmod +x deploy.sh
./deploy.sh
```

### Option 2: Using PowerShell Script (Windows)

```powershell
cd kubernetes
powershell -ExecutionPolicy Bypass -File deploy.ps1
```

### Option 3: Manual kubectl Apply

```bash
# Deploy everything at once
kubectl apply -f kubernetes/

# Or deploy step-by-step (see DEPLOYMENT_GUIDE.md)
```

## Component Descriptions

### Namespace (00-namespace/)
- Creates an isolated `astronomy-shop` namespace
- Organizes all resources in a single namespace

### ConfigMaps (01-configmaps/)
- **app-environment**: Common environment variables for all microservices
- **otel-collector-config**: OpenTelemetry Collector configuration
- **prometheus-config**: Prometheus scrape targets
- **loki-config**: Loki storage and retention policies
- **tempo-config**: Tempo trace storage backend

### Observability Stack (02-observability/)

**Storage (pvcs.yaml)**
- Prometheus Data: 2Gi
- Loki Data: 2Gi
- Tempo Data: 3Gi

**Components**
- **otel-collector**: Receives metrics, traces, and logs from all services
- **prometheus**: Collects and stores metrics
- **loki**: Aggregates logs
- **tempo**: Stores distributed traces
- **grafana**: Unified visualization dashboard

### Microservices (03-applications/)

All services deployed with:
- **2 replicas** by default (auto-scales up to 5)
- **Health checks** (liveness and readiness probes)
- **Resource limits** (250m CPU, 128Mi memory request)
- **Environment variables** from ConfigMaps
- **Service discovery** via Kubernetes DNS

**Services**:
- **Frontend**: Web UI (port 8080)
- **Product Catalog**: API for products (port 3550)
- **Cart**: Shopping cart service (port 7070)
- **Checkout**: Checkout processing (port 5050)

### Networking (04-networking/)

**Ingress (ingress.yaml)**
- Routes external traffic to internal services
- Supports multiple hostnames:
  - `astronomy-shop.local` → Frontend
  - `grafana.astronomy-shop.local` → Grafana
  - `prometheus.astronomy-shop.local` → Prometheus

**HorizontalPodAutoscaler (hpa.yaml)**
- Auto-scales each service based on CPU/memory usage
- Min: 2 replicas, Max: 5 replicas
- Triggers: 70% CPU or 80% memory utilization

## Resource Requirements

Total cluster requirements:
- **CPU**: ~3-4 cores (with headroom for autoscaling)
- **Memory**: ~3-4 GB (with headroom for autoscaling)
- **Storage**: ~10 Gi (PVCs for observability data)

Per service:
- **Microservices**: 250m CPU, 128Mi memory (request)
- **Observability**: 500m CPU, 192Mi memory (request)

## Key Features

### High Availability
- Multiple replicas for each microservice
- Liveness and readiness probes
- Auto-scaling based on resource usage

### Observability
- **Traces**: See request flows through all services
- **Metrics**: Monitor CPU, memory, request rates
- **Logs**: Centralized logging with structured metadata

### Security
- Namespace isolation
- Network policies for traffic control
- Service accounts (can be enhanced with RBAC)

### Scalability
- Horizontal Pod Autoscaling
- Resource limits for stable performance
- ConfigMap-based configuration (no rebuilds for config changes)

## Customization

### Change Image Registry

Edit deployments and update the `image` field:

```yaml
image: your-registry.com/astronomy-shop-lite-app:latest
imagePullPolicy: IfNotPresent
```

### Adjust Resource Limits

Edit deployments to change resources:

```yaml
resources:
  requests:
    cpu: 100m          # Adjust as needed
    memory: 64Mi
  limits:
    cpu: 250m
    memory: 256Mi
```

### Enable TLS/HTTPS

Update ingress.yaml to use HTTPS:

```yaml
spec:
  tls:
  - hosts:
    - astronomy-shop.local
    secretName: tls-secret
```

### Change Replica Counts

Edit deployments:

```yaml
spec:
  replicas: 3  # Change from 2
```

Or use kubectl:

```bash
kubectl scale deployment frontend --replicas=5 -n astronomy-shop
```

## Monitoring and Debugging

### View Pod Logs

```bash
kubectl logs -f deployment/frontend -n astronomy-shop
```

### Execute Commands in Pod

```bash
kubectl exec -it pod/frontend-xxxxx -n astronomy-shop -- /bin/bash
```

### Port Forward for Local Access

```bash
kubectl port-forward svc/grafana 3000:3000 -n astronomy-shop
```

### Watch Deployment Status

```bash
kubectl rollout status deployment/frontend -n astronomy-shop
```

## Cleanup

```bash
# Delete entire namespace
kubectl delete namespace astronomy-shop

# Delete specific manifests
kubectl delete -f kubernetes/04-networking/
```

## Production Deployment Checklist

- [ ] Use private container registry with authentication
- [ ] Enable HTTPS with valid TLS certificates
- [ ] Set resource requests/limits appropriately
- [ ] Configure persistent volumes with appropriate storage class
- [ ] Set up Pod Disruption Budgets for reliability
- [ ] Configure Network Policies for security
- [ ] Create ServiceAccounts with minimal RBAC permissions
- [ ] Set up Secrets for sensitive data
- [ ] Enable pod security policies
- [ ] Configure backup strategy for PVs
- [ ] Set up alerting for observability stack
- [ ] Test disaster recovery procedures

## Troubleshooting

See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for detailed troubleshooting steps.

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Deployment Guide](DEPLOYMENT_GUIDE.md)
- [Architecture Overview](ARCHITECTURE.md)
- [Main README](../README.md)
