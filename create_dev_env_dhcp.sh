#!/bin/bash

# Constants
STORAGE="local-lvm" # Storage location (update if needed)
DISK=5             # Disk size in GB
CPU=1               # Number of CPU cores
MEMORY=1024         # Memory size in MB
NAMESERVER="8.8.8.8" # Public DNS
PASSWORD="admin123"  # Default root password (updated to meet requirements)
TEMPLATE_NAME="debian-12-standard_12.7-1_amd64.tar.zst"
TEMPLATE_PATH="/var/lib/vz/template/cache/$TEMPLATE_NAME"
TEMPLATE_URL="https://download.proxmox.com/images/system/$TEMPLATE_NAME"

# Check if template exists or download it
if [ ! -f "$TEMPLATE_PATH" ]; then
  echo "Template $TEMPLATE_NAME not found. Downloading..."
  wget -O "$TEMPLATE_PATH" "$TEMPLATE_URL"
  if [ $? -ne 0 ]; then
    echo "Failed to download template. Exiting."
    exit 1
  fi
else
  echo "Template $TEMPLATE_NAME found."
fi

# Prompt for hostname
read -p "Enter a hostname for the container: " HOSTNAME

# Automatically generate CTID
CTID=$(pvesh get /cluster/nextid)
echo "Using CTID: $CTID"

# Create the container
echo "Creating LXC container (CTID: $CTID)..."
pct create $CTID local:vztmpl/$TEMPLATE_NAME \
  --hostname $HOSTNAME \
  --password $PASSWORD \
  --storage $STORAGE \
  --rootfs ${STORAGE}:${DISK}G \
  --cores $CPU \
  --memory $MEMORY \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --nameserver $NAMESERVER \
  --unprivileged 1 \
  --features nesting=1

# Check if container creation was successful
if [ $? -ne 0 ]; then
  echo "Failed to create the container. Please check the error messages above."
  exit 1
fi

# Start the container
echo "Starting the container..."
pct start $CTID

# Install software in the container
echo "Installing software..."
pct exec $CTID -- bash -c "
  apt-get update &&
  apt-get install -y curl wget nano sudo gnupg nodejs npm mariadb-server php filebrowser &&
  npm install -g npm
"

# Configure File Browser
echo "Configuring File Browser..."
pct exec $CTID -- bash -c "
  filebrowser config set --address 0.0.0.0 --port 8080 --root /root &&
  filebrowser users add admin admin123 --perm.admin
"

# Configure MariaDB
echo "Securing MariaDB..."
pct exec $CTID -- bash -c "
  mysql -e \"UPDATE mysql.user SET Password=PASSWORD('admin123') WHERE User='root';\" &&
  mysql -e \"FLUSH PRIVILEGES;\"
"

# Configure firewall rules for security
echo "Configuring firewall..."
pct set $CTID --features nesting=1 --net0 name=eth0,bridge=vmbr0,firewall=1
cat <<EOF | pvesh set /nodes/$(hostname)/lxc/$CTID/firewall/rules --json -f
[
  {
    "type": "in",
    "action": "ACCEPT",
    "proto": "tcp",
    "dport": "80,443,8080"
  }
]
EOF

# Display access information
echo -e "\nContainer created successfully!"
echo "Access information:"
echo "  File Browser: http://<container-IP>:8080"
echo "    Username: admin"
echo "    Password: admin123"
echo "  MariaDB:"
echo "    Root Password: admin123"
echo "  Node.js: Installed (npm updated)"
echo "  PHP: Installed"
echo -e "\nReplace <container-IP> with the IP assigned to the container (check 'pct list' for details)."
