#!/bin/bash

# Pod CIDR for Flannel
POD_CIDR="10.244.0.0/16"

echo "Step 1: Disabling swap..."
sudo swapoff -a

# Check if swap is actually disabled
if [ "$(sudo swapon --show)" == "" ]; then
    echo "Verified: Swap is disabled"
else
    echo "Warning: Swap might still be active"
    exit 1
fi

echo -e "\nStep 2: Setting up kernel modules..."
# Configure kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

echo "Loading kernel modules..."
sudo modprobe overlay
sudo modprobe br_netfilter

# Verify modules are loaded
if ! lsmod | grep -q br_netfilter; then
    echo "Error: br_netfilter module not loaded"
    exit 1
else
    echo "Verified: br_netfilter module is loaded"
fi

if ! lsmod | grep -q overlay; then
    echo "Error: overlay module not loaded"
    exit 1
else
    echo "Verified: overlay module is loaded"
fi

echo -e "\nStep 3: Configuring sysctl parameters..."
# Configure sysctl parameters
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

echo "Applying sysctl parameters..."
sudo sysctl --system

# Verify IP forwarding is enabled
ip_forward=$(sudo sysctl -n net.ipv4.ip_forward)
if [ "$ip_forward" -eq 1 ]; then
    echo "Verified: IP forwarding is enabled (net.ipv4.ip_forward = $ip_forward)"
else
    echo "Error: IP forwarding is not enabled (net.ipv4.ip_forward = $ip_forward)"
    exit 1
fi

echo -e "\nStep 4: Installing containerd..."
# Update package list
echo "Updating package list..."
sudo apt-get update

# Install prerequisites
echo "Installing prerequisites..."
sudo apt-get install -y ca-certificates curl

# Set up Docker's apt repository
echo "Setting up Docker repository..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package list again after adding new repository
sudo apt-get update

# Install containerd
echo "Installing containerd..."
sudo apt-get install -y containerd.io

echo -e "\nStep 5: Configuring containerd..."
# Generate default config
echo "Generating default containerd configuration..."
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# Backup the original config
sudo cp /etc/containerd/config.toml /etc/containerd/config.toml.bak

# Update SystemdCgroup
echo "Setting SystemdCgroup to true..."
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Update sandbox_image
echo "Updating sandbox_image..."
sudo sed -i 's|sandbox_image = ".*"|sandbox_image = "registry.k8s.io/pause:3.10"|' /etc/containerd/config.toml

# Verify the changes
if ! sudo grep -q "SystemdCgroup = true" /etc/containerd/config.toml; then
    echo "Error: Failed to set SystemdCgroup to true"
    exit 1
fi

if ! sudo grep -q 'sandbox_image = "registry.k8s.io/pause:3.10"' /etc/containerd/config.toml; then
    echo "Error: Failed to update sandbox_image"
    exit 1
fi

# Restart containerd
echo "Restarting containerd..."
sudo systemctl restart containerd

# Verify containerd is running
if ! sudo systemctl is-active --quiet containerd; then
    echo "Error: containerd failed to start with new configuration"
    exit 1
else
    echo "Verified: containerd is running with new configuration"
fi

echo -e "\nStep 6: Installing Kubernetes components..."
# Install required packages
echo "Installing prerequisites..."
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Set up Kubernetes repository
echo "Setting up Kubernetes repository..."
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes repository
echo "Adding Kubernetes repository to sources..."
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update package list
sudo apt-get update

# Install Kubernetes components
echo "Installing kubelet, kubeadm, and kubectl..."
sudo apt-get install -y kubelet kubeadm kubectl

# Mark packages to prevent automatic updates
echo "Marking Kubernetes packages to prevent automatic updates..."
sudo apt-mark hold kubelet kubeadm kubectl

# Verify installations
echo "Verifying Kubernetes component installations..."
if ! kubectl version --client; then
    echo "Error: kubectl not properly installed"
    exit 1
fi

if ! sudo kubeadm version; then
    echo "Error: kubeadm not properly installed"
    exit 1
fi

echo -e "\nStep 7: Initializing control plane node..."
# Get eth0 IP address
CONTROL_PLANE_IP=$(ip -f inet addr show eth0 | grep -Po 'inet \K[\d.]+' | cut -d'/' -f1)
if [ -z "$CONTROL_PLANE_IP" ]; then
    echo "Error: Could not detect eth0 IP address"
    exit 1
fi

echo "Detected control plane IP: $CONTROL_PLANE_IP"
echo "Using pod CIDR: $POD_CIDR"

# Initialize the control plane
sudo kubeadm init --apiserver-advertise-address="$CONTROL_PLANE_IP" --pod-network-cidr="$POD_CIDR" | tee kubeadm-init.out

if [ $? -ne 0 ]; then
    echo "Error: Control plane initialization failed"
    exit 1
fi

# Set up kubectl configuration
echo "Setting up kubectl configuration..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo -e "\nStep 8: Deploying Flannel network..."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

if [ $? -ne 0 ]; then
    echo "Error: Flannel deployment failed"
    exit 1
fi

echo -e "\nControl plane initialization completed successfully!"
echo "The kubeadm init output is saved to kubeadm-init.out"

# Extract and display the join command
echo -e "\nJoin command for worker nodes:"
echo "$(grep -A 2 'kubeadm join' kubeadm-init.out | sed -e 's/^[[:space:]]*//')"
echo -e "\nWe're done here. Run the join command on your worker nodes to join them to the cluster."