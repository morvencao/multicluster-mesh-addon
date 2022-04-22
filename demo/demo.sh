#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

# Put your stuff here

printf "Create three KinD clusters, one will be the OCM hub cluster, the other two clusters will join the OCM hub as managed clusters.\n"
pei "kind create cluster --name hub"
pei "kind create cluster --name cluster1"
pei "kind create cluster --name cluster2"

printf "\nExport environment variables that will used through the demo.\n"
pei "export CTX_HUB_CLUSTER=kind-hub"
pei "export CTX_MANAGED_CLUSTER1=kind-cluster1"
pei "export CTX_MANAGED_CLUSTER2=kind-cluster2"

printf "\nDeploy cluster manager on the hub cluster.\n"
pei "clusteradm init --wait --context ${CTX_HUB_CLUSTER}"

# retrieve the hub bootstrap token and apiserver address in the background 
token_secret_name=$(kubectl --context $CTX_HUB_CLUSTER -n open-cluster-management get sa cluster-bootstrap -o json | jq -r .secrets[].name)
token=$(kubectl --context $CTX_HUB_CLUSTER -n open-cluster-management get secret $token_secret_name -o json | jq -r '.data["token"]' | base64 -d)
apiserver_port=$(docker inspect hub-control-plane --format '{{ (index (index .NetworkSettings.Ports "6443/tcp") 0).HostPort }}')

printf "\nJoin the kind-cluster1 to the Hub.\n"
pei "clusteradm join --context ${CTX_MANAGED_CLUSTER1} --hub-token $token --hub-apiserver https://127.0.0.1:${apiserver_port} --wait --cluster-name cluster1 --force-internal-endpoint-lookup"

printf "\nJoin the kind-cluster2 to the Hub.\n"
pei "clusteradm join --context ${CTX_MANAGED_CLUSTER2} --hub-token $token --hub-apiserver https://127.0.0.1:${apiserver_port} --wait --cluster-name cluster2 --force-internal-endpoint-lookup"

printf "\nAccept the two cluster join requests in Hub.\n"
pei "clusteradm accept --clusters cluster1 --context ${CTX_HUB_CLUSTER}"
pei "clusteradm accept --clusters cluster2 --context ${CTX_HUB_CLUSTER}"

printf "\nVerify two managed clusters are joined to the Hub.\n"
pei "kubectl get managedcluster --context ${CTX_HUB_CLUSTER}"

# pull istio and bookinfo images and load them into KinD clusters in the background
docker pull docker.io/istio/operator:1.13.2 > /dev/null 2>&1 &
docker pull docker.io/istio/pilot:1.13.2 > /dev/null 2>&1 &
docker pull docker.io/istio/proxyv2:1.13.2 > /dev/null 2>&1 &
docker pull docker.io/istio/examples-bookinfo-productpage-v1:1.16.2 > /dev/null 2>&1 &
docker pull docker.io/istio/examples-bookinfo-details-v1:1.16.2 > /dev/null 2>&1 &
docker pull docker.io/istio/examples-bookinfo-ratings-v1:1.16.2 > /dev/null 2>&1 &
docker pull docker.io/istio/examples-bookinfo-reviews-v1:1.16.2 > /dev/null 2>&1 &
docker pull docker.io/istio/examples-bookinfo-reviews-v2:1.16.2 > /dev/null 2>&1 &
docker pull docker.io/istio/examples-bookinfo-reviews-v3:1.16.2 > /dev/null 2>&1 &
kind load docker-image docker.io/istio/operator:1.13.2 --name cluster1 > /dev/null 2>&1 &
kind load docker-image docker.io/istio/pilot:1.13.2 --name cluster1 > /dev/null 2>&1 &
kind load docker-image docker.io/istio/proxyv2:1.13.2 --name cluster1 > /dev/null 2>&1 &
kind load docker-image docker.io/istio/examples-bookinfo-productpage-v1:1.16.2 --name cluster1 > /dev/null 2>&1 &
kind load docker-image docker.io/istio/examples-bookinfo-details-v1:1.16.2 --name cluster1 > /dev/null 2>&1 &
kind load docker-image docker.io/istio/examples-bookinfo-ratings-v1:1.16.2 --name cluster1 > /dev/null 2>&1 &
kind load docker-image docker.io/istio/examples-bookinfo-reviews-v1:1.16.2 --name cluster1 > /dev/null 2>&1 &
kind load docker-image docker.io/istio/examples-bookinfo-reviews-v2:1.16.2 --name cluster1 > /dev/null 2>&1 &
kind load docker-image docker.io/istio/examples-bookinfo-reviews-v3:1.16.2 --name cluster1 > /dev/null 2>&1 &
kind load docker-image docker.io/istio/operator:1.13.2 --name cluster2 > /dev/null 2>&1 &
kind load docker-image docker.io/istio/pilot:1.13.2 --name cluster2 > /dev/null 2>&1 &
kind load docker-image docker.io/istio/proxyv2:1.13.2 --name cluster2 > /dev/null 2>&1 &
kind load docker-image docker.io/istio/examples-bookinfo-productpage-v1:1.16.2 --name cluster2 > /dev/null 2>&1 &
kind load docker-image docker.io/istio/examples-bookinfo-details-v1:1.16.2 --name cluster2 > /dev/null 2>&1 &
kind load docker-image docker.io/istio/examples-bookinfo-ratings-v1:1.16.2 --name cluster2 > /dev/null 2>&1 &
kind load docker-image docker.io/istio/examples-bookinfo-reviews-v1:1.16.2 --name cluster2 > /dev/null 2>&1 &
kind load docker-image docker.io/istio/examples-bookinfo-reviews-v2:1.16.2 --name cluster2 > /dev/null 2>&1 &
kind load docker-image docker.io/istio/examples-bookinfo-reviews-v3:1.16.2 --name cluster2 > /dev/null 2>&1 &

printf "\n\nDeploy multicluster-mesh-addon in hub cluster.\n"
pe "git clone git@github.com:morvencao/multicluster-mesh-addon.git -b ocm_version && cd multicluster-mesh-addon"
pe "kubectl config use-context kind-hub && make deploy"
pei  "cd .. && rm -rf multicluster-mesh-addon"

printf "\nMake sure the multicluster-mesh-addon is up and running in hub cluster.\n"
pe "kubectl -n open-cluster-management get pod -l app=multicluster-mesh-addon --context ${CTX_HUB_CLUSTER}"
pei "kubectl get managedclusteraddon multicluster-mesh -n cluster1 --context ${CTX_HUB_CLUSTER}"
pei "kubectl get managedclusteraddon multicluster-mesh -n cluster2 --context ${CTX_HUB_CLUSTER}"

printf "\nMake sure the multicluster-mesh-agents are up and running in managed clusters.\n"
pei "kubectl -n open-cluster-management-agent-addon get pod -l app=multicluster-mesh-agent --context ${CTX_MANAGED_CLUSTER1}"
pei "kubectl -n open-cluster-management-agent-addon get pod -l app=multicluster-mesh-agent --context ${CTX_MANAGED_CLUSTER2}"

printf "\n\nDeploy an istio service mesh in a managed cluster to verify the existing mesh can be discoveried by the multicluster-mesh-addon.\n"
pe "istioctl install --revision test --set profile=minimal -y --context ${CTX_MANAGED_CLUSTER1}"

printf "\nFrom hub cluster check that the istio service mesh created in last step is discoveried.\n"
pe "kubectl get mesh -n cluster1 --context ${CTX_HUB_CLUSTER}"

printf "\n\nFrom hub cluster deploy new istio service mesh(es) by creating meshdeployment resource.\n"
pe "cat meshdeployment.yaml"
pe "kubectl --context ${CTX_HUB_CLUSTER} apply -f meshdeployment.yaml"

printf "\nVerify the istio serivce meshes are created in the corresponding managed clusters.\n"
pe "kubectl -n istio-system get pod --context ${CTX_MANAGED_CLUSTER1}"
pe "kubectl -n istio-system get pod --context ${CTX_MANAGED_CLUSTER2}"

printf "\n\nFrom hub cluster federate the istio serivce meshes created in last step by creating meshfederation resource.\n"
pe "cat meshfederation.yaml"
pe "kubectl --context ${CTX_HUB_CLUSTER} apply -f meshfederation.yaml"

printf "\n\nVerify the istio service meshes are federated successfull by deploying bookinfo application.\n"
printf "    Deploy part(productpage,details,reviews-v1,reviews-v2,ratings) of the bookinfo application in cluster1.\n"
pe "kubectl create ns bookinfo --context ${CTX_MANAGED_CLUSTER1}"
pe "kubectl label namespace bookinfo istio.io/rev=1-13-2 --context ${CTX_MANAGED_CLUSTER1}"
pe "kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/release-1.13/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app,version notin (v3)' --context ${CTX_MANAGED_CLUSTER1}"
pe "kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/release-1.13/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account' --context ${CTX_MANAGED_CLUSTER1}"

printf "\n    Deploy another part(reviews-v3, ratings) of bookinfo application in cluster2.\n"
pe "kubectl create ns bookinfo --context ${CTX_MANAGED_CLUSTER2}"
pe "kubectl label namespace bookinfo istio.io/rev=1-13-2 --context ${CTX_MANAGED_CLUSTER2}"
pe "kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/release-1.8/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app,version in (v3)' --context ${CTX_MANAGED_CLUSTER2}"
pe "kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/release-1.8/samples/bookinfo/platform/kube/bookinfo.yaml -l 'service=reviews' --context ${CTX_MANAGED_CLUSTER2}"
pe "kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/release-1.8/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account=reviews' --context ${CTX_MANAGED_CLUSTER2}"
pe "kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/release-1.8/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app=ratings' --context ${CTX_MANAGED_CLUSTER2}"
pe "kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/release-1.8/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account=ratings' --context ${CTX_MANAGED_CLUSTER2}"

printf "\nVerify productpage,details,reviews-v1,reviews-v2,ratings are up and running in cluster1.\n"
pe "kubectl -n bookinfo get pod --context ${CTX_MANAGED_CLUSTER1}"

printf "\nVerify ratings and reviews-v3, ratings are up and running in cluster2.\n"
pe "kubectl -n bookinfo get pod --context ${CTX_MANAGED_CLUSTER2}"

printf "\nCreate the serviceentry in cluster2 to to 'export' the remote service(reviews-v3).\n"
pe "cat serviceentry-export-cluster2.yaml"
export REVIEW_V3_IP=$(kubectl --context=${CTX_MANAGED_CLUSTER2} -n bookinfo get pod -l app=reviews -o jsonpath='{.items[0].status.podIP}')
pe "cat serviceentry-export-cluster2.yaml | REVIEW_V3_IP=${REVIEW_V3_IP} envsubst | kubectl --context=${CTX_MANAGED_CLUSTER2} apply -f -"

printf "\nCreate the serviceentry in cluster1 to to 'import' the remote service(reviews-v3).\n"
pe "cat serviceentry-import-cluster1.yaml"
export CLUSTER2_HOST_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' cluster2-control-plane)
export EASTWESTGW_NODEPORT=$(kubectl --context=${CTX_MANAGED_CLUSTER2} -n istio-system get svc istio-eastwestgateway -o jsonpath='{.spec.ports[?(@.name=="tls")].nodePort}')
pe "cat serviceentry-import-cluster1.yaml | CLUSTER2_HOST_IP=${CLUSTER2_HOST_IP} EASTWESTGW_NODEPORT=${EASTWESTGW_NODEPORT} envsubst | kubectl --context=${CTX_MANAGED_CLUSTER1} apply -f -"

# apply the destinationrule and virtualservice in the background
kubectl --context=${CTX_MANAGED_CLUSTER2} apply -f destinationrule-cluster2.yaml > /dev/null 2>&1 &
kubectl --context=${CTX_MANAGED_CLUSTER1} apply -f virtualservice-cluster1.yaml > /dev/null 2>&1 &

printf "\nPort forward the producppage service in cluster1 so that we can access it from browser.\n"
printf "kubectl --context=${CTX_MANAGED_CLUSTER1} -n bookinfo port-forward svc/productpage --address 0.0.0.0 9080:9080 &\n"

pe "exit 0"
