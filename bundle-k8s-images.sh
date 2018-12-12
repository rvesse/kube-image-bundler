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
  cleanup
  exit ${EXIT_CODE}
}

function cleanup() {
  # Dump Docker daemon logs
  docker logs clean-docker > daemon.log 2>&1

  # Clean up after ourselves
  docker stop clean-docker
  docker rm clean-docker

  # Destroy our temporary data store
  rm -Rf ${IMAGE_DIR}
}

# Make a temporary folder
IMAGE_DIR=/tmp/${USER}-$$
mkdir -p "${IMAGE_DIR}/images" "${IMAGE_DIR}/export"
rm -Rf "${IMAGE_DIR}/images/*" "${IMAGE_DIR}/export/*"

# Start Docker in Docker Daemon
docker run --privileged --name clean-docker -d -v ${IMAGE_DIR}/images:/var/lib/docker docker:dind --storage-driver=overlay2
if [ $? -ne 0 ]; then
  error "Failed to start clean Docker daemon"
fi

# Link another image and obtain the images in it
IMAGES=$(docker run --rm --link clean-docker:docker rvesse/kubeadm:${KUBEADM_IMAGE_VERSION} kubeadm config images list --kubernetes-version ${KUBE_VERSION})
if [ $? -ne 0 ]; then
  error "Failed to list K8S images"
fi
IMAGES=($IMAGES)
echo "Found ${#IMAGES[@]} images to bundle"
if [ "$#IMAGES[@]}" -eq 0 ]; then
  error "Failed to detect any K8S images"
fi

# Pull the desired images
for IMAGE in ${IMAGES[@]}; do
  docker pull ${IMAGE}
  if [ $? -ne 0 ]; then
    error "Failed to pull image ${IMAGE}"
  fi
done
# Then we want to run another command to save the images
docker save -o ${IMAGE_DIR}/export/k8s_${KUBE_VERSION}_images.tar "${IMAGES[@]}"
if [ $? -ne 0 ]; then
  error "Failed to save K8S images"
fi

cp ${IMAGE_DIR}/export/k8s_${KUBE_VERSION}_images.tar .
if [ $? -ne 0 ]; then
  error "Failed to find saved K8S images"
fi

# Clean up
cleanup
