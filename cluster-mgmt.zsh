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
