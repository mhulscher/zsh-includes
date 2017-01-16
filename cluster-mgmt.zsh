# cluster mgmt functions

alias ktopmem="watch -t 'kubectl top pods --all-namespaces | sort -rnk4'"
alias ktopcpu="watch -t 'kubectl top pods --all-namespaces | sort -rnk3'"

alias applogs='stern --namespace=`basename $PWD` -s 1s'
alias appmon='watch -t knsmon `basename $PWD`'
alias apps-from-deis="deis apps | grep -v '=== Apps' | xargs mkdir -v 2>/dev/null"

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
    alias stern="stern --kube-config=${KUBECONFIG}"
  fi
}
