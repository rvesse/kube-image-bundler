FROM centos
MAINTAINER Rob Vesse <rvesse@dotnetrdf.org>

# Firstly install Docker to give us a common base layer
COPY kubernetes.repo /etc/yum.repos.d/
RUN yum install -y docker

# Then install the desired kubeadm version
ARG KUBE_VERSION
RUN yum install -y kubeadm-${KUBE_VERSION}
