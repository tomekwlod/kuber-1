#!/bin/bash

swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# echo "Removing old docker if any"
# yum remove -y docker docker-ce docker-ce-cli

echo "Installing bare minimum soft"
yum install -y firewalld httpd-tools \
    && systemctl start firewalld \
    && systemctl enable firewalld

# https://kubernetes.io/docs/setup/production-environment/container-runtimes/#docker vvv
echo "Installing docker";
yum install -y yum-utils \
    device-mapper-persistent-data \
    lvm2
yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

# yum list docker-ce     --showduplicates | sort -r  <---- check the CE  versions available
# yum list docker-ce-cli --showduplicates | sort -r  <---- check the CLI versions available
# yum install -y docker-ce docker-ce-cli containerd.io
yum install -y docker-ce-18.09.9 docker-ce-cli-18.09.9 containerd.io
# proper version of docker for this kuber version https://kubernetes.io/docs/setup/release/notes/#unchanged

systemctl start docker
systemctl enable docker
# https://kubernetes.io/docs/setup/production-environment/container-runtimes/#docker ^^^

# https://kubernetes.io/docs/tasks/debug-application-cluster/debug-service/#does-the-service-work-by-dns
# install nslookup https://unix.stackexchange.com/a/164212
yum install -y bind-utils

# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl vvv
echo "Installing kubernetes"
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

# Set SELinux in permissive mode (effectively disabling it)
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

systemctl enable --now kubelet

# Make sure that the br_netfilter module is loaded before this step. This can be done by running lsmod | grep br_netfilter. To load it explicitly call modprobe br_netfilter
lsmod | grep br_netfilter && modprobe br_netfilter

cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl ^^^

echo "Deploying kubernetes"
# if kubeadm is running and we re-run this install.sh then here it will throw fatal error
# do kubeadm reset - to use this command again
res=$(kubeadm init --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=NumCPU 2>&1) # add --apiserver-advertise-address="ip" if you want to use a different IP address than the main server IP

# expected output - when executed second time :/
#[init] Using Kubernetes version: v1.16.2
#[preflight] Running pre-flight checks
#	[WARNING Firewalld]: firewalld is active, please ensure ports [6443 10250] are open or your cluster may not function correctly
#	[WARNING IsDockerSystemdCheck]: detected "cgroupfs" as the Docker cgroup driver. The recommended driver is "systemd". Please follow the guide at https://kubernetes.io/docs/setup/cri/
#error execution phase preflight: [preflight] Some fatal errors occurred:
#	[ERROR Port-6443]: Port 6443 is in use
#	[ERROR Port-10251]: Port 10251 is in use
#	[ERROR Port-10252]: Port 10252 is in use
#	[ERROR FileAvailable--etc-kubernetes-manifests-kube-apiserver.yaml]: /etc/kubernetes/manifests/kube-apiserver.yaml already exists
#	[ERROR FileAvailable--etc-kubernetes-manifests-kube-controller-manager.yaml]: /etc/kubernetes/manifests/kube-controller-manager.yaml already exists
#	[ERROR FileAvailable--etc-kubernetes-manifests-kube-scheduler.yaml]: /etc/kubernetes/manifests/kube-scheduler.yaml already exists
#	[ERROR FileAvailable--etc-kubernetes-manifests-etcd.yaml]: /etc/kubernetes/manifests/etcd.yaml already exists
#	[ERROR Port-10250]: Port 10250 is in use
#	[ERROR Port-2379]: Port 2379 is in use
#	[ERROR Port-2380]: Port 2380 is in use
#	[ERROR DirAvailable--var-lib-etcd]: /var/lib/etcd is not empty
#[preflight] If you know what you are doing, you can make a check non-fatal with `--ignore-preflight-errors=...`
#To see the stack trace of this error execute with --v=5 or higher

printf "\n\n=====vvv\n\n"
echo $res;
printf "\n\n=====^^^\n\n"

ports=$(echo $res | egrep "firewalld is active, please ensure ports \[[0-9 ]+\] are open " | egrep -oh "(\[[0-9 ]+\])" | egrep -oh "[0-9 ]+")
portsarray=($ports)

printf "\n\n=====vvv\n\n"
 echo ${portsarray}
printf "\n\n=====^^^\n\n"

# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#check-required-ports
if (( ${#portsarray[@]} )); then
    for i in "${portsarray[@]}"
    do
    echo "Opening port $i"
    firewall-cmd --zone=public --add-port=$i/tcp --permanent

    done

    sudo firewall-cmd --reload
fi;



# echo "Applying CNI"
# kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/canal.yaml


# some clue:
  # https://github.com/ubuntu/microk8s/issues/536#issuecomment-509663386
