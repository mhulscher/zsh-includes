## Kubernetes / Deis Workflow -- administrative utilities

The scripts and aliasses provided by this project offer a workflow to interact
with both Kubernetes and Deis Workflow installations.

### Requirements

#### Shell

This will work with ZSH. Other shells have not been tested.

#### Binaries

Download the following binaries and place them in your `$PATH`:

* [download](https://coreos.com/kubernetes/docs/latest/configure-kubectl.html#download-the-kubectl-executable) `kubectl`
* [download](https://deis.com/docs/workflow/quickstart/install-cli-tools/) `deis-cli`
* [download](https://github.com/wercker/stern/releases) `stern`

### Installation


* Clone this repository somewhere. Here we assume we clone into `~/cluster-mgmt`
* Add the `bin/` directory to your path.
* Add the following to your `.zshrc`

```
$ git clone https://github.com/mhulscher/zsh-includes.git ~/cluster-mgmt

$ cat <<'EOF' >> ~/.zshrc

# Cluster management
PATH=$PATH:~/cluster-mgmt/bin
source ~/cluster-mgmt/cluster-mgmt.zsh
EOF
```

For switching between the context of multiple clusters, this project will assume a directory for every cluster inside `~/clusters`. Create these. If you disagree with this path, feel free to fork this project.

```
$ mkdir -pv ~/clusters

# For example, if you manage clusters called dev1, ext1 and int1
$ mkdir -pv ~/clusters/dev1 ~/clusters/ext1 ~/clusters/int1
```

### Usage

#### Cluster-context switching (kubeconfig context)

Issue `use-context some-cluster` to switch to the first context that matches the first  arrgument.
Same as `use-cluster` except it doesn't set `KUBECONFIG`.

#### Cluster-context switching (seperate KUBECONIG)

Using the `use-cluster` function you can switch between credentials of multiple clusters. This function will set the appropriate `KUBECONFIG` and `DEIS_PROFILE` environment variables. Assuming we want to switch context to a cluster called `usvc-dev1`, we make sure that the files below exist.

```
$ ls ~/.kube
usvc-dev1

$ ls ~/.deis
usvc-dev1.json

$ use-cluster usvc-dev1
Using cluster 'usvc-dev1'

$ pwd
~/clusters/usvc-dev1

$ env | grep 'KUBECONFIG\|DEIS_PROFILE'
KUBECONFIG=~/.kube/usvc-dev1
DEIS_PROFILE=usvc-dev1

$ deis whoami
You are john.doe at https://deis.dev1.example.com
```

#### Other functions

##### Kubernetes

The commands below require the `kubectl` binary and access to the Kubernetes-API.

|Command|Full name|Example invocation|Description
|---|---|---|---
|`kubesh`|Kubernetes Shell`|`kubesh default mypod`|Specify the namespace and pod to start a shell in
|`knsmon`|Kubernetes Namespace Monitor|`knsmon kube-system`|Prints an overview of objects inside a specific namespace
|`knprint`|Kubernetes Node Printer|`knprint`|Prints an overview of cluster-nodes including labels and annotations
|`ktopmem`, `ktpmem`|Kubernetes top pod (memory sorted)|`ktpmem`|Prints and refreshes an overview of `kubectl top pods` sorted by memory usage
|`ktopcpu`, `ktpcpu`|Kubernetes top pod (cpu sorted)|`ktpcpu`|Prints and refreshes an overview of `kubectl top pods` sorted by cpu usage
|`ktnmem`|Kubernetes top node (memory sorted)|`ktnmem`|Prints and refreshes an overview of `kubectl top nodes` sorted by memory usage
|`ktncpu`|Kubernetes top node (cpu sorted)|`ktncpu`|Prints and refreshes an overview of `kubectl top nodes` sorted by cpu usage
|`kpall`|Kubernetes get Pods all|`kpall`|Prints and refreshes a detailed list of all pods
|`kpnr`|Kubernetes get Pods Not Running|`kpnr`|Prints and refreshes a detailed list of all not-running pods
|`appmon`|Application Monitor|`appmon`|Uses the name of the current-directory as namespace-name and invokes `knsmon` on it
|`applogs`|Application Log Streamer|`applogs .`|***Requires stern*** Uses the name of the current-directory as namespace-name and invokes `stern` using this namespace
|`apps-from-namespaces`|`-`|`apps-from-namespaces`|Creates a directory inside the current directory for every namespace found using `kubectl get namespaces`

##### Deis Workflow

The commands below require the `deis` binary and access to the Deis Workflow API.

|Command|Description
|---|---
|`apps-from-deis`|Creates a directory inside the current directory for every application found using `deis apps`
