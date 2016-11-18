# cluster mgmt functions

alias applogs='stern --namespace=`basename $PWD`'

function use-cluster {
  if [[ ${#@} -eq 0 ]]; then
    echo "Cluster exports cleared"
    unset KUBECONFIG
    unset DEIS_PROFILE
    unalias stern
  else
    echo "Using cluster '${1}'"
    cd ~/clusters/${1}
    export KUBECONFIG="${HOME}/.kube/${1}"
    export DEIS_PROFILE=${1}
    alias stern="stern --kube-config=${KUBECONFIG} -s 1s"
  fi
}

function knsmon {
  emulate bash

  COLS=$(($(tput cols)-6))

  NAMESPACE=${1:-kube-system}
  DEFAULT_OBJECTS="services daemonsets deployments pods replicasets replicationcontrollers"
  OPTS="${@:2}"

  if [[ $OPTS =~ ^\+ ]]; then
    OPTS=$(echo ${OPTS} | sed 's/^\+//')
    OBJECTS="$OPTS $DEFAULT_OBJECTS"
  else
    OBJECTS=${OPTS:-'services daemonsets deployments pods replicasets replicationcontrollers'}
  fi

  printf "=%.0s" $(seq 1 $(($COLS-${#NAMESPACE})))
  printf " ${NAMESPACE} ===\n"

  for OBJECT in ${OBJECTS}; do
    printf "=== $OBJECT "
    printf "=%.0s" $(seq 1 $(($COLS-${#OBJECT})))
    printf "\n"
    kubectl "--namespace=${NAMESPACE}" get ${OBJECT} --show-all
    printf "\n"
  done
}
