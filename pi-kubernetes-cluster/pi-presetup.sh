#!/bin/bash

# Configuration variables
nameserver="192.168.1.86" # I'm using PiHole as a DNS server. Feel free to use 8.8.8.8 Google or 1.1.1.1 Cloudflare
default_gateway="192.168.1.1" # IP of your router
wifi_ssid="" # Your Wireless SSID
wifi_plain_password="" # Your Wireless Password

# Check eth0 status
eth0_status=$(ip addr show eth0 | grep "state" | awk '{print $9}')

if [ "$eth0_status" = "UP" ]; then
    echo "eth0 is UP"
elif [ "$eth0_status" = "DOWN" ]; then
    echo "eth0 is DOWN - attempting to bring it up..."
    sudo ip link set eth0 up
    
    # Verify the interface was brought up successfully
    sleep 7  # Give the interface time to come up
    new_status=$(ip addr show eth0 | grep "state" | awk '{print $9}')
    if [ "$new_status" = "UP" ]; then
        echo "Successfully brought eth0 UP"
    else
        echo "Failed to bring eth0 UP"
        exit 1
    fi
else
    echo "Could not determine eth0 status"
    exit 1
fi

# Install DHCP client
echo "Installing DHCP client..."
sudo apt update && sudo apt install isc-dhcp-client -y

if [ $? -ne 0 ]; then
    echo "Failed to install DHCP client"
    exit 1
fi

# Request IP address using DHCP
echo "Requesting IP address for eth0..."
sudo dhclient eth0

# Save the eth0 IPv4 address to a variable
eth0_ip=$(ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)

if [ -n "$eth0_ip" ]; then
    echo "Successfully obtained eth0 IP address: $eth0_ip"
else
    echo "Failed to obtain eth0 IP address"
    exit 1
fi

# Get wlan0 IPv4 address
wlan0_ip=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)

if [ -n "$wlan0_ip" ]; then
    echo "Found wlan0 IP address: $wlan0_ip"
else
    echo "No IP address found for wlan0"
fi

# Generate the encoded password using wpa_passphrase
wifi_encoded_password=$(wpa_passphrase "${wifi_ssid}" "${wifi_plain_password}" | grep "psk=" | grep -v "#" | cut -d= -f2)

echo "Encoded password: $wifi_encoded_password"

# Create new netplan configuration
cat << EOF | sudo tee /etc/netplan/50-cloud-init.yaml
network:
    version: 2
    ethernets:
      eth0:
        dhcp4: false
        dhcp6: false
        addresses:
        - ${eth0_ip}/24
        routes:
        - to: default
          via: ${default_gateway}
          metric: 100
        nameservers:
          addresses: [${nameserver}]
    wifis:
        renderer: networkd
        wlan0:
          dhcp4: false
          dhcp6: false
          addresses:
          - ${wlan0_ip}/24
          routes:
          - to: default
            via: ${default_gateway}
            metric: 200
          nameservers:
            addresses: [${nameserver}]
          access-points:
            ${wifi_ssid}:
              password: ${wifi_encoded_password}
          optional: true
EOF

# Apply the new configuration
sudo netplan apply

if [ $? -eq 0 ]; then
    echo "Successfully applied new network configuration"
else
    echo "Failed to apply network configuration"
    exit 1
fi

# Configure resolv.conf to use nameserver
echo "Configuring resolv.conf..."
# First remove immutable attribute if it exists
sudo chattr -i /etc/resolv.conf 2>/dev/null

# Remove symlink if it exists
sudo rm -f /etc/resolv.conf

# Create new resolv.conf
echo "nameserver ${nameserver}" | sudo tee /etc/resolv.conf

# Make it immutable (so Ubuntu won't overwrite)
sudo chattr +i /etc/resolv.conf

# Final reboot
echo "Rebooting system..."
sudo reboot now