# foreman-idevfsd

Whip up Foreman in a bunch of Docker containers (one for the
front-end, another one for the smart proxy, plus PostgreSQL and
Træfik). Then, use that and Foreman +
[foreman_ansible](https://theforeman.org/plugins/foreman_ansible/3.x/index.html)
that to spray some
[Kubespray](https://github.com/kubernetes-sigs/kubespray) everywhere.

## Quickstart

Inventory of clusters you want to Kubespray is in [managed-inventory.yml](managed-inventory.yml). Once you have made the desired changes,

```
./foresible
```

Then [log in to Foreman](https://itsidevfsd0005.xaas.epfl.ch:9090/),
install the nodes (see detailed procedure below), and finally look for
the Kubespray button under Configure → Host Groups.

Precious state: none (besides whatever you put onto the generated Kubernetei of course)

Semi-precious state:
- ssh key that Foreman puts into nodes' `/root/.ssh` to retain access — If you lose it you will either have to reinstall the node, or put the new one back in by hand
- front-end certificate — If you lose it, your browser will complain. Again

## Detailed Install Procedure

Foreman is configured to install (or reinstall) all the cluster nodes with Ubuntu 20.04.

(To be continued)
