#!/bin/bash

# Constants
STORAGE="local-lvm"
DISK=5
CPU=1
MEMORY=1024
NAMESERVER="8.8.8.8"
PASSWORD="admin123"
TEMPLATE_NAME="debian-12-standard_12.7-1_amd64.tar.zst"

# Prompt for hostname
read -p "Enter a hostname for the container: " HOSTNAME

# Automatically generate CTID
CTID=$(pvesh get /cluster/nextid)
echo "Using CTID: $CTID"

# Construct the pct create command
PCT_COMMAND="pct create $CTID local:vztmpl/$TEMPLATE_NAME \
  --hostname $HOSTNAME \
  --password $PASSWORD \
  --storage $STORAGE \
  --rootfs ${STORAGE}:${DISK}G \
  --cores $CPU \
  --memory $MEMORY \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --nameserver $NAMESERVER \
  --unprivileged 1 \
  --features nesting=1"

# Print and run the command
echo "Running command: $PCT_COMMAND"
eval $PCT_COMMAND

# Check if container creation was successful
if [ $? -ne 0 ]; then
  echo "Failed to create the container. Please check the error messages above."
  exit 1
fi

# Continue with starting and configuring the container...
