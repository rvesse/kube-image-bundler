#!/usr/bin/env bash

function showUsage() {
  cat <<EOF
Kubeadm Image Builder

  ./buildImages.sh [OPTIONS]

Where OPTIONS are as follows:

  -h                   Displays this help and exits

  -l <latest-version>  Specifies the version of kubeadm to tag as latest

  -n <name>            Name for the built images (defaults to kubeadm)

  -p                   When specified push all the built images to the specified Docker
                       repository

  -r <repo>            Specifies the Docker repository to use (defaults to your username)

  -v <version>         Specifies a version of kubeadm to build an image for.  May be
                       specified multiple times to build multiple images

EOF
}

REPO=
NAME=
PUSH=
LATEST=
VERSIONS=()
PARSED_OPTIONS=$(getopt "r:n:l:v:ph" -- "$@")
eval set "${PARSED_OPTIONS}"
while [ $# -gt 0 ]; do
  case "$1" in
    -h)
      showUsage
      exit 0
      ;;
    -l)
      if [ -z "$2" ]; then
        echo "Option -l requires a version to be specified"
        exit 1
      fi
      LATEST=$2
      shift 2
      ;;
    -n)
      if [ -z "$2" ]; then
        echo "Option -n requires an image name to be specified"
        exit 1
      fi
      NAME=$2
      shift 2
      ;;
    -p)
      PUSH=true
      shift
      ;;
    -r)
      if [ -z "$2" ]; then
        echo "Option -r requires a Docker repository to be specified"
        exit 1
      fi
      REPO=$2
      shift 2
      ;;
    -v)
      if [ -z "$2" ]; then
        echo "Option -v requires a version to be specified"
        exit 1
      fi
      VERSIONS+=("$2")
      shift 2
      ;;
    *)
      echo "Unexpected option $1"
      exit 1
      ;;
  esac
done

if [ -z "${REPO}" ]; then
  echo "Required repository option -r <repo> was not set"
  exit 1
fi
if [ "${#VERSIONS[@]}" -eq 0 ]; then
  echo "No -v <version> options specified so using default version list: ${VERSIONS[@]}"
  VERSIONS=("1.13.0" "1.12.3" "1.11.5" "1.10.11" "1.9.11")
fi

function buildAndTagVersion() {
  local TARGET_VERSION=$1
  shift
  
  docker build -t ${REPO}/${NAME}:v${TARGET_VERSION} --build-arg KUBE_VERSION=${TARGET_VERSION} docker/

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
  buildAndTagVersion ${VERSION} ${VERSION} "v${VERSION}" ${SHORT_TAG} "v${SHORT_TAG}"
done

# Tag latest image
if [ -n "${LATEST}" ]; then
  docker tag ${REPO}/${NAME}:${LATEST} ${REPO}/${NAME}:latest
fi
