#!/bin/bash

# Set your AWS key pair name
KEY_PAIR_NAME="musicApp"

# Create a new EC2 instance
INSTANCE_ID=$(aws ec2 run-instances --image-id ami-06e46074ae430fba6 --count 1 --instance-type t2.micro --key-name $KEY_PAIR_NAME --query 'Instances[0].InstanceId' --output text)
echo $INSTANCE_ID
sleep 5
# Get the instance's public IP address
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo $PUBLIC_IP
# Wait for the instance to start
echo "Waiting for instance to start..."
aws ec2 wait instance-status-ok --instance-ids $INSTANCE_ID
sleep 30

# Set up the instance
ssh -o "StrictHostKeyChecking no" -i /Users/kartikkumar/Downloads/cc-a2/musicApp.pem ec2-user@$PUBLIC_IP 'bash -s' <<-'ENDSSH'
    # Update packages
    sudo yum update -y

    # Install Nginx
    sudo amazon-linux-extras install nginx1.12 -y

    # Start and enable Nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx
ENDSSH

# Transfer the React app build directory to the instance
scp -i /Users/kartikkumar/Downloads/cc-a2/musicApp.pem -r ./build ec2-user@$PUBLIC_IP:/home/ec2-user/

# Configure Nginx on the instance to serve the React app
ssh -i /Users/kartikkumar/Downloads/cc-a2/musicApp.pem ec2-user@$PUBLIC_IP 'bash -s' <<-'ENDSSH'
    # Remove the default Nginx configuration
    sudo rm /etc/nginx/conf.d/default.conf

    # Create a new Nginx configuration file
    sudo bash -c 'cat > /etc/nginx/conf.d/react-app.conf' <<-'EOF'
    server {
        listen 80;
        server_name localhost;
        root /home/ec2-user/build;

        location / {
            try_files $uri /index.html;
        }
    }
    EOF

    # Reload Nginx
    sudo systemctl reload nginx
ENDSSH

echo "React app deployed at: http://$PUBLIC_IP"
