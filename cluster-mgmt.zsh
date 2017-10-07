# cluster mgmt functions

alias cssh-k8s-nodes='cssh $(kubectl get nodes -o jsonpath="{.items[*].metadata.name}")'

alias ktopmem="watch -t 'kubectl top pods --all-namespaces | sort -rnk4'"
alias ktopcpu="watch -t 'kubectl top pods --all-namespaces | sort -rnk3'"
alias ktpmem="watch -t 'kubectl top pods --all-namespaces | sort -rnk4'"
alias ktpcpu="watch -t 'kubectl top pods --all-namespaces | sort -rnk3'"

alias ktnmem="watch -t 'kubectl top nodes | sort -rnk4'"
alias ktncpu="watch -t 'kubectl top nodes | sort -rnk3'"

alias kpls="kubectl get pods --all-namespaces --show-all -o wide"
alias kpall="watch -t 'kubectl get pods --all-namespaces -o wide'"
alias kpnr="watch -t \"kubectl get pods --all-namespaces -o wide | grep -v ' Running '\""
alias kpo="kubectl get pods --all-namespaces --show-all | sed 1d | awk '{print \$4}' | perl -ne 'chomp;\$data{\$_}++;END{printf \"%-20s \$data{\$_}\n\", \"\$_\" for sort keys %data};'"

alias applogs='stern --namespace=`basename $PWD` -s 1s'
alias appmon='watch -t knsmon `basename $PWD`'
alias apptopmem='watch -t "kubectl top pods --namespace=`basename $PWD` | sort -rnk3"'
alias apptopcpu='watch -t "kubectl top pods --namespace=`basename $PWD` | sort -rnk2"'
alias apps-from-deis="deis apps | grep -v '=== Apps' | xargs mkdir -v 2>/dev/null"
alias apps-from-namespaces="kubectl get namespaces -ojsonpath='{.items[*].metadata.name}' | xargs -n1 mkdir -pv"

function use-context {
  [ -z ${1+x} ] && return 1
  local q=${1}
  local ctxt=$(kubectl config get-contexts | sed -e 1d | sed 's,\*,,' | awk '{print $1}' | grep ${q} | head -n1)

  if [ "${ctxt}x" = "x" ]; then
    echo >&2 "context not found"
    return 1
  fi

  # echo "Switching cluster-context to '${ctxt}'"
  # alias kubectl="kubectl --context=${ctxt}"
  kubectl config use-context ${ctxt}
  export DEIS_PROFILE=${ctxt}

  mkdir -pv ~/clusters/${ctxt}
  cd ~/clusters/${ctxt}
}

function use-cluster {
  if [[ ${#@} -eq 0 ]]; then
    echo "Cluster exports cleared"
    unset KUBECONFIG
    unset DEIS_PROFILE
  else
    echo "Using cluster '${1}'"
    cd ~/clusters/${1}
    export KUBECONFIG="${HOME}/.kube/${1}"
    export DEIS_PROFILE=${1}
  fi
}

function kgetc { kubectl -n ${1} get po/${2} -o json | jq -Mr ".spec.containers[].name" }
