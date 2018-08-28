#!/usr/bin/env bash
set -eE -o pipefail

OC_ARGS=""
if [[ -n "$KUBERNETES_MASTER" ]];
then
  OC_ARGS="--token=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token) --namespace=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace) --certificate-authority=/run/secrets/kubernetes.io/serviceaccount/ca.crt"
fi

function oc() {
  command oc $OC_ARGS "$@"
  return $?
}

dir=$(dirname "$(readlink -f "$0")")

if [[ -n "$OCP_ENV" && -f $dir/../env/${OCP_ENV}.env ]];
then
  set -a
  . $dir/../env/${OCP_ENV}.env
  set +a
fi

oc apply -f $dir/build.yml
oc start-build mule-ee --from-dir=. --wait --follow
