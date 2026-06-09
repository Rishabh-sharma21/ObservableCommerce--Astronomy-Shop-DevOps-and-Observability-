# Architecture Overview - Astronomy Shop on Kubernetes

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        External Access (Ingress)                            │
│                                                                             │
│    astronomy-shop.local ──┬── grafana.astronomy-shop.local                  │
│                           └── prometheus.astronomy-shop.local               │
└──────────────┬────────────────────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster: astronomy-shop ns                   │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                    Load Balancer / Ingress                         │    │
│  │  Routes: / → frontend:8080                                        │    │
│  │          /api/products → product-catalog:3550                     │    │
│  │          /api/cart → cart:7070                                    │    │
│  │          /api/checkout → checkout:5050                           │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                 │                                           │
│         ┌───────────────────────┴───────────────────────┐                   │
│         │                                               │                   │
│         ▼                                               ▼                   │
│  ┌──────────────────────┐                      ┌──────────────────────┐    │
│  │   Frontend Pods      │                      │  Grafana Pod         │    │
│  │  (flask:8080) ×2     │                      │  (port 3000)  ×1     │    │
│  │  (HPA: 2-5 replicas) │                      └──────────────────────┘    │
│  └──────────────────────┘                                                  │
│         │       │                                                           │
│         │       ▼                                                           │
│         │  ┌──────────────────────┐    ┌──────────────────────┐            │
│         │  │  Product Catalog     │    │  Prometheus Pod      │            │
│         │  │  (flask:3550) ×2     │    │  (port 9090) ×1      │            │
│         │  │  (HPA: 2-5 replicas) │    └──────────────────────┘            │
│         │  └──────────────────────┘            ▲                           │
│         │         ▲   │                        │                           │
│         ▼         │   ▼                        │                           │
│  ┌──────────────────────┐                      │                           │
│  │  Cart Pods           │                      │                           │
│  │  (flask:7070) ×2     │    ┌──────────────────────┐                      │
│  │  (HPA: 2-5 replicas) │    │  OTEL Collector      │                      │
│  └──────────────────────┘    │  (port 4317,4318) ×1 │                      │
│         │                    │  gRPC + HTTP         │                      │
│         ▼                    └──────────────────────┘______               │
│  ┌──────────────────────┐            │                     │              │
│  │  Checkout Pods       │            ▼                     ▼              │
│  │  (flask:5050) ×2     │    ┌──────────────────────┐    ┌──────────────┐ │
│  │  (HPA: 2-5 replicas) │    │  Loki Pod            │    │  Tempo Pod   │ │
│  └──────────────────────┘    │  (port 3100) ×1      │    │  (port 3200) │ │
│         │                    │  (PVC: 2Gi)          │    │  (PVC: 3Gi)  │ │
│         └────────────────────┤                      │    │              │ │
│                              └──────────────────────┘    └──────────────┘ │
│                                                                             │
│                         All pods → OTEL Collector                          │
│                         Collector → Prometheus, Loki, Tempo                │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────┐    │
│  │                    ConfigMaps (Shared Configuration)              │    │
│  │  • app-environment: Common env vars (OTEL endpoints, service URLs)│    │
│  │  • otel-collector-config: Telemetry pipeline configuration       │    │
│  │  • prometheus-config: Metric collection targets                  │    │
│  │  • loki-config: Log storage and retention                        │    │
│  │  • tempo-config: Trace storage backend                           │    │
│  └───────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────┐    │
│  │              Persistent Volumes (Storage)                        │    │
│  │  • prometheus-data: /prometheus (2Gi)                            │    │
│  │  • loki-data: /loki (2Gi)                                        │    │
│  │  • tempo-data: /var/tempo (3Gi)                                  │    │
│  └───────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Request Flow

```
Browser Request → Ingress → Frontend Pod
                             ├─→ Product Catalog Pod (via HTTP)
                             ├─→ Cart Pod (via HTTP)
                             └─→ Checkout Pod (via HTTP)
                                  ├─→ Cart Pod (via HTTP)
                                  └─→ Product Catalog Pod (via HTTP)
```

### 2. Telemetry Flow

```
All Pods (OpenTelemetry instrumentation)
  │
  ├─ Traces ─┐
  ├─ Metrics ├─→ OTEL Collector gRPC/HTTP (4317/4318)
  └─ Logs ───┤                  │
             │     ┌────────────┼────────────┐
             │     ▼            ▼            ▼
             │  Prometheus   Loki        Tempo
             │     │           │            │
             └─────▼───────────▼────────────▼
                    │
                    ▼
                Grafana (3000)
                    │
                    ▼
              Dashboard View
```

## Kubernetes Resources by Type

### Deployments (9)
- **frontend**: 2 replicas, scales to 5
- **product-catalog**: 2 replicas, scales to 5
- **cart**: 2 replicas, scales to 5
- **checkout**: 2 replicas, scales to 5
- **otel-collector**: 1 replica (stateless)
- **prometheus**: 1 replica (with PVC)
- **loki**: 1 replica (with PVC)
- **tempo**: 1 replica (with PVC)
- **grafana**: 1 replica (ephemeral, recovers from datasources config)

### Services (9)
- ClusterIP services for all deployments
- Enables service discovery via Kubernetes DNS
- Internal communication between services

### Ingress (1)
- Routes external traffic to internal services
- Hosts configured for local DNS

### PersistentVolumeClaims (3)
- prometheus-data: 2Gi
- loki-data: 2Gi
- tempo-data: 3Gi

### ConfigMaps (5)
- app-environment
- otel-collector-config
- prometheus-config
- loki-config
- tempo-config

### HorizontalPodAutoscalers (4)
- frontend-hpa: 2-5 replicas
- product-catalog-hpa: 2-5 replicas
- cart-hpa: 2-5 replicas
- checkout-hpa: 2-5 replicas

### NetworkPolicy (1)
- Restricts ingress/egress traffic to/from namespace

## Service Dependencies

```
frontend
  ├─ depends: product-catalog (HTTP)
  ├─ depends: cart (HTTP)
  ├─ depends: checkout (HTTP)
  └─ depends: otel-collector

product-catalog
  └─ depends: otel-collector

cart
  ├─ depends: product-catalog (HTTP)
  └─ depends: otel-collector

checkout
  ├─ depends: cart (HTTP)
  └─ depends: otel-collector

otel-collector
  ├─ depends: prometheus
  ├─ depends: loki
  └─ depends: tempo
```

## Configuration Management

### Environment Variables
All microservices receive environment variables from `app-environment` ConfigMap:
- `OTEL_EXPORTER_OTLP_ENDPOINT`: OTEL Collector endpoint
- `OTEL_SERVICE_NAME`: Service identifier
- `PRODUCT_CATALOG_URL`: Discovery URL
- `CART_URL`: Discovery URL
- `CHECKOUT_URL`: Discovery URL

Changes to ConfigMaps require pod restarts:
```bash
kubectl rollout restart deployment/<service> -n astronomy-shop
```

### Observability Configuration
Each observability component reads its configuration from a dedicated ConfigMap:
- OTEL Collector: Defines telemetry pipelines
- Prometheus: Defines scrape targets
- Loki: Defines storage backend
- Tempo: Defines trace storage

## High Availability Features

### Pod Disruption Budgets
Can be added to ensure minimum availability during cluster maintenance:
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: frontend-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: frontend
```

### Health Checks
All pods have:
- **Liveness Probe**: Detects stuck/crashed containers
- **Readiness Probe**: Removes unhealthy pods from service load balancing

### Auto-Scaling
HPA triggers scaling based on:
- CPU utilization > 70%
- Memory utilization > 80%

## Networking

### Service Discovery
Services are discoverable via Kubernetes DNS:
- `frontend.astronomy-shop.svc.cluster.local`
- `cart.astronomy-shop.svc.cluster.local`
- `product-catalog.astronomy-shop.svc.cluster.local`
- `checkout.astronomy-shop.svc.cluster.local`
- `otel-collector.astronomy-shop.svc.cluster.local`

### External Access
Two options:

1. **Port Forwarding** (Development)
   ```bash
   kubectl port-forward svc/frontend 8080:8080 -n astronomy-shop
   ```

2. **Ingress** (Production)
   - Requires DNS setup or /etc/hosts entry
   - Load balancer assigns external IP/hostname

## Resource Utilization

### Memory
- Per microservice: 128Mi request, 128Mi limit
- Observability: 192-256Mi request/limit
- Total: ~2GB minimum for full stack

### CPU
- Per microservice: 250m request, 500m limit
- Observability: 250-500m request/limit
- Total: ~3-4 cores for full stack

### Storage
- Prometheus: 2Gi, ~24 hours retention
- Loki: 2Gi, ~24 hours retention
- Tempo: 3Gi, ~24 hours retention

## Monitoring and Observability

### Metrics (Prometheus)
- Container CPU usage
- Container memory usage
- HTTP request rates
- HTTP request latency

### Logs (Loki)
- Structured logs from all services
- Searchable by service name, pod name
- Retention: 24 hours

### Traces (Tempo)
- Full request traces through all services
- Span-level timing information
- Trace-to-logs correlation

### Dashboards (Grafana)
- Pre-configured with Prometheus, Loki, Tempo data sources
- Interactive exploration of metrics, logs, and traces

## Security Considerations

### Current Setup (Development)
- No authentication (GF_AUTH_ANONYMOUS_ENABLED=true)
- No RBAC restrictions
- No network policies blocking traffic
- Services accessible from any namespace

### Production Hardening
- [ ] Enable HTTPS/TLS on ingress
- [ ] Configure RBAC for service accounts
- [ ] Enable Pod Security Policies
- [ ] Restrict network policies
- [ ] Use sealed-secrets for sensitive data
- [ ] Enable audit logging
- [ ] Use private container registry with auth
- [ ] Implement backup/disaster recovery

## Disaster Recovery

### Backup Strategy
1. ConfigMaps: Version controlled in git
2. PVCs: Use PV snapshots or external backup tools
3. Application state: Cart is ephemeral, no backup needed

### Recovery Procedure
1. Recreate namespace: `kubectl apply -f kubernetes/00-namespace/`
2. Recreate ConfigMaps: `kubectl apply -f kubernetes/01-configmaps/`
3. Restore PVCs from backup
4. Redeploy stack: `kubectl apply -f kubernetes/`

## Scaling Considerations

### Horizontal Scaling
- Microservices: Auto-scale based on CPU/memory (2-5 replicas)
- Observability: Currently single-instance (can be clustered)
- Database layer: Not present in this version

### Vertical Scaling
- Increase resource requests/limits in deployment manifests
- Requires pod restart

### Geographic Distribution
- Multi-region: Use multi-cluster tools (e.g., Istio, Linkerd)
- Load balancing: Configure ingress with multiple backends

## References

- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [OpenTelemetry Deployment Guide](https://opentelemetry.io/docs/deploying/)
- [Grafana in Kubernetes](https://grafana.com/docs/grafana/latest/setup-grafana/installation/kubernetes/)
- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)
