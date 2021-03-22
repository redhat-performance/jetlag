# RAN workload

1. Clone the repo to the bastion machine
2. Check/review size of workload and workload config
3. Run desired workload

## RAN workload with labels

Prior to running any RAN workloads with selectors, you must create a number of labels beforehand. Scripts have been provided to make this easy.

Create 100 shared labels across the cluster

```console
./create-shared-labels.sh rwn=true 100
```

Create 100 unique labels per node per RAN workload pod (2 pods * 6 nodes * 100 labels)

```console
./create-unique-labels.sh rwn=true 1200
```

Clear all of the above created labels

```console
./clear-labels.sh rwn=true 600
```
