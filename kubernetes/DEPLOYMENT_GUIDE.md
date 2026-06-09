# Kubernetes Deployment Guide for Astronomy Shop

This guide walks through deploying the Astronomy Shop Lite application to Kubernetes with full observability stack.

## Prerequisites

1. **Kubernetes Cluster** (v1.24+)
   - Local options: Docker Desktop, Minikube, Kind, Colima
   - Cloud options: EKS, GKE, AKS

2. **Container Registry**
   - Docker Hub, ECR, GCR, or private registry

3. **Tools Installed**
   - `kubectl` configured to access your cluster
   - `docker` for building images
   - `helm` (optional, for package management)

## Quick Start

### Step 1: Build and Push the Docker Image

```bash
# Build the Docker image
docker build -t astronomy-shop-lite-app:latest .

# Tag for your registry (example: Docker Hub)
docker tag astronomy-shop-lite-app:latest <your-registry>/astronomy-shop-lite-app:latest

# Push to registry
docker push <your-registry>/astronomy-shop-lite-app:latest
```

**Note:** If using a private registry, create an image pull secret:
```bash
kubectl create secret docker-registry regcred \
  --docker-server=<registry-server> \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email> \
  -n astronomy-shop
```

### Step 2: Deploy to Kubernetes

#### Option A: Apply All Manifests at Once

```bash
# Create namespace and deploy everything
kubectl apply -f kubernetes/

# Monitor the deployment
kubectl get pods -n astronomy-shop -w
```

#### Option B: Apply Step-by-Step (Recommended for Learning)

```bash
# 1. Create namespace
kubectl apply -f kubernetes/00-namespace/namespace.yaml

# 2. Create ConfigMaps
kubectl apply -f kubernetes/01-configmaps/

# 3. Create observability stack PVCs
kubectl apply -f kubernetes/02-observability/pvcs.yaml

# Wait for PVCs to be bound
kubectl get pvc -n astronomy-shop

# 4. Deploy observability stack (in order)
kubectl apply -f kubernetes/02-observability/otel-collector.yaml
kubectl apply -f kubernetes/02-observability/prometheus.yaml
kubectl apply -f kubernetes/02-observability/loki.yaml
kubectl apply -f kubernetes/02-observability/tempo.yaml
kubectl apply -f kubernetes/02-observability/grafana.yaml

# Wait for all observability pods to be ready
kubectl wait --for=condition=ready pod \
  -l app=loki,app=tempo,app=prometheus,app=otel-collector,app=grafana \
  -n astronomy-shop --timeout=300s

# 5. Deploy application services
kubectl apply -f kubernetes/03-applications/product-catalog.yaml
kubectl apply -f kubernetes/03-applications/cart.yaml
kubectl apply -f kubernetes/03-applications/checkout.yaml
kubectl apply -f kubernetes/03-applications/frontend.yaml

# Wait for all application pods to be ready
kubectl wait --for=condition=ready pod \
  -l app=frontend,app=product-catalog,app=cart,app=checkout \
  -n astronomy-shop --timeout=300s

# 6. Apply networking (Ingress and HPA)
kubectl apply -f kubernetes/04-networking/ingress.yaml
kubectl apply -f kubernetes/04-networking/hpa.yaml
```

## Verification

### Check Pod Status

```bash
# List all pods
kubectl get pods -n astronomy-shop

# Check a specific pod
kubectl describe pod <pod-name> -n astronomy-shop

# View pod logs
kubectl logs -f <pod-name> -n astronomy-shop -c <container-name>
```

### Check Services

```bash
# List all services
kubectl get svc -n astronomy-shop

# Check Ingress
kubectl get ingress -n astronomy-shop

# Describe Ingress details
kubectl describe ingress astronomy-shop-ingress -n astronomy-shop
```

### Port Forwarding (if not using Ingress)

```bash
# Frontend (web UI)
kubectl port-forward svc/frontend 8080:8080 -n astronomy-shop

# Grafana (observability dashboards)
kubectl port-forward svc/grafana 3000:3000 -n astronomy-shop

# Prometheus (metrics)
kubectl port-forward svc/prometheus 9090:9090 -n astronomy-shop
```

Access via:
- Frontend: http://localhost:8080
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090

### Using Ingress (DNS Required)

1. **Get Ingress IP**
   ```bash
   kubectl get ingress astronomy-shop-ingress -n astronomy-shop
   ```

2. **Add to /etc/hosts** (or your OS equivalent):
   ```
   <INGRESS_IP> astronomy-shop.local
   <INGRESS_IP> grafana.astronomy-shop.local
   <INGRESS_IP> prometheus.astronomy-shop.local
   ```

3. **Access via hostnames**:
   - http://astronomy-shop.local
   - http://grafana.astronomy-shop.local
   - http://prometheus.astronomy-shop.local

## Generate Telemetry Data

1. Open the frontend at the address above
2. Browse products
3. Add items to cart
4. Complete a checkout
5. This generates traces, metrics, and logs

## View Observability Data

### In Grafana

1. Navigate to Grafana dashboard
2. Use **Explore** tab:
   - **Prometheus**: Query metrics like `target_info`
   - **Loki**: Query logs with `{service_name=~".+"}`
   - **Tempo**: Search traces by service name

### Key Queries

**Prometheus** (Metrics):
```promql
target_info
rate(otel_traces_received_total[5m])
```

**Loki** (Logs):
```
{service_name=~".+"}
{service_name="frontend"}
```

**Tempo** (Traces):
- Use Service Name search
- Click through to view trace flows

## Scaling and Auto-Scaling

### Manual Scaling

```bash
# Scale frontend to 5 replicas
kubectl scale deployment frontend --replicas=5 -n astronomy-shop

# Check HPA status
kubectl get hpa -n astronomy-shop
```

### Auto-Scaling (HPA)

The deployment includes HorizontalPodAutoscalers that automatically scale based on CPU and memory usage:
- Min replicas: 2
- Max replicas: 5
- CPU threshold: 70%
- Memory threshold: 80%

Monitor HPA:
```bash
kubectl get hpa -n astronomy-shop -w
```

## Configuration Management

### Update Application Configuration

Edit ConfigMaps:
```bash
# Edit app environment variables
kubectl edit configmap app-environment -n astronomy-shop

# Edit OTEL collector config
kubectl edit configmap otel-collector-config -n astronomy-shop
```

Restart affected deployments after editing ConfigMaps:
```bash
kubectl rollout restart deployment/frontend -n astronomy-shop
kubectl rollout restart deployment/otel-collector -n astronomy-shop
```

### Update Resource Limits

Edit deployment resource requests/limits:
```bash
kubectl edit deployment frontend -n astronomy-shop
```

## Troubleshooting

### Pod Stuck in Pending

```bash
# Check PVC status
kubectl get pvc -n astronomy-shop

# Describe node to check capacity
kubectl describe nodes
```

### Pod CrashLoopBackOff

```bash
# Check logs
kubectl logs -f <pod-name> -n astronomy-shop --previous

# Describe pod for errors
kubectl describe pod <pod-name> -n astronomy-shop
```

### Service Discovery Issues

Verify internal DNS:
```bash
# Get a pod shell
kubectl exec -it <pod-name> -n astronomy-shop -- /bin/bash

# Test DNS resolution
nslookup otel-collector
nslookup product-catalog
```

### Observability Not Working

Check OTEL collector connectivity:
```bash
# Check collector logs
kubectl logs -f deployment/otel-collector -n astronomy-shop

# Verify services are discoverable
kubectl get svc -n astronomy-shop
```

## Cleanup

### Delete Everything

```bash
# Delete all resources in the namespace
kubectl delete namespace astronomy-shop

# Or selectively delete:
kubectl delete -f kubernetes/04-networking/
kubectl delete -f kubernetes/03-applications/
kubectl delete -f kubernetes/02-observability/
kubectl delete -f kubernetes/01-configmaps/
kubectl delete -f kubernetes/00-namespace/
```

### Cleanup Persistent Data

```bash
# Delete PVCs (persistent data)
kubectl delete pvc -n astronomy-shop --all

# Delete PVs if not auto-cleaned
kubectl delete pv <pv-name>
```

## Production Considerations

1. **Container Registry**: Use private registry with proper authentication
2. **TLS/Certificates**: Enable HTTPS with cert-manager
3. **Persistence**: Use managed storage (EBS, GCS, etc.)
4. **Monitoring**: Set up cluster monitoring with Prometheus Operator
5. **Resource Quotas**: Define namespace resource quotas
6. **Network Policies**: Enforce network policies for security
7. **RBAC**: Create specific service accounts with minimal permissions
8. **Secrets Management**: Use sealed-secrets or external-secrets operator
9. **GitOps**: Use ArgoCD or Flux for declarative deployments
10. **Multi-Zone**: Use Pod Disruption Budgets for high availability

## Advanced: Using Helm

### Create Helm Chart

```bash
helm create astronomy-shop
# Modify values.yaml with image registry and other settings
# Update templates/ with manifests from kubernetes/
```

### Deploy with Helm

```bash
helm install astronomy-shop ./astronomy-shop \
  --namespace astronomy-shop \
  --create-namespace \
  --values values.yaml
```

## Further Learning

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [OpenTelemetry Best Practices](https://opentelemetry.io/docs/)
- [Prometheus Query Language](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
