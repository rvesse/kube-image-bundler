#!/usr/bin/env bash

function showUsage() {
  cat <<EOF
Kubernetes Image Bundler

  ./bundle-k8s-images.sh [OPTIONS]

Where OPTIONS are as follows:

  -a <kubeadm-version>       Specifies the version of kubeadm image to use

  -e <image-ref>             Specifies extra images to bundle

  -h                         Shows this help and exits

  -k <k8s-version>           Specifies the version of Kubernetes to bundle images for

NB - kubeadm only supports listing the relevant images with 1.11 and higher.  Additionally kubeadm
     can typically only install a cluster within a single minor version of the kubeadm version.
     Therefore you need to select an appropriate kubeadm version for the desired Kubernetes version.
     If the kubeadm version is not explicitly specified then the tool will select a version based on
     the specified Kubernetes version.

     For example:

       ./bundle-k8s-images.sh -a 1.11 -k 1.10.11

     Or:

       ./bundle-k8s-images.sh -k 1.12.3
EOF
}

KUBE_VERSION=
KUBEADM_IMAGE_VERSION=
EXTRA_IMAGES=()
PARSED_OPTIONS=$(getopt ":k:a:e:h" -- "$@")
eval set "${PARSED_OPTIONS}"
while [ $# -gt 0 ]; do
  case "$1" in
    -k)
      if [ -z "$2" ]; then
        echo "Option -k requires a version to be specified"
        exit 1
      fi
      KUBE_VERSION="$2"
      shift 2
      ;;
    -a)
      if [ -z "$2" ]; then
        echo "Option -a requires a version to be specified"
        exit 1
      fi
      KUBEADM_IMAGE_VERSION="$2"
      shift 2
      ;;
    -e)
      if [ -z "$2" ]; then
        echo "Option -e requires an image reference to be specified"
        exit 1
      fi
      EXTRA_IMAGES+=("$2")
      shift 2
      ;;
    -h)
      showUsage
      exit 0
      ;;
    *)
      echo "Unexpected option $1"
      exit 1
      ;;
  esac
done

if [ -z "${KUBE_VERSION}" ]; then
  echo "No KUBE_VERSION specified"
  exit 1
fi
if [ -z "${KUBEADM_IMAGE_VERSION}" ]; then
  KUBEADM_IMAGE_VERSION=$(echo ${KUBE_VERSION} | awk -F '.' '{print $1 "." $2}')
  echo "Auto-configured kubeadm image version as ${KUBEADM_IMAGE_VERSION} based on specified K8S version ${KUBE_VERSION}"
fi

function error() {
  local MESSAGE=$1
  local EXIT_CODE=${2:-1}
  echo "ERROR: ${MESSAGE}"
  exit ${EXIT_CODE}
}

# Obtain the K8S images list
IMAGES=$(docker run --rm -v /var/run/docker.sock:/var/run/docker.sock rvesse/kubeadm:${KUBEADM_IMAGE_VERSION} kubeadm config images list --kubernetes-version ${KUBE_VERSION})
if [ $? -ne 0 ]; then
  error "Failed to list K8S images"
fi
IMAGES=($IMAGES)
echo "Found ${#IMAGES[@]} images to bundle"
if [ "${#IMAGES[@]}" -eq 0 ]; then
  error "Failed to detect any K8S images"
  exit 1
fi
if [ "${#EXTRA_IMAGES[@]}" -gt 0 ]; then
  echo "Will bundle ${#EXTRA_IMAGES[@]} extra images: ${EXTRA_IMAGES[@]}"
  IMAGES+=("${EXTRA_IMAGES[@]}")
fi

# Pull the desired images
for IMAGE in ${IMAGES[@]}; do
  docker pull ${IMAGE}
  if [ $? -ne 0 ]; then
    error "Failed to pull image ${IMAGE}"
  fi

  IMAGE=${IMAGE##k8s.gcr.io/}
  TAG=$(echo "${IMAGE}" | cut -d ':' -f 2)
  IMAGE=${IMAGE%%:${TAG}}
  if [ "${IMAGE}" == "pause" ]; then
    docker tag "k8s.gcr.io/${IMAGE}:${TAG}" "k8s.gcr.io/${IMAGE}-amd64:${TAG}"
    IMAGES+=("k8s.gcr.io/${IMAGE}-amd64:${TAG}")
  fi
done

# If this version was previously exported nuke the existing export
EXPORT_FILE="k8s_${KUBE_VERSION}_images.tar"
if [ -f "${EXPORT_FILE}" ]; then
  rm -f "${EXPORT_FILE}"
  if [ $? -ne 0 ]; then
    error "Failed to remove previously exported images ${EXPORT_FILE}"
  fi
fi

# Then we want to run another command to save the images
echo "Exporting Docker images as TAR archive, this may take a while..."
docker save -o "${EXPORT_FILE}" "${IMAGES[@]}"
if [ $? -ne 0 ]; then
  error "Failed to save K8S images"
fi
echo "Docker images exported as ${PWD}/${EXPORT_FILE}"
