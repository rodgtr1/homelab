Full video tutorial and walkthrough of these scripts can be found in the Homelab Course in the [Travis Media Community](https://www.skool.com/travis-media-community).

# Raspberry Pi Pre-setup
When you install Ubuntu server on a Raspberry Pi, the eth0 network interface is DOWN. This script brings it up, assigns it an IP address, and then continues to set up a static IP via Netplan. This also includes prioritizing eth0 over wlan0 as well as setting a custom DNS server (in my case, my PiHole server).

### Instructions:
1. Create the script file and paste in the pi-presetup.sh contents.
2. Set the nameserver, default gateway, wireless SSID, and wireless password variables. 
3. Make the script executable `sudo chmod +x pi-presetup.sh`
4. Run the script on all Raspberry pi servers `./pi-presetup.sh`

# Installing Kubernetes via Kubeadm with scripts
Kubeadm is a tool for installing Kubernetes. It can be tedious to work through the documentation and run all the commands manually. I have created two scripts, one to run on the controlplane server and another to run on the worker servers. 

### Instructions for the controlplane server:
1. Create the script file and paste in the kubeadm-install-controlplane.sh content. 
2. There is a Network plugin option variable at the top to set either Flannel or Calico as the pod networking solution. Flannel is basic, Calico will give you more features. Choose an option AND be sure to also update your Pod CIDR range for that option. 
3. Make the script executable `sudo chmod +x kubeadm-install-controlplane.sh`
4. Run the script on the controlplane server.
5. Copy the kubeadm join command that is output at the end. You will need to run this on the worker nodes to join the cluster. 

### Instructions for the worker servers:
1. Create the script file and paste in the kubeadm-install-worker.sh content. 
2. Make the script executable `sudo chmod +x kubeadm-install-worker.sh`
3. Run the script on a worker server.
4. When this is complete. You can manually enter the kubeadm join command that copied from the controlplane (remember to run with sudo) to join this worker to the cluster. 
5. Repeat for all worker nodes.  