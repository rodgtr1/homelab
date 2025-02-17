#!/bin/bash

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

echo "To finalize, run the kubeadm join command from the control plane here:"
echo "Example: kubeadm join <control-plane-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>"
