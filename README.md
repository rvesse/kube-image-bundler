# Kubernetes Image Bundler

This repository contains simple scripts and associated Docker image to aid in obtaining and bundling up the Kubernetes system images into a TAR archive which can then be used with `docker load` to bootstrap the image registry on offline/air-gapped systems.

## Usage

Run the `bundle-k8s-images.sh` script passing in the desired Kubernetes version and optionally the `kubeadm` image version to use e.g.

```
> ./bundle-k8s-images.sh -k 1.10.11 -a v1.11
```
Will produce a `k8s_v1.10.11_images.tar` file.

Where options can be viewed by running with the `-h` option.  Only required option is `-k <k8s-version>` to specify the desired Kubernetes version.

**NB:** This feature of `kubeadm` was only added from 1.11 onwards and `kubeadm` is typically only able to provide images for versions within 1 minor version of it.  Therefore you should use an image version as close to the desired Kubernetes version as possible.  The `-a <kubeadm-version>` option specifies the desired `kubeadm` image version, if omitted the script selects a version based on the specified `-k <k8s-version>` option which may not be correct when targeting older versions of Kubernetes.

**WARNING:** We have observed cases where the set of bundled images is not sufficient to run Kubernetes fully e.g. missing sidecar images.  It is unclear if this is a bug in `kubeadm` itself or a side-effect of specific K8S configuration choices we have made.

The `kubeadm` image is publicly available on Docker Hub as `rvesse/kubeadm` with various tags covering 1.9 through 1.13.  You can optionally build your own images using the other contents of this repository.

If you need to bundle additional images e.g. for your network overlay or other system services you can use the `-e <image-ref>` option as many times as you want to specify additional images to bundle e.g.

```
> ./bundle-k8s-images.sh -k 1.10.11 -a 1.11 -e quay.io/romana/agent:v2.0.2 -e quay.io/romana/listener:v2.0.2 -e quay.io/romana/daemon:v2.0.2
```

## Building the Docker Image (Optional)

If you want to build your own images with Docker + `kubeadm` you can do so using the `Dockerfile` provided here.  The provided `buildImages.sh` script will build images for all recent `kubeadm` versions.  The script takes three arguments:

```
> ./buildImages.sh -r <repo> -n <image-name> -p
```
The `<repo>` and `<image-name>` arguments are used together with the versions to form a full image tag in the format `<repo>/<name>:<version>`.

The default versions which are built are hardcoded into the script as a Bash array.  You can use the `-v <version>` option to build images for specified `kubeadm` versions. You can optionally specify `-d` to always include the default list of versions.  If no versions are explicitly specified then the default list will be used.

If `-p` is given then the resulting images are also pushed to the selected `<repo>`.

You can use `-l <version>` to specify that a specific version should also be tagged as `latest`.
