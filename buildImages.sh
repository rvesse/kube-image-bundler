#!/usr/bin/env bash

REPO=${1:-rvesse}
NAME=${2:-kubeadm}
PUSH=$3
VERSIONS=("1.13.0" "1.12.3" "1.11.5" "1.10.11" "1.9.11")

function buildAndTagVersion() {
  local TARGET_VERSION=$1
  shift
  
  docker build -t ${REPO}/${NAME}:v${TARGET_VERSION} --build-arg KUBE_VERSION=${TARGET_VERSION} .

  if [ -n "${PUSH}" ]; then
    docker push ${REPO}/${NAME}:v${TARGET_VERSION}
  fi

  if [ $# -gt 0 ]; then
    for TAG in $@; do
      docker tag ${REPO}/${NAME}:v${TARGET_VERSION} ${REPO}/${NAME}:${TAG}

      if [ -n "${PUSH}" ]; then
        docker push ${REPO}/${NAME}:${TAG}
      fi
    done
  fi 
}

# Build version specific images
for VERSION in ${VERSIONS[@]}; do
  SHORT_TAG=$(echo ${VERSION} | awk -F '.' '{print $1 "." $2}')
  buildAndTagVersion ${VERSION} ${SHORT_TAG} "v${SHORT_TAG}"
done

# Tag latest image
set +x
docker tag ${REPO}/${NAME}:v${VERSIONS[0]} ${REPO}/${NAME}:latest
