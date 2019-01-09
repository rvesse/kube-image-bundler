#!/usr/bin/env bash

KUBE_VERSION=$1
if [ -z "${KUBE_VERSION}" ]; then
  echo "No KUBE_VERSION specified"
  exit 1
fi
KUBEADM_IMAGE_VERSION=$2
if [ -z "${KUBEADM_IMAGE_VERSION}" ]; then
  KUBEADM_IMAGE_VERSION=$(echo ${KUBE_VERSION} | awk -F '.' '{print $1 "." $2}')
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
