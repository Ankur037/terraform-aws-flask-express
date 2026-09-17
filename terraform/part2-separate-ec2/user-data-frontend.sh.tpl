#!/bin/bash
set -e

dnf update -y
dnf install -y git

curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs

cd /home/ec2-user
git clone https://github.com/Ankur037/terraform-aws-flask-express.git
cd terraform-aws-flask-express/app/frontend

npm install
BACKEND_URL=http://${backend_ip}:5000 nohup node server.js > /home/ec2-user/frontend.log 2>&1 &

echo "Frontend setup complete" > /home/ec2-user/setup-done.txt
