# cluster mgmt functions

function p_info {
  echo "\n\e[42m[+]\e[0m $*\n"
}

# alias cssh-k8s-nodes='cssh -ns $(kubectl get nodes -o jsonpath="{.items[*].metadata.name}")'
alias cssh-k8s-nodes='cssh -u root -sa "-o StrictHostKeyChecking=no" -ns $(kubectl get nodes -o jsonpath="{.items[*].status.addresses[0].address}")'

alias ktopmem="watch -t 'kubectl top pods --all-namespaces | sort -rnk4'"
alias ktopcpu="watch -t 'kubectl top pods --all-namespaces | sort -rnk3'"
alias ktpmem="watch -t 'kubectl top pods --all-namespaces | sort -rnk4'"
alias ktpcpu="watch -t 'kubectl top pods --all-namespaces | sort -rnk3'"

alias ktnmem="watch -t 'kubectl top nodes | sort -rnk4'"
alias ktncpu="watch -t 'kubectl top nodes | sort -rnk3'"

alias kpls="kubectl get pods --all-namespaces -o wide"
alias kpall="watch -t 'kubectl get pods --all-namespaces -o wide'"
alias kpnr="watch -t \"kubectl get pods --all-namespaces -o wide | grep -v ' Running '\""
alias kpo="kubectl get pods --all-namespaces | sed 1d | awk '{print \$4}' | perl -ne 'chomp;\$data{\$_}++;END{printf \"%-20s \$data{\$_}\n\", \"\$_\" for sort keys %data};'"

alias pxctl='kubectl -n kube-system exec -c portworx -ti $(kubectl -n kube-system get pods -l name=portworx -ocustom-columns=NAME:.metadata.name --no-headers | head -n1) -- /opt/pwx/bin/pxctl'

function kgetc { kubectl -n ${1} get po/${2} -o json | jq -Mr ".spec.containers[].name" }

function kinjectkey {
  local pod="libio-key-installer"

  local reply=""
  echo -n "Inject SSH-key on all nodes? [yn] " 
  read reply
  [ "${reply}" != "y" ] && return 1

  # Cleanup remaining pods
  kubectl delete po -l app=${pod} >/dev/null 2>&1

  for node in $(kubectl get nodes -o jsonpath="{.items[*].metadata.name}"); do
    p_info "${node}: running ${pod}"

    cat <<EOF | kubectl apply -f-
apiVersion: v1
kind: Pod
metadata:
  name: ${pod}
  labels:
    app: ${pod}
spec:
  containers:
  - image: alpine
    name: ${pod}
    command:
    - /bin/sh
    - -xc
    - grep -q 'mitch.hulscher@lib.io' /root/.ssh/authorized_keys || echo "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAucUjmnEszJrcFAfikVZOEY0vEBZk0IEu9uuvGHG1URkn9D03QSoZ/0JyvifRR+r3YbxZgstPtHrvf9yWVmuuvP6B/aaoP4LIflfFPyfJPLgO4OHNjN/DBcpNkXPKNv/E3hV9cEH62k8y5RDi0qRE1slXRlOjn1uZYGLfcv1l8J+04pGWWhQJj6VTk8XDQUzuHsA4ftgOVgrNWx1sH0pi1hS+4Agx13gqe8oMarS+vrvbAlB8AtqM4SHIoXb0vQGibIuSxYZF7ISp1NcWBddtnWNT2K2rdmd/7rZBYtGGF+29p3io1VLxj2V98EJNo4qxXEP/Ovi4ZnK5Asu5qjynkw== mitch.hulscher@lib.io" >> /root/.ssh/authorized_keys
    volumeMounts:
    - mountPath: /root/.ssh
      name: ssh
  nodeSelector:
    kubernetes.io/hostname: ${node}
  restartPolicy: Never
  tolerations:
  - operator: "Exists"
  volumes:
  - hostPath:
      path: /root/.ssh
    name: ssh
EOF

    sleep 5

    while kubectl get po -l app=${pod} --no-headers | awk '{print $3}' | tail -n1 | grep -qv Completed ; do
      p_info "${node}: waiting on pod to complete"
      sleep 5
    done

    p_info "${node}: done"
    kubectl delete po -l app=${pod}
  done
}

function knodeshell {
  if [ -z ${1+x} ]; then
    echo >&2 "Missing argument: hostname"
    return 1
  fi

  local node=${1}
  local namespace=${2:-kube-system}
  local pod=${3:-kube-dashboard}
  local manifest=$(mktemp)

  pod="${pod}-$(cat /dev/urandom|tr -dc '0-9'|fold -w10|head -n1)-$(cat /dev/urandom|tr -dc 'a-z0-9'|fold -w5|head -n1)"

  while kubectl -n ${namespace} get po ${pod} >/dev/null 2>&1; do
    kubectl -n ${namespace} delete po ${pod} >/dev/null 2>&1 || true
    sleep 1
  done

  cat <<EOF > ${manifest}
apiVersion: v1
kind: Pod
metadata:
  name: ${pod}
spec:
  containers:
  - image: debian:stable-slim
    name: ${pod}
    env:
    - name: LANG
      value: en_US.UTF-8
    - name: TERM
      value: "xterm-256color"
    - name: PS1
      value: "${node}# "
    tty: true
    stdin: true
    securityContext:
      privileged: true
    command:
    - sleep
    - infinity
    volumeMounts:
    - mountPath: /mnt
      name: root
  nodeSelector:
    kubernetes.io/hostname: ${node}
  restartPolicy: Never
  securityContext: {}
  hostIPC: true
  hostPID: true
  hostNetwork: true
  tolerations:
  - operator: "Exists"
  volumes:
  - hostPath:
      path: /
    name: root
EOF

  kubectl -n ${namespace} apply -f ${manifest} >/dev/null || return 1
  rm ${manifest}

  local tries=20
  for i in $(seq 0 ${tries}); do
    if [ "$(kubectl -n ${namespace} get po ${pod} -o json | jq -Mr .status.phase)" = "Running" ]; then
      kubectl -n ${namespace} exec -ti ${pod} -- chroot /mnt bash
      break
    else
      echo "Waiting for pod '${pod}' to become ready... ${i}/${tries}"
      sleep 2
    fi
  done

  kubectl -n ${namespace} delete po/${pod} --now || true
}
