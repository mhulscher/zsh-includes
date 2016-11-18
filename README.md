# HOWTO

* Add the `bin/` directory to your path.
* Add the following to your `.zshrc`:

```
source cluster-mgmt.zsh
```

Create the following directories:

```
~/clusters

# For example, cluster called dev1, ext1 and int1
~/clusters/dev1
~/clusters/ext1
~/clusters/int1
```

# Requirements

You will need the following tools in your path:

* `kubectl`
* `deis-cli`
* `stern`
