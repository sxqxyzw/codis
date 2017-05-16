## Usage

### dependence

This codis running in k8s need zookeeper running in the k8s environment, or some other zookeeper cluster accessible.

### Build codis image

```
$ docker build -f ../Dockerfile -t codis-image
```

### Build one codis cluster

```
$ sh setup.sh buildup
```

### Clean up the codis cluster

```
$ sh setup.sh cleanup
```

### Scale codis cluster proxy

```
$ sh setup.sh scale-proxy $(number)
```

### Scale codis cluster server

```
$ sh setup.sh scale-server $(number)
```


