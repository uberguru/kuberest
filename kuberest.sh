#!/bin/bash

#install some tools
sudo apt-get install curl jq

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

# example without certificate




# list the nodes in my cluster just to test access
curl --insecure --request GET \
  --url "$APISERVER/api/v1/nodes" \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/json" \
  | jq '.items[] .metadata.labels'


curl -s http://$APISERVER/api/v1/namespaces/default/pods \
--header "Authorization: Bearer $TOKEN" \
-XPOST -H 'Content-Type: application/json' \
-d@nginx-pod.json \
| jq '.status'

#-d@nginx-pod.json \


