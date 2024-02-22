# How to build MLMD in a disconnected environment?

This document will provide guidance on how to generate an archive, containing external dependencies and bazel cache, that can be used to build MLMD in a disconnected/offline environment.

## Prerequisites

1. Docker
2. Git
3. More than 20GB of free space

## Instructions

0. Clone this repository

```bash
git clone git@github.com:lampajr/mlmd-bazel-cache.git
```

or simply download the [Dockerfile](./Dockerfile)

```bash
wget https://raw.githubusercontent.com/lampajr/mlmd-bazel-cache/main/Dockerfile
```

1. Clone the `ml-metadata` project and checkout to the branch/tag taht you'd like to build in offline mode.

```bash
git clone --branch $BRANCH git@github.com:red-hat-data-services/ml-metadata.git
```

2. Checkout the local folder

```bash
cd ml-metadata
```

3. Build the docker image containing the fetched dependencies

```bash
docker build -t $IMAGE_NAME:$IMAGE_TAG -f path/to/mlmd-bazel-cache/Dockerfile .
```

4. Run the created image

```bash
docker run --name $CONTAINER_NAME -it $IMAGE_NAME:$IMAGE_TAG
```

5. Copy the content from the running container into your local filesystem

```bash
CONTAINER_ID=$(docker ps -aqf "name=$CONTAINER_NAME")

mkdir ./_bazel_root
docker cp $CONTAINER_ID:/root/.cache/bazel/_bazel_root/13c4dbfe298d1ad9f047b4ec78c9d429 ./_bazel_root/
docker cp $CONTAINER_ID:/root/.cache/bazel/_bazel_root/cache ./_bazel_root/

# remove this as this is a cyclic reference to the ml-metadata project, not required
rm -rf ./_bazel_root/13c4dbfe298d1ad9f047b4ec78c9d429/external/ml_metadata
```

Expected result:
```bash
$ tree -L 1 _bazel_root
_bazel_root
├── 13c4dbfe298d1ad9f047b4ec78c9d429
└── cache

3 directories, 0 files
```

6. Create the tar.gz archive

```bash
# Run from the ml-metadata directory
SHA=$(git rev-parse --short HEAD)

# Run from the directory containing _bazel_root folder
tar -czvf bazel_root_$SHA.tar.gz _bazel_root
```

## Note

There are some aspects that should be taken into account in order to guarantee that the build will work in a disconnected environment.

1. The base image should match the one that will be used in the disconnected container build

```dockerfile
FROM registry.redhat.io/ubi8/ubi:8.9
```

2. The working directory name in [Dockerfile](./Dockerfile) must match the one used in your disconnected Dockerfile build

```dockerfile
WORKDIR /mlmd-src
```

This is needed because `bazel` creates the `output_base` directory as the hash of the client's workspace root.

> Note: see how `bazel` creates directories [here](https://bazel.build/remote/output-directories#layout-diagram)

3. The `bazel` version _should_ be the same used in the disconnected environment, if using custom RPM I would suggest to inject and use that one.

4. If you experience during the disconnected build:
```bash
0.236 Starting local Bazel server and connecting to it...
1.577 Loading: 
1.580 Loading: 0 packages loaded
1.643 ERROR: no such package '@bazel_tools//tools/build_defs/repo': to fix, run
1.643 	bazel fetch //...
1.643 External repository @bazel_tools not found and fetching repositories is disabled.
```
This could mean that `_bazel_root/13c4dbfe298d1ad9f047b4ec78c9d429/external/bazel_tools` symlink is broken.
Possible root cause is that the bazel extracted installation has different hash `/root/.cache/bazel/_bazel_root/install/<HASH>`