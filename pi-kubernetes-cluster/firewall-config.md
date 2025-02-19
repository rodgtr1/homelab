When we installed Kubernetes via Kubeadm, we disabled the firewall. 

Now that we have Kubernetes installed and running we want to enable this again and open up specific ports required of Kubernetes. 

We'll also need to open up ports as we install applications. This page will be a reference.

# Helpful commands
```bash
# Listing all rules, numbered
sudo ufw status numbered

# Deleting rule by number
sudo ufw delete number
```

# After installing Kubernetes

### Master node
```bash
# First, ensure UFW is installed
sudo apt install ufw

# Enable UFW
sudo ufw enable

# Allow SSH (important to do this first so you don't lock yourself out)
sudo ufw allow 22/tcp

# Control plane ports
sudo ufw allow 6443/tcp        # Kubernetes API server
sudo ufw allow 2379:2380/tcp   # etcd server client API
sudo ufw allow 10250/tcp       # Kubelet API
sudo ufw allow 10259/tcp       # kube-scheduler
sudo ufw allow 10257/tcp       # kube-controller-manager

# CNI (Flannel) related
sudo ufw allow 8472/udp
sudo ufw allow from WORKER_IP proto esp to MASTER_IP # change to your worker and master node IPs
```

### Worker node(s)
```bash
# First, ensure UFW is installed
sudo apt install ufw

# Enable UFW
sudo ufw enable

# Allow SSH
sudo ufw allow 22/tcp

# Worker node ports
sudo ufw allow 10250/tcp       # Kubelet API
sudo ufw allow 30000:32767/tcp # NodePort Services range

# CNI (Flannel) related
sudo ufw allow 8472/udp
sudo ufw allow from MASTER_IP proto esp to WORKER_IP # change to your worker and master node IPs
```