# Set up Demo Environment for Multicluster Mesh Addon with KinD Clusters

## Set up KinD Clusters and Install OCM

1. To create three local running KinD clusters(one for hub cluster, another for managed clusters) locally, run:

```bash
kind create cluster --name hub
kind create cluster --name cluster1
kind create cluster --name cluster2
```

2. Export the environment variables and command alias that will be used through the guide:

```bash
export CTX_HUB_CLUSTER=kind-hub
export CTX_MANAGED_CLUSTER1=kind-cluster1
export CTX_MANAGED_CLUSTER2=kind-cluster2
```

3. Deploy a cluster manager on the hub cluster and import the other two KinD clusters as managed clusters:

```bash
clusteradm init --wait --context ${CTX_HUB_CLUSTER}

clusteradm join \
     --context ${CTX_MANAGED_CLUSTER1} \
     --hub-token <token_from_last_step> \
     --hub-apiserver <hubcluster_endpoint_from_last_step> \
     --wait \
     --cluster-name "cluster1" \
     --force-internal-endpoint-lookup

clusteradm join \
     --context ${CTX_MANAGED_CLUSTER2} \
     --hub-token <token_from_last_step> \
     --hub-apiserver <hubcluster_endpoint_from_last_step> \
     --wait \
     --cluster-name "cluster2" \
     --force-internal-endpoint-lookup

clusteradm accept --clusters cluster1 --context ${CTX_HUB_CLUSTER}
clusteradm accept --clusters cluster2 --context ${CTX_HUB_CLUSTER}

# verify the managedclusters
kubectl get managedcluster --context ${CTX_HUB_CLUSTER}
```

## Deploy the Multicluster Mesh Addon

1. Deploy multicluster-mesh-addon in hub cluster:

```bash
git clone git@github.com:morvencao/multicluster-mesh-addon.git -b ocm_version
cd multicluster-mesh-addon
kubectl config use-context kind-hub
make deploy
```

2. Make sure the multicluster-mesh-addon is up and running in hub cluster and multicluster-mesh-agents are up and running in managed cluster:

```bash
kubectl -n open-cluster-management get pod -l app=multicluster-mesh-addon --context ${CTX_HUB_CLUSTER}
kubectl get managedclusteraddon multicluster-mesh -n cluster1 --context ${CTX_HUB_CLUSTER}
kubectl get managedclusteraddon multicluster-mesh -n cluster2 --context ${CTX_HUB_CLUSTER}
kubectl -n open-cluster-management-agent-addon get pod -l app=multicluster-mesh-agent --context ${CTX_MANAGED_CLUSTER1}
kubectl -n open-cluster-management-agent-addon get pod -l app=multicluster-mesh-agent --context ${CTX_MANAGED_CLUSTER2}
```

## Load Istio Images to Managed Clusters

Pull the istio related images from docker hub and load into the KinD clusters to workaround the docker.io pull limite issue:

```bash
docker pull docker.io/istio/operator:1.13.2
docker pull docker.io/istio/pilot:1.13.2
docker pull docker.io/istio/proxyv2:1.13.2
docker pull docker.io/istio/examples-bookinfo-productpage-v1:1.16.2
docker pull docker.io/istio/examples-bookinfo-details-v1:1.16.2
docker pull docker.io/istio/examples-bookinfo-ratings-v1:1.16.2
docker pull docker.io/istio/examples-bookinfo-reviews-v1:1.16.2
docker pull docker.io/istio/examples-bookinfo-reviews-v2:1.16.2
docker pull docker.io/istio/examples-bookinfo-reviews-v3:1.16.2
kind load docker-image docker.io/istio/operator:1.13.2 --name cluster1
kind load docker-image docker.io/istio/pilot:1.13.2 --name cluster1
kind load docker-image docker.io/istio/proxyv2:1.13.2 --name cluster1
kind load docker-image docker.io/istio/examples-bookinfo-productpage-v1:1.16.2 --name cluster1
kind load docker-image docker.io/istio/examples-bookinfo-details-v1:1.16.2 --name cluster1
kind load docker-image docker.io/istio/examples-bookinfo-ratings-v1:1.16.2 --name cluster1
kind load docker-image docker.io/istio/examples-bookinfo-reviews-v1:1.16.2 --name cluster1
kind load docker-image docker.io/istio/examples-bookinfo-reviews-v2:1.16.2 --name cluster1
kind load docker-image docker.io/istio/examples-bookinfo-reviews-v3:1.16.2 --name cluster1
kind load docker-image docker.io/istio/operator:1.13.2 --name cluster2
kind load docker-image docker.io/istio/pilot:1.13.2 --name cluster2
kind load docker-image docker.io/istio/proxyv2:1.13.2 --name cluster2
kind load docker-image docker.io/istio/examples-bookinfo-productpage-v1:1.16.2 --name cluster2
kind load docker-image docker.io/istio/examples-bookinfo-details-v1:1.16.2 --name cluster2
kind load docker-image docker.io/istio/examples-bookinfo-ratings-v1:1.16.2 --name cluster2
kind load docker-image docker.io/istio/examples-bookinfo-reviews-v1:1.16.2 --name cluster2
kind load docker-image docker.io/istio/examples-bookinfo-reviews-v2:1.16.2 --name cluster2
kind load docker-image docker.io/istio/examples-bookinfo-reviews-v3:1.16.2 --name cluster2
```

## Mesh Discovery

1. Deploy an istio service mesh in managed cluster with `istioctl`:

```bash
istioctl install --revision canary --set profile=minimal -y --context ${CTX_MANAGED_CLUSTER1}
```

2. From hub cluster check that the istio service mesh created in last step is discoveried:

```bash
kubectl get mesh -n cluster1 --context ${CTX_HUB_CLUSTER}
```

## Mesh Deploy

1. From hub cluster deploy new istio service mesh(es) by creating `meshdeployment` resource:

```bash
cat << EOF | kubectl --context ${CTX_HUB_CLUSTER} apply -f -
apiVersion: mesh.open-cluster-management.io/v1alpha1
kind: MeshDeployment
metadata:
  name: istio
  namespace: open-cluster-management
spec:
  clusters: ["cluster1", "cluster2"]
  controlPlane:
    components: ["base", "istiod", "istio-ingress"]
    namespace: istio-system
    profiles: ["default"]
    version: 1.13.2
    revision: 1-13-2
  meshMemberRoll: ["bookinfo"]
  meshProvider: Upstream Istio
EOF
```

2. Verify the istio serivce meshes are created in the corresponding managed clusters:

```bash
kubectl -n istio-system get pod --context ${CTX_MANAGED_CLUSTER1}
kubectl -n istio-system get pod --context ${CTX_MANAGED_CLUSTER2}
```

## Mesh Federation

1. From hub cluster federate the istio serivce meshes created in last step by creating `meshfederation` resource:

```bash
cat << EOF | kubectl --context ${CTX_HUB_CLUSTER} apply -f -
apiVersion: mesh.open-cluster-management.io/v1alpha1
kind: MeshFederation
metadata:
  name: istio-federation
  namespace: open-cluster-management
spec:
  meshPeers:
  - peers:
    - name: cluster1-istio
      cluster: cluster1
    - name: cluster2-istio
      cluster: cluster2
  trustConfig:
    trustType: Complete
EOF
```

2. Verify the istio service meshes are federated successfull by [deploying bookinfo application](mesh-federation-verify-istio.md):

- Deploy part(productpage,details,reviews-v1,reviews-v2,ratings) of the bookinfo application in `cluster1`:

```bash
kubectl config use-context ${CTX_MANAGED_CLUSTER1}
kubectl create ns bookinfo
kubectl label namespace bookinfo istio.io/rev=1-13-2
kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/release-1.13/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app,version notin (v3)'
kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/release-1.13/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account'
```

- Then deploy another part(reviews-v3, ratings) of bookinfo application in `cluster2`:

```bash
kubectl config use-context ${CTX_MANAGED_CLUSTER2}
kubectl create ns bookinfo
kubectl label namespace bookinfo istio.io/rev=1-13-2
kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/release-1.8/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app,version in (v3)' 
kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/release-1.8/samples/bookinfo/platform/kube/bookinfo.yaml -l 'service=reviews' 
kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/release-1.8/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account=reviews' 
kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/release-1.8/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app=ratings' 
kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/release-1.8/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account=ratings'
```

- Create the following `serviceentry` and `destinationrule` resources in `cluster2` to expose service(reviews-v3) from mesh `cluster2-istio`:

```bash
REVIEW_V3_IP=$(kubectl --context=${CTX_MANAGED_CLUSTER2} -n bookinfo get pod -l app=reviews -o jsonpath="{.items[0].status.podIP}")
cat << EOF | kubectl --context=${CTX_MANAGED_CLUSTER2} apply -f -
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: reviews.bookinfo.svc.cluster2.global
  namespace: istio-system
spec:
  endpoints:
  - address: ${REVIEW_V3_IP}
    labels:
      app: reviews
      version: v3
    ports:
      http: 9080
  exportTo:
  - .
  hosts:
  - reviews.bookinfo.svc.cluster2.global
  location: MESH_INTERNAL
  ports:
  - name: http
    number: 9080
    protocol: HTTP
  resolution: STATIC
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews-bookinfo-cluster2
  namespace: istio-system
spec:
  host: reviews.bookinfo.svc.cluster2.global
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF
```

- Get the accessiable address of eastwest gateway for mesh `cluster2-istio`, for KinD cluster, the address can be the combination of the host docker container IP and Kubernetes Service NodePort:

```bash
CLUSTER2_HOST_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' cluster2-control-plane)
EASTWESTGW_NODEPORT=$(kubectl --context=${CTX_MANAGED_CLUSTER2} -n istio-system get svc istio-eastwestgateway -o jsonpath='{.spec.ports[?(@.name=="tls")].nodePort}')
```

- Create the serviceentry in `cluster1` to discovery the remote service(reviews-v3) from source mesh `cluster1-istio` with the IP and port retrieved from the last step:

```bash
cat << EOF | kubectl --context=${CTX_MANAGED_CLUSTER1} apply -f -
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: reviews.bookinfo.svc.cluster2.global
  namespace: istio-system
spec:
  addresses:
  - 255.51.210.11
  endpoints:
  - address: ${CLUSTER2_HOST_IP}
    labels:
      app: reviews
      version: v3
    ports:
      http: ${EASTWESTGW_NODEPORT}
  hosts:
  - reviews.bookinfo.svc.cluster2.global
  location: MESH_INTERNAL
  ports:
  - name: http
    number: 9080
    protocol: HTTP
  resolution: STATIC
EOF
```

- Create the following `virtualservice` and `destinationrule` resources in `cluster1` to route traffic from mesh `cluster1-istio` to mesh `cluster1-istio`:

```bash
cat << EOF | kubectl --context=${CTX_MANAGED_CLUSTER1} apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: bookinfo
spec:
  hosts:
  - reviews.bookinfo.svc.cluster.local
  http:
  - match:
    - port: 9080
    route:
    - destination:
        host: reviews.bookinfo.svc.cluster2.global
        port:
          number: 9080
      weight: 75
    - destination:
        host: reviews.bookinfo.svc.cluster.local
        port:
          number: 9080
        subset: version-v1
      weight: 15
    - destination:
        host: reviews.bookinfo.svc.cluster.local
        port:
          number: 9080
        subset: version-v2
      weight: 10
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews
  namespace: bookinfo
spec:
  host: reviews.bookinfo.svc.cluster.local
  subsets:
  - labels:
      version: v1
    name: version-v1
  - labels:
      version: v2
    name: version-v2
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews-bookinfo-cluster2
  namespace: istio-system
spec:
  host: reviews.bookinfo.svc.cluster2.global
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF
```

- Port forward the producppage service in `cluster1` so that we can access it from browser:

```bash
kubectl --context=${CTX_MANAGED_CLUSTER1} -n bookinfo port-forward svc/productpage --address 0.0.0.0 9080:9080
```

_Note_: The expected result is that by refreshing the page several times, you should occasionally see traffic being routed to the `reviews-v3` service, which will produce red-colored stars on the product page.
