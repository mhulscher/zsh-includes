function k() {
  if ! command -v kubectl 2>&1 >/dev/null; then
    echo >&2 "kubectl is not installed"
    exit 1
  fi

  kubectl "$@" 
}

function k.lc() {
  k config get-contexts
}

function k.uc() {
  [ -z ${1+x} ] && return 1
  local q=${1}
  local ctxt=$(k config get-contexts | sed -e 1d | sed 's,\*,,' | awk '{print $1}' | grep ${q} | head -n1)

  if [ "${ctxt}x" = "x" ]; then
    echo >&2 "context not found"
    return 1
  fi

  k config use-context ${ctxt}
}

function k.ns() {
  k config set-context $(k config current-context) --namespace ${1}
}

k.is_valid_object() {
  [ -z ${1+x} ] && return 1
  local search=${1}
  local objects=$(k get 2>&1 | grep -oP "(?<=\* )[a-z]+|(?<=aka ')[a-z]+" | tr '\n' ' ')

  for object in $(echo ${objects}); do
    if [ ${object} = ${search} ]; then
      export KUBE_IS_OBJECT=1
      break
    fi
  done
}

function k.ls () {
  if [ $# -eq 0 ]; then
    k get pods
    return 0
  fi
  
  local param=${1%/*}

  export KUBE_IS_OBJECT=0
  k.is_valid_object ${param}

  if [ ${KUBE_IS_OBJECT} -eq 1 ]; then
    k get "$@"
  else
    k get pods "$@"
  fi
}

function k.la() {
  k.ls "$@" --show-all=true --include-uninitialized=true
}

function k.ll() {
  k.ls "$@" --show-labels=true --output=wide
}

function k.lla() {
  k.ls "$@" --show-all=true --include-uninitialized=true --show-labels=true --output=wide
}

function k.del() {
  [ -z ${1+x} ] && return 1

  echo -n "Do you really want to 'kubectl delete $@'? [yn] "
  read reply

  [ ${reply} = "y" ] && k delete "$@"
}

function k.delr() {
  [ -z ${1+x} ] && return 1

  local search=${1}
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
  echo -n "I am about to delete these ${count} pods, one-by-one. Are you sure? [yn] "
  read reply

  if [ ${reply} = "y" ]; then
    local index=1
    for pod in $(echo ${pods} | awk '{print $1}'); do
      echo -e "\nDeleting pod (${index}/${count}): ${pod}"
      k delete pods ${pod}
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
