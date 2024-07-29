#!/bin/bash

# Define variables
RPI_USER="peter"         # Raspberry Pi username
RPI_HOST="peterpi.local"  # Raspberry Pi IP address (port 22 is default for SSH)
RPI_PATH="/home/peter/steam-idler/"  # Path on Raspberry Pi to deploy the project
LOCAL_PATH=$(pwd)         # Current directory (assuming deploy.sh is in the project root)

# Build the project (if necessary)
echo "Preparing Node.js project..."

# Create a tarball of the project excluding sensitive files
echo "Creating tarball of the project..."
tar czf project.tar.gz -C "$LOCAL_PATH" . --exclude='.git' --exclude='.env' --exclude='*.session' --exclude='*.session-journal'

# Check if tarball was created successfully
if [ ! -f project.tar.gz ]; then
    echo "Error: Failed to create tarball."
    exit 1
fi

# Create the deployment directory on Raspberry Pi
echo "Creating deployment directory on Raspberry Pi..."
ssh $RPI_USER@$RPI_HOST "mkdir -p $RPI_PATH"

# Copy the tarball to the Raspberry Pi
echo "Copying tarball to Raspberry Pi..."
scp project.tar.gz $RPI_USER@$RPI_HOST:$RPI_PATH

# Check if the tarball was successfully copied
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy tarball to Raspberry Pi."
    exit 1
fi

# Connect to Raspberry Pi and deploy
echo "Deploying on Raspberry Pi..."
ssh $RPI_USER@$RPI_HOST << 'EOF'
    # Change to the deployment directory
    cd /home/peter/steam-idler/ || { echo "Failed to cd into /home/peter/steam-idler/"; exit 1; }

    # List the current contents for verification
    echo "Current contents of /home/peter/steam-idler/:"
    ls -la

    # Clean up existing files
    echo "Cleaning up existing files..."
    find . -mindepth 1 -not -name 'project.tar.gz' -not -name '.env' -not -name '.gitignore' -exec rm -rf {} +

    # Extract the tarball and clean up
    if [ -f project.tar.gz ]; then
        echo "Extracting tarball..."
        tar xzf project.tar.gz
        rm project.tar.gz
    else
        echo "Error: Tarball not found."
        exit 1
    fi

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

    # Start the Node.js script using PM2
    echo "Starting Node.js application with PM2..."
    pm2 start src/index.js --name steam-idler

    # Save PM2 process list and set up PM2 to restart on reboot
    echo "Saving PM2 process list and setting up PM2 to restart on reboot..."
    pm2 save
    pm2 startup

    # Enable PM2 service to start on boot
    sudo pm2 startup systemd -u peter --hp /home/peter

    # Optional: Check PM2 status
    pm2 ls
EOF

# Clean up local tarball
echo "Cleaning up local tarball..."
rm project.tar.gz

echo "Deployment completed!"
