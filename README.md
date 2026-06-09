# Astronomy Shop Lite

A small, resource-conscious microservices project for learning distributed
tracing, metrics, and logs with OpenTelemetry.

This is a heavily simplified derivative of the
[OpenTelemetry Astronomy Shop](https://github.com/open-telemetry/opentelemetry-demo).
It keeps the learning value while removing services that are expensive or not
part of the requested flow.

## Architecture

```text
Browser -> Frontend -> Product Catalog
                    -> Cart -> Product Catalog
                    -> Checkout -> Cart

All services -> OpenTelemetry Collector
Collector -> Prometheus (metrics)
          -> Loki (logs)
          -> Tempo (traces)
Prometheus + Loki + Tempo -> Grafana
```

The cart is intentionally stored in memory, so restarting `cart` clears it.
This avoids PostgreSQL and Redis while learning. The four application
containers share one Python image to reduce Docker storage.

## Run

1. Make sure Docker has at least **6 GB free disk space** for the first build.
   A 3 GB RAM limit can work with these container limits, but 3 GB disk space
   is not enough for the application, observability images, and build cache.
2. If you previously ran the full upstream demo, stop or delete its containers
   in Docker Desktop first. They use the same ports and many have automatic
   restart enabled.
3. Start Docker Desktop.
4. From this folder, build and start:

   ```powershell
   docker compose up --build -d
   docker compose ps
   ```

5. Open the shop at <http://localhost:8080>.
6. Add products and complete a checkout to generate telemetry.
7. Open Grafana at <http://localhost:3000> and use **Explore**:
   - Prometheus query: `target_info`
   - Loki query: `{service_name=~".+"}`
   - Tempo: search by service name

Direct learning endpoints:

- Product Catalog: <http://localhost:3550/products>
- Cart: <http://localhost:7070/cart/demo-user>
- Prometheus: <http://localhost:9090>

## Run on AWS EKS (Kubernetes)

For production deployment or cloud-based learning, deploy to AWS EKS.

### Prerequisites

- **AWS Account** with appropriate permissions
- **AWS CLI** configured with credentials
- **kubectl** installed
- **helm** installed
- **Docker** for building and pushing images
- **eksctl** (optional, for easier cluster creation)

### Step 1: Create AWS EKS Cluster

```bash
# Option A: Using eksctl (simplest)
eksctl create cluster \
  --name astronomy-shop \
  --region us-east-1 \
  --nodes 3 \
  --node-type t3.medium

# Option B: Using AWS Console or CloudFormation
# Follow AWS documentation for manual setup
```

Update kubeconfig:
```bash
aws eks update-kubeconfig --region us-east-1 --name astronomy-shop
```

Verify cluster access:
```bash
kubectl cluster-info
kubectl get nodes
```

### Step 2: Install AWS Load Balancer Controller

Required for Ingress routing in AWS:

```bash
# Add Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=astronomy-shop
```

Verify installation:
```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### Step 3: Create Amazon ECR Repository

Push your Docker image to Amazon ECR:

```bash
# Set AWS account ID and region
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-1

# Create ECR repository
aws ecr create-repository \
  --repository-name astronomy-shop-lite-app \
  --region $AWS_REGION

# Get login password
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build image
docker build -t astronomy-shop-lite-app:latest .

# Tag for ECR
docker tag astronomy-shop-lite-app:latest \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/astronomy-shop-lite-app:latest

# Push to ECR
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/astronomy-shop-lite-app:latest
```

### Step 4: Update Kubernetes Manifests for AWS

Update `kubernetes/02-observability/pvcs.yaml` to use AWS EBS storage:

```yaml
spec:
  storageClassName: gp3  # AWS EBS storage class (or gp2 for older clusters)
  resources:
    requests:
      storage: 2Gi
```

Update all application deployments (`kubernetes/03-applications/*.yaml`) with ECR image:

```yaml
image: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/astronomy-shop-lite-app:latest
imagePullPolicy: IfNotPresent
```

Update `kubernetes/04-networking/ingress.yaml` for AWS:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: astronomy-shop-ingress
  namespace: astronomy-shop
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb  # AWS Load Balancer
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 8080
```

### Step 5: Deploy to EKS

```bash
# Navigate to project root
cd astronomy-shop

# Apply all manifests
kubectl apply -f kubernetes/

# Verify deployment
kubectl get pods -n astronomy-shop
kubectl get services -n astronomy-shop
kubectl get ingress -n astronomy-shop

# Wait for all pods to be ready (2-3 minutes)
kubectl wait --for=condition=ready pod \
  -l app in (frontend,product-catalog,cart,checkout) \
  -n astronomy-shop --timeout=300s
```

### Step 6: Get External URL

```bash
# Get the ALB (Application Load Balancer) DNS name
kubectl get ingress -n astronomy-shop -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'

# Output: k8s-astronomy-xxxxx-1234567890.us-east-1.elb.amazonaws.com
```

### Step 7: Access the Application

Use the ALB DNS name from above:

```
Frontend:    http://k8s-astronomy-xxxxx.us-east-1.elb.amazonaws.com/
Grafana:     http://k8s-astronomy-xxxxx.us-east-1.elb.amazonaws.com/grafana
Prometheus:  http://k8s-astronomy-xxxxx.us-east-1.elb.amazonaws.com/prometheus
```

Or use port forwarding for local access:

```bash
# Frontend
kubectl port-forward svc/frontend 8080:8080 -n astronomy-shop

# Grafana
kubectl port-forward svc/grafana 3000:3000 -n astronomy-shop

# Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n astronomy-shop
```

### Step 8: Generate Telemetry Data

1. Open the frontend in browser
2. Browse products
3. Add items to cart
4. Complete checkout
5. View data in Grafana:
   - **Metrics** (Prometheus)
   - **Logs** (Loki)
   - **Traces** (Tempo)

### AWS Deployment Checklist

- [ ] EKS cluster created and accessible
- [ ] AWS Load Balancer Controller installed
- [ ] ECR repository created
- [ ] Docker image pushed to ECR
- [ ] Manifests updated with ECR image URL
- [ ] Storage class set to `gp3` or `gp2`
- [ ] Ingress annotations updated for AWS ALB
- [ ] All manifests deployed with `kubectl apply`
- [ ] All pods running: `kubectl get pods -n astronomy-shop`
- [ ] Ingress has ALB DNS name
- [ ] Can access frontend via ALB URL
- [ ] Telemetry data visible in Grafana

### AWS Cost Optimization

For production deployments:

```bash
# Use Spot Instances to reduce costs
eksctl create nodegroup \
  --cluster=astronomy-shop \
  --name=spot-nodes \
  --spot \
  --instance-types=t3.medium,t3a.medium \
  --nodes=2

# Enable Cluster Autoscaler
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscovery.yaml
```

### Cleanup AWS Resources

```bash
# Delete Kubernetes resources
kubectl delete namespace astronomy-shop

# Delete ECR repository
aws ecr delete-repository \
  --repository-name astronomy-shop-lite-app \
  --region us-east-1 \
  --force

# Delete EKS cluster
eksctl delete cluster --name astronomy-shop --region us-east-1
```

**⚠️ Warning**: Deleting the cluster will incur charges for any remaining resources. Ensure all resources are properly deleted.

### AWS Deployment Documentation

For more details, see:
- [kubernetes/DEPLOYMENT_GUIDE.md](kubernetes/DEPLOYMENT_GUIDE.md) - Detailed Kubernetes instructions
- [kubernetes/ARCHITECTURE.md](kubernetes/ARCHITECTURE.md) - System architecture
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

## Learn In This Order

1. Read `compose.yaml` to understand containers, dependencies, limits, and
   ports.
2. Read `services/frontend/app.py`, then follow calls through cart and checkout.
3. Read `observability/otel-collector.yaml` to see the three telemetry
   pipelines.
4. Generate traffic in the shop and find one request in Tempo, Loki, and
   Prometheus.
5. Add a custom span or log field, rebuild, and confirm it appears in Grafana.
6. Later, add Redis to cart or PostgreSQL to product catalog as a separate
   learning phase.

## Resource And Cleanup Commands

The Compose file caps the full stack near 1.5 GB RAM and rotates container
logs. Telemetry data is retained for about 24 hours.

```powershell
# Check what Docker is using before deleting anything
docker system df

# Stop but keep telemetry data
docker compose down

# Stop and delete telemetry data
docker compose down -v

# Remove unused build cache and images when disk space is tight
docker builder prune -f
docker image prune -f
```

## Publish As Your Project

The original remote is named `upstream`. Create an empty GitHub repository,
then connect and publish your customized version:

```powershell
git remote add origin https://github.com/YOUR-NAME/astronomy-shop-lite.git
git add .
git commit -m "Build resource-friendly OpenTelemetry astronomy shop"
git push -u origin main
```

Describe it honestly as your customized learning implementation based on the
OpenTelemetry demo, and keep `LICENSE` plus `NOTICE.md`.
#   O b s e r v a b l e C o m m e r c e  
 