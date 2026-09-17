#!/bin/bash
set -e

dnf update -y
dnf install -y git python3 python3-pip

cd /home/ec2-user
git clone https://github.com/Ankur037/terraform-aws-flask-express.git
cd terraform-aws-flask-express/app/backend

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
nohup python app.py > /home/ec2-user/backend.log 2>&1 &
deactivate

echo "Backend setup complete" > /home/ec2-user/setup-done.txt
