#!/usr/bin/env bash

function showUsage() {
  cat <<EOF
Kubernetes Image Bundler

  ./bundle-k8s-images.sh [OPTIONS]

Where OPTIONS are as follows:

  -a <kubeadm-version>       Specifies the version of kubeadm image to use

  -d                         Specifies debug mode, displays all commands being run by this
                             script

  -e <image-ref>             Specifies extra images to bundle

  -f <features-gates>        Specifies a comma separated list of key value pairs that are passed to
                             kubeadm via the --feature-gates flag as feature gates may affect the list
                             of images you need to bundle

  -g                         Specifies that the resulting bundle should be gzipped

  -h                         Shows this help and exits

  -k <k8s-version>           Specifies the version of Kubernetes to bundle images for

NB - kubeadm only supports listing the relevant images with 1.11 and higher.  Additionally kubeadm
     can typically only install a cluster within a single minor version of the kubeadm version.
     Therefore you need to select an appropriate kubeadm version for the desired Kubernetes version.
     If the kubeadm version is not explicitly specified then the tool will select a version based on
     the specified Kubernetes version.

     For example:

       ./bundle-k8s-images.sh -a 1.11 -k 1.10.11

     Bundling images to use the old kube-dns DNS provider:

       ./bundle-k8s-images.sh -a 1.11 -k 1.10.11 -f CoreDNS=false

     Or:

       ./bundle-k8s-images.sh -k 1.12.3
EOF
}

KUBE_VERSION=
KUBEADM_IMAGE_VERSION=
EXTRA_IMAGES=()
FEATURE_GATES=
GZIP=
PARSED_OPTIONS=$(getopt ":k:a:e:f:hdg" -- "$@")
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
    -f)
      if [ -z "$2" ]; then
        echo "Option -f requires a comma separated list of feature gates to be specified"
        exit 1
      fi
      FEATURE_GATES=$2
      shift 2
      ;;
    -h)
      showUsage
      exit 0
      ;;
    -d)
      set -x
      shift
      ;;
    -g)
      GZIP=true
      shift
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

function listImages() {
  while [ $# -gt 0 ];
  do
    echo $1
    shift
  done
}

# Obtain the K8S images list
KUBEADM_COMMAND="docker run --rm -v /var/run/docker.sock:/var/run/docker.sock rvesse/kubeadm:${KUBEADM_IMAGE_VERSION} kubeadm config images list --kubernetes-version ${KUBE_VERSION}"
if [ -n "${FEATURE_GATES}" ]; then
  KUBEADM_COMMAND="${KUBEADM_COMMAND} --feature-gates ${FEATURE_GATES}"
fi
IMAGES=$(${KUBEADM_COMMAND})
if [ $? -ne 0 ]; then
  error "Failed to list K8S images"
fi
IMAGES=($IMAGES)
echo "Found ${#IMAGES[@]} images to bundle:"
if [ "${#IMAGES[@]}" -eq 0 ]; then
  error "Failed to detect any K8S images"
  exit 1
else
  listImages ${IMAGES[@]}
fi
if [ "${#EXTRA_IMAGES[@]}" -gt 0 ]; then
  echo "Will bundle ${#EXTRA_IMAGES[@]} extra images:"
  listImages ${EXTRA_IMAGES[@]}
  IMAGES+=("${EXTRA_IMAGES[@]}")
fi

echo ""

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

# GZip if requested
if [ -n "${GZIP}" ]; then
  echo "Compressing bundle with GZip..."
  ls -lh "${EXPORT_FILE}"
  gzip "${EXPORT_FILE}"
  EXPORT_FILE="${EXPORT_FILE}.gz"
  ls -lh "${EXPORT_FILE}"
fi

echo "Docker images exported as ${PWD}/${EXPORT_FILE}"
