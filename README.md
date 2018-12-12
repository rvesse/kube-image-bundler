# Kubernetes Image Bundler

This repository contains simple scripts and associated Docker image to aid in obtaining and bundling up the Kubernetes system images into a TAR archive which can then be used with `docker load` to bootstrap the image registry on offline/air-gapped systems.

## Usage

Run the `bundle-k8s-images.sh` script passing in the desired Kubernetes version and optionally the `kubeadm` image version to use e.g.

```
> ./bundle-k8s-images.sh 1.10.11 v1.11
```
Will produce a `k8s_v1.10.11_images.tar` file.

The optional second argument refers to an image that contains Docker + Kubeadm and is used to obtain the images via the `kubeadm config images list` command.

**NB:** This feature of `kubeadm` was only added from 1.11 onwards and `kubeadm` is typically only able to provide images for versions within 1 minor version of it.  Therefore you should use an image version as close to the desired Kubernetes version as possible.

The `kubeadm` image is publicly available on Docker Hub as `rvesse/kubeadm` with various tags covering 1.9 through 1.13.  You can optionally build your own images using the other contents of this repository.

## Building the Docker Image (Optional)

If you want to build your own images with Docker + `kubeadm` you can do so using the `Dockerfile` provided here.  The provided `buildImages.sh` script will build images for all recent `kubeadm` versions.  The script takes three arguments:

```
> ./buildImages.sh <repo> <image-name> <push>
```
The `<repo>` and `<image-name>` arguments are used together with the versions to form a full image tag in the format `<repo>/<name>:<version>`.  The versions which are built are hardcoded into the script currently as a Bash array.  If `<push>` is given any non-zero value the resulting images are also pushed to the selected `<repo>`.

## Future Work

- Refactor scripts to use `getopt` for argument parsing