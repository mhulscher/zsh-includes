alias k=kubecolor
alias m=minikube

function k.lc() {
  kubectl config get-contexts
}

function k.uc() {
  [ -z ${1+x} ] && return 1
  local q=${1}
  local ctxt_all=$(kubectl config get-contexts | sed -e 1d | sed 's,\*,,' | awk '{print $1}')

  # Specific search first (starts with)
  local ctxt=$(echo ${ctxt_all} | grep "^${q}" | head -n1)

  # Generic search (contains)
  [ "${ctxt}x" = "x" ] && ctxt=$(echo ${ctxt_all} | grep "${q}" | head -n1)

  if [ "${ctxt}x" = "x" ]; then
    echo >&2 "context not found"
    return 1
  fi

  kubectl config use-context ${ctxt}
}

function k.ns() {
  [ -z ${1+x} ] && return 1
  local q=${1}

  local ns_all=$(kubectl get ns -ocustom-columns=NAME:.metadata.name --no-headers)

  local ns=$(echo ${ns_all} | grep "^${q}" | head -n1)
  [ "${ns}x" = "x" ] && ns=$(echo ${ns_all} | grep "${q}" | head -n1)

  if [ "${ns}x" = "x" ]; then
    echo >&2 "namespace not found"
    return 1
  fi

  kubectl config set-context $(kubectl config current-context) --namespace ${ns}
}

k.is_valid_object() {
  [ -z ${1+x} ] && return 1
  local search=${1}
  local objects=$(kubectl get 2>&1 | grep -oP "(?<=\* )[a-z]+|(?<=aka ')[a-z]+" | tr '\n' ' ')

  for object in $(echo ${objects}); do
    if [ ${object} = ${search} ]; then
      export KUBE_IS_OBJECT=1
      break
    fi
  done
}

function k.ls() {
  if [ $# -eq 0 ]; then
    kubectl get pods
    return 0
  fi

  local param=${1%/*}

  export KUBE_IS_OBJECT=0
  k.is_valid_object ${param}

  if [ ${KUBE_IS_OBJECT} -eq 1 ]; then
    kubectl get "$@"
  else
    kubectl get pods "$@"
  fi
}

function k.ll() {
  k.ls "$@" --output=wide
}

function k.lll() {
  k.ll "$@" --show-labels
}

function k.nr() {
  kubectl get pods --all-namespaces --output=wide | grep -vP "\b(\d+)/\1\b" | grep -ve '\bError\b' -e '\bCompleted\b'
}

function k.wnr() {
  watch -t 'kubectl get pods --all-namespaces --output=wide | grep -vP "\b(\d+)/\1\b" | grep -v -e '\bError\b' -e Completed -e Evicted -e OutOfcpu -e OutOfmemory'
}

function k.wmaintenance() {
  context=""
  test ${1+x} && context="--context=${1}"
  watch -t "kubectl ${context} version --short; echo; kubectl ${context} get nodes -o wide -L node.kubernetes.io/instance-type,kubernetes.io/os,kubernetes.io/arch,topology.kubernetes.io/zone,kpn.org/role,kpn.org/lifecycle,nvidia.com/gpu; echo; kubectl ${context} get po -o wide --all-namespaces | grep -vP '(\d+)/\1' | grep -v -e '\bError\b' -e Completed -e Evicted -e OutOfcpu -e OutOfmemory"
}

function k.del() {
  [ -z ${1+x} ] && return 1

  echo -n "Do you really want to 'kubectl delete $@'? [yn] "
  read reply

  [ ${reply} = "y" ] && kubectl delete "$@"
}

function k.delr() {
  [ -z ${1+x} ] && return 1

  local search=${1}
  local force=${2:-"n"}
  local pods=$(k.ls -o wide | grep "^${search}")
  if [ -z ${pods+x} ]; then
    echo "Found no pods"
    return 0
  fi

  local not_ready="$(echo ${pods} | grep -v Running)"
  if [ "${not_ready}" != "" ]; then
    echo -e "\n${not_ready}\n"
    echo "Not all pods are ready -- not doing anything!"
    return 1
  fi

  local count=$(echo ${pods} | wc -l)

  echo -e "\n${pods}\n"

  if [ ${force} != "y" ]; then
    echo -n "I am about to delete these ${count} pods, one-by-one. Are you sure? [yn] "
    read reply
  fi

  if [ ${force} = "y" ] || [ ${reply} = "y" ]; then
    local index=1
    for pod in $(echo ${pods} | awk '{print $1}'); do
      echo -e "\nDeleting pod (${index}/${count}): ${pod}"
      kubectl delete pods ${pod}
      sleep 1
      while true; do
        local new_pods=$(k.ls | grep "^${search}")
        local new_count_ready=$(echo ${new_pods} | grep Running | grep -cP '\b(\d+)/\1\b')
        [ ${new_count_ready} -eq ${count} ] && break
        sleep 5
      done
      ((index++))
    done
  fi
}

function k.delstatus() {
  [ -z ${1+x} ] && return 1

  local state=${1}
  local pods=$(k.la | awk '$3 == "'${state}'" { print $0 }')

  if [ "${pods}" = "" ]; then
    echo >&2 "No pods have state '${state}'"
    return 1
  fi

  echo -e "\n${pods}\n"
  echo -n "I am about delete these pods, are you sure? [yn] "
  read reply

  [ "${reply}" != "y" ] && return 0

  echo ${pods} | awk '{ print $1 }' | xargs -I%% kubectl delete po %% --grace-period=0
}

function k.nh() {
  kubectl get nodes -o json |
    jq -r '.items[] | .metadata.name,(.status.conditions[] | .type,.status)' |
    awk '$1 ~ /^[a-z]/ { printf "\n%-50s", $1 } $1 ~ /^[A-Z]/ { printf "%-15s", $1 }' |
    sed 1d
  echo
}

function k.ing() {
  [ -z ${1+x} ] && return 1

  local host="$1"
  local namespace="${2:-ingress-nginx}"

  kubectl ingress-nginx \
    -n "$namespace" \
    conf \
    --host "$host" \
    --pod $(
      k -n "$namespace" get po -l app.kubernetes.io/component=controller --no-headers |
        head -1 |
        awk '{print $1}'
    )
}

function k.providerid() {
  [ -z ${1+x} ] && return 1
  kubectl get node "$1" -o json | jq -r .spec.providerID | sed 's,.*/,,'
}

function k.ec2terminate {
  [ -z ${1+x} ] && return 1
  kubectl drain "$1" --ignore-daemonsets --delete-emptydir-data --force --timeout 5m
  sleep 10
  aws ec2 terminate-instances --instance-ids "$(k.providerid "$1")"
}

function k.ec2replaceall {
  for node in $(kubectl get nodes -o jsonpath="{.items[*].metadata.name}" -l "eks.amazonaws.com/compute-type notin (fargate)"); do
    k.ec2terminate "$node"
  done
}

function k.ssm() {
  [ -z ${1+x} ] && return 1
  aws ssm start-session --target $(k.providerid "$1")
}

function k.ssma() {
  # nodes="$(kubectl get nodes -o jsonpath="{.items[*].metadata.name}")"
  # test $? -eq 0 || return

  declare -a instanceIds=()

  for node in $(kubectl get nodes -o jsonpath="{.items[*].metadata.name}"); do
    instanceIds+=("$(k.providerid "$node")")
  done

  sessionName="eks-nodes-$(date "+%s")"
  tmux new-session -d -s "$sessionName" "aws ssm start-session --target ${instanceIds[0]}"

  for instanceId in "${instanceIds[@]}"; do
    [ "$instanceId" = "${instanceIds[0]}" ] && continue
    tmux split-window -t "$sessionName" "aws ssm start-session --target $instanceId"
    tmux select-layout -t "$sessionName" "tiled"
  done

  tmux attach-session -t "$sessionName"
  tmux select-layout -t "$sessionName" "tiled"
  tmux set-window-option -t "$sessionName" synchronize-panes on
}

function k.sh() {
  [ -z ${1+x} ] && return 1

  local pod="$1"

  [ ! -z ${2+x } ] && local container="--container=$2"

  kubectl exec -ti "$pod" "$container" -- sh
}

function k.portforward() {
  local ns="$1"
  local svc="$2"
  local rport="$3"
  local lport="$((($RANDOM % 65535) + 1024))"

  k -n "$ns" port-forward "$svc" "$lport:$rport" &

  for i in {1..20}; do
    nc -z 127.0.0.1 "$lport" && break
    sleep 1
  done

  xdg-open "http://127.0.0.1:$lport"
}

function k.prom() {
  k.portforward kube-system svc/kube-prometheus-stack-prometheus 9090
}

function k.alert() {
  k.portforward kube-system svc/kube-prometheus-stack-alertmanager 9093
}
