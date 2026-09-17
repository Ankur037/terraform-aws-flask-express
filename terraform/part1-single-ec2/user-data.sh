#!/bin/bash
set -e

# Install dependencies
dnf update -y
dnf install -y git python3 python3-pip

# Install Node.js
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs

# Clone the app code
cd /home/ec2-user
git clone https://github.com/Ankur037/terraform-aws-flask-express.git
cd terraform-aws-flask-express

# Set up and start the Flask backend
cd app/backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
nohup python app.py > /home/ec2-user/backend.log 2>&1 &
deactivate

# Set up and start the Express frontend
cd ../frontend
npm install
BACKEND_URL=http://localhost:5000 nohup node server.js > /home/ec2-user/frontend.log 2>&1 &

echo "Setup complete" > /home/ec2-user/setup-done.txt
