#!/bin/bash

# Define variables
RPI_USER="peter"         # Raspberry Pi username
RPI_HOST="peterpi.local"  # Raspberry Pi hostname or IP address
RPI_PATH="/home/peter/steam-idler/"  # Path on Raspberry Pi to deploy the project
LOCAL_PATH=$(pwd)         # Current directory (assuming deploy.sh is in the project root)

# Build the project (if necessary)
echo "Preparing Node.js project..."

# Create a tarball of the project, excluding sensitive files
echo "Creating tarball of the project..."
tar czf project.tar.gz -C "$LOCAL_PATH" . --exclude='.git' --exclude='.gitignore' --exclude='node_modules'

# Check if tarball was created successfully
if [ ! -f project.tar.gz ]; then
    echo "Error: Failed to create tarball."
    exit 1
fi

# Connect to Raspberry Pi and deploy
echo "Connecting to Raspberry Pi..."

# Add Raspberry Pi host to known_hosts to avoid SSH host key verification issues
ssh-keyscan -H $RPI_HOST >> ~/.ssh/known_hosts

# Clean up existing files, keeping only .env
ssh $RPI_USER@$RPI_HOST << EOF
    # Change to the deployment directory
    cd $RPI_PATH || { echo "Failed to cd into $RPI_PATH"; exit 1; }

    # Clean up existing files and directories
    echo "Cleaning up existing files and directories..."
    rm -rf *

    # Ensure no tarball exists before copying
    if [ -f project.tar.gz ]; then
        echo "Removing old tarball..."
        rm project.tar.gz
    fi

    # Exit SSH session
EOF

# Copy the tarball to the Raspberry Pi
echo "Copying tarball to Raspberry Pi..."
scp project.tar.gz $RPI_USER@$RPI_HOST:$RPI_PATH

# Connect again to perform the extraction and setup
ssh $RPI_USER@$RPI_HOST << EOF
    # Change to the deployment directory
    cd $RPI_PATH || { echo "Failed to cd into $RPI_PATH"; exit 1; }

    # Extract the tarball
    echo "Extracting tarball..."
    tar xzf project.tar.gz
    rm project.tar.gz

    # Update package list and install Node.js if not installed
    echo "Checking and installing Node.js if needed..."
    if ! command -v node &> /dev/null; then
        echo "Node.js not found, installing..."
        curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    # Install PM2 globally if not installed
    echo "Checking and installing PM2 if needed..."
    if ! command -v pm2 &> /dev/null; then
        echo "PM2 not found, installing..."
        sudo npm install -g pm2
    fi

    # Install Node.js dependencies
    if [ -f package.json ]; then
        echo "Installing Node.js dependencies..."
        npm install
    else
        echo "Error: package.json not found."
        exit 1
    fi

    # Run build command if needed
    if [ -f build.sh ]; then
        echo "Running build script..."
        ./build.sh
    fi

    # Start the Node.js script using PM2
    echo "Starting Node.js application with PM2..."
    pm2 start src/index.js --name steam-idler

    # Save PM2 process list and set up PM2 to restart on reboot
    echo "Saving PM2 process list and setting up PM2 to restart on reboot..."
    pm2 save
    pm2 startup

    # Enable PM2 service to start on boot
    sudo pm2 startup systemd -u $RPI_USER --hp /home/$RPI_USER

    # Optional: Check PM2 status
    pm2 ls
EOF

# Clean up local tarball
echo "Cleaning up local tarball..."
rm project.tar.gz

echo "Deployment completed!"
