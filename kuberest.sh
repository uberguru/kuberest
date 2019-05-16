#!/bin/bash

#install some tools
#sudo apt-get install curl jq

#create a service account to access the api 
kubectl create serviceaccount kubehack
kubectl create clusterrolebinding kubehack-binding --clusterrole=cluster-admin --serviceaccount=default:kubehack

# Get the ServiceAccount's token Secret's name
SERVICEACCOUNT=kubehack
SECRET=$(kubectl get serviceaccount $SERVICEACCOUNT -o json | jq -Mr '.secrets[].name | select(contains("token"))')
echo $SECRET

# Extract the Bearer token from the Secret and decode
TOKEN=$(kubectl get secret $SECRET -o json | jq -Mr '.data.token' | base64 -d)
echo $TOKEN

#Extract, decode and write the ca.crt to a temporary location
kubectl get secret $SECRET -o json | jq -Mr '.data["ca.crt"]' | base64 -d > /tmp/ca.crt

# Get the API Server location
APISERVER=https://$(kubectl -n default get endpoints kubernetes --no-headers | awk '{ print $2 }')
echo $APISERVER


#Examples with certificate

curl -s $APISERVER/api/v1/namespaces/default/pods/ --header "Authorization: Bearer $TOKEN" --cacert /tmp/ca.crt | jq -rM '.items[].metadata.name'

curl -s $APISERVER/api/v1/nodes --header "Authorization: Bearer $TOKEN" --cacert /tmp/ca.crt | jq -rM '.items[].metadata.name'


# example without certificate (because its a self signed)

# list the nodes in my cluster just to test access
#curl --insecure --request GET \
#  --url "$APISERVER/api/v1/nodes" \
#  --header "Authorization: Bearer $TOKEN" \
#  --header "Content-Type: application/json" \
#  | jq '.items[] .metadata.labels'

#deploy a pod via rest
curl -s $APISERVER/api/v1/namespaces/default/pods \
-XPOST -H 'Content-Type: application/json' \
-d@nginx-pod.json --header "Authorization: Bearer $TOKEN" --cacert /tmp/ca.crt \
| jq '.status'

sleep 5

#creat service endpoint
curl -s $APISERVER/api/v1/namespaces/default/services \
-XPOST -H 'Content-Type: application/json' \
-d@nginx-service.json --header "Authorization: Bearer $TOKEN" --cacert /tmp/ca.crt \
| jq '.spec.clusterIP'

#Delete Cleanup Example cleaning up the pods. 

#curl $APISERVER/api/v1/namespaces/default/services/nginx-service -XDELETE \
#--header "Authorization: Bearer $TOKEN" --cacert /tmp/ca.crt

#curl $APISERVER/api/v1/namespaces/default/pods/nginx -XDELETE \
#--header "Authorization: Bearer $TOKEN" --cacert /tmp/ca.crt

