# Quick Reference - Common Kubernetes Commands

## Cluster Information

```bash
# Get cluster info
kubectl cluster-info

# Get current context
kubectl config current-context

# List all contexts
kubectl config get-contexts

# Switch context
kubectl config use-context <context-name>
```

## Namespace Operations

```bash
# List namespaces
kubectl get namespaces

# Create namespace
kubectl create namespace astronomy-shop

# Delete namespace (deletes all resources in it)
kubectl delete namespace astronomy-shop

# Set default namespace
kubectl config set-context --current --namespace=astronomy-shop

# Get all resources in namespace
kubectl api-resources --no-headers=true | awk '{print $1}' | xargs -I {} kubectl get {} -n astronomy-shop
```

## Pod Operations

```bash
# List pods
kubectl get pods -n astronomy-shop

# List pods with more details
kubectl get pods -n astronomy-shop -o wide

# Watch pods (continuous output)
kubectl get pods -n astronomy-shop -w

# Describe pod
kubectl describe pod <pod-name> -n astronomy-shop

# Get pod logs
kubectl logs <pod-name> -n astronomy-shop

# Get logs from specific container
kubectl logs <pod-name> -c <container-name> -n astronomy-shop

# Stream logs (follow)
kubectl logs -f <pod-name> -n astronomy-shop

# Get previous logs (if pod restarted)
kubectl logs <pod-name> --previous -n astronomy-shop

# Execute command in pod
kubectl exec <pod-name> -n astronomy-shop -- <command>

# Interactive shell in pod
kubectl exec -it <pod-name> -n astronomy-shop -- /bin/bash

# Copy file from pod
kubectl cp <namespace>/<pod-name>:<path> <local-path> -n astronomy-shop

# Delete pod
kubectl delete pod <pod-name> -n astronomy-shop

# Delete all pods in namespace
kubectl delete pods --all -n astronomy-shop
```

## Deployment Operations

```bash
# List deployments
kubectl get deployments -n astronomy-shop

# Get deployment details
kubectl describe deployment <deployment-name> -n astronomy-shop

# Scale deployment
kubectl scale deployment <deployment-name> --replicas=3 -n astronomy-shop

# Update deployment (e.g., change image)
kubectl set image deployment/<deployment-name> <container-name>=<new-image>:<tag> -n astronomy-shop

# Restart deployment (rolling)
kubectl rollout restart deployment/<deployment-name> -n astronomy-shop

# Check rollout status
kubectl rollout status deployment/<deployment-name> -n astronomy-shop

# Undo last rollout
kubectl rollout undo deployment/<deployment-name> -n astronomy-shop

# Rollout history
kubectl rollout history deployment/<deployment-name> -n astronomy-shop

# Delete deployment
kubectl delete deployment <deployment-name> -n astronomy-shop

# Edit deployment
kubectl edit deployment <deployment-name> -n astronomy-shop
```

## Service Operations

```bash
# List services
kubectl get services -n astronomy-shop

# Describe service
kubectl describe service <service-name> -n astronomy-shop

# Get service endpoints
kubectl get endpoints <service-name> -n astronomy-shop

# Create port forward (for local access)
kubectl port-forward svc/<service-name> <local-port>:<service-port> -n astronomy-shop

# Delete service
kubectl delete service <service-name> -n astronomy-shop

# Edit service
kubectl edit service <service-name> -n astronomy-shop
```

## ConfigMap Operations

```bash
# List ConfigMaps
kubectl get configmap -n astronomy-shop

# Get ConfigMap contents
kubectl get configmap <configmap-name> -o yaml -n astronomy-shop

# Create ConfigMap from file
kubectl create configmap <name> --from-file=<file-path> -n astronomy-shop

# Edit ConfigMap
kubectl edit configmap <configmap-name> -n astronomy-shop

# Delete ConfigMap
kubectl delete configmap <configmap-name> -n astronomy-shop

# View specific key in ConfigMap
kubectl get configmap <configmap-name> -o jsonpath='{.data.key-name}' -n astronomy-shop
```

## Secret Operations

```bash
# List secrets
kubectl get secrets -n astronomy-shop

# Create secret (generic)
kubectl create secret generic <secret-name> --from-literal=key=value -n astronomy-shop

# Create secret (docker registry)
kubectl create secret docker-registry <secret-name> \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<pass> \
  -n astronomy-shop

# View secret (base64 encoded)
kubectl get secret <secret-name> -o yaml -n astronomy-shop

# Delete secret
kubectl delete secret <secret-name> -n astronomy-shop
```

## Persistent Volume Operations

```bash
# List PVs
kubectl get pv

# List PVCs
kubectl get pvc -n astronomy-shop

# Describe PVC
kubectl describe pvc <pvc-name> -n astronomy-shop

# Delete PVC
kubectl delete pvc <pvc-name> -n astronomy-shop

# Check PV usage (approximate)
kubectl exec -it <pod-using-pvc> -n astronomy-shop -- df -h /path/to/mount
```

## Ingress Operations

```bash
# List ingresses
kubectl get ingress -n astronomy-shop

# Describe ingress
kubectl describe ingress <ingress-name> -n astronomy-shop

# Get ingress IP/hostname
kubectl get ingress <ingress-name> -n astronomy-shop -o jsonpath='{.status.loadBalancer.ingress[0]}'

# Edit ingress
kubectl edit ingress <ingress-name> -n astronomy-shop

# Delete ingress
kubectl delete ingress <ingress-name> -n astronomy-shop
```

## HPA Operations

```bash
# List HPAs
kubectl get hpa -n astronomy-shop

# Describe HPA
kubectl describe hpa <hpa-name> -n astronomy-shop

# Watch HPA scaling
kubectl get hpa <hpa-name> -n astronomy-shop -w

# Edit HPA
kubectl edit hpa <hpa-name> -n astronomy-shop

# Check current metrics
kubectl get hpa <hpa-name> -n astronomy-shop -o jsonpath='{.status}'
```

## Manifest Operations

```bash
# Apply manifest
kubectl apply -f manifest.yaml

# Apply all manifests in directory
kubectl apply -f ./kubernetes/

# Apply with specific namespace
kubectl apply -f manifest.yaml -n astronomy-shop

# Dry run (preview changes)
kubectl apply -f manifest.yaml --dry-run=client

# Dry run on server
kubectl apply -f manifest.yaml --dry-run=server

# Get applied manifest
kubectl get <resource-type> <resource-name> -o yaml -n astronomy-shop

# Delete manifest
kubectl delete -f manifest.yaml

# Compare current vs applied
kubectl diff -f manifest.yaml -n astronomy-shop
```

## Debugging

```bash
# Check pod events
kubectl describe pod <pod-name> -n astronomy-shop

# Check node status
kubectl get nodes

# Describe node
kubectl describe node <node-name>

# Check node logs
kubectl logs /var/log/kubelet.log

# Test DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup service-name

# Network debugging pod
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash

# Check resource usage
kubectl top nodes
kubectl top pods -n astronomy-shop

# Check available resources
kubectl describe nodes | grep -A 5 "Allocated resources"
```

## Cleanup

```bash
# Delete pod
kubectl delete pod <pod-name> -n astronomy-shop

# Delete deployment (cascades to pods)
kubectl delete deployment <deployment-name> -n astronomy-shop

# Delete service
kubectl delete service <service-name> -n astronomy-shop

# Delete entire namespace
kubectl delete namespace astronomy-shop

# Delete all resources of a type
kubectl delete <resource-type> --all -n astronomy-shop

# Force delete stuck pod
kubectl delete pod <pod-name> -n astronomy-shop --grace-period=0 --force
```

## Useful Flags

```bash
# Get resources from all namespaces
kubectl get pods --all-namespaces
kubectl get pods -A

# Label selector
kubectl get pods -l app=frontend -n astronomy-shop

# Output formats
-o yaml      # YAML output
-o json      # JSON output
-o wide      # Extended output
-o name      # Just resource names

# Watch resources
kubectl get pods -n astronomy-shop -w

# Sort by field
kubectl get pods --sort-by=.metadata.creationTimestamp -n astronomy-shop

# Limit results
kubectl get pods -n astronomy-shop --limit=10

# Show field names
kubectl get pods -n astronomy-shop --show-kind
```

## Quick Deploy Steps

```bash
# 1. Build and push image
docker build -t <registry>/astronomy-shop-lite-app:latest .
docker push <registry>/astronomy-shop-lite-app:latest

# 2. Create namespace
kubectl apply -f kubernetes/00-namespace/

# 3. Create configs
kubectl apply -f kubernetes/01-configmaps/

# 4. Deploy observability
kubectl apply -f kubernetes/02-observability/

# 5. Deploy applications
kubectl apply -f kubernetes/03-applications/

# 6. Deploy networking
kubectl apply -f kubernetes/04-networking/

# 7. Access frontend
kubectl port-forward svc/frontend 8080:8080 -n astronomy-shop
# Open: http://localhost:8080

# 8. Access Grafana
kubectl port-forward svc/grafana 3000:3000 -n astronomy-shop
# Open: http://localhost:3000
```

## Troubleshooting Cheatsheet

```bash
# Pod stuck in Pending
kubectl describe pod <pod-name> -n astronomy-shop
kubectl describe nodes  # Check node capacity

# Pod CrashLoopBackOff
kubectl logs -f <pod-name> -n astronomy-shop
kubectl logs <pod-name> --previous -n astronomy-shop  # Previous crash

# ImagePullBackOff
kubectl describe pod <pod-name> -n astronomy-shop  # Check image name/tag

# Services can't communicate
kubectl exec -it <pod-name> -n astronomy-shop -- nslookup other-service
kubectl exec -it <pod-name> -n astronomy-shop -- curl http://other-service:port

# Ingress not working
kubectl get ingress -n astronomy-shop
kubectl describe ingress <ingress-name> -n astronomy-shop
# Check: /etc/hosts for DNS entry

# High CPU/Memory
kubectl top nodes
kubectl top pods -n astronomy-shop
# Increase limits or adjust HPA
```

## Pro Tips

1. **Set default namespace to avoid -n flag**
   ```bash
   kubectl config set-context --current --namespace=astronomy-shop
   ```

2. **Use aliases for faster typing**
   ```bash
   alias k=kubectl
   alias kgp='kubectl get pods'
   alias kl='kubectl logs -f'
   ```

3. **Get resource YAML and modify**
   ```bash
   kubectl get deployment frontend -n astronomy-shop -o yaml > frontend.yaml
   # Edit frontend.yaml
   kubectl apply -f frontend.yaml
   ```

4. **Watch real-time updates**
   ```bash
   kubectl get pods -n astronomy-shop -w
   ```

5. **Get all resources in namespace**
   ```bash
   kubectl get all -n astronomy-shop
   ```
