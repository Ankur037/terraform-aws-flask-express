# Terraform AWS Deployment — Flask Backend + Express Frontend

A Feedback App (Express frontend + Flask backend) deployed to AWS in three progressively more advanced configurations, each fully provisioned with Terraform.

## Architecture Overview

| Part | Infrastructure | What it demonstrates |
|---|---|---|
| 1 | Single EC2 instance | Basic provisioning + `user_data` bootstrapping |
| 2 | Two EC2 instances | Multi-resource orchestration, `templatefile()`, cross-instance networking |
| 3 | ECR + ECS Fargate + VPC + ALB | Full containerized, load-balanced, production-shaped deployment |

All three parts deploy the same application: a simple feedback form (Name, Message) submitted from the Express frontend to a Flask REST API backend.

## Repository Structure

```
terraform-aws-flask-express/
├── app/
│   ├── backend/          Flask API (app.py, requirements.txt, Dockerfile)
│   └── frontend/         Express server + form (server.js, package.json, Dockerfile, public/index.html)
├── terraform/
│   ├── part1-single-ec2/         Single EC2, both apps on one instance
│   ├── part2-separate-ec2/       Two EC2 instances, cross-instance networking
│   └── part3-ecs-ecr-vpc-alb/    ECR + ECS Fargate + VPC + ALB, S3 remote state
└── README.md
```

## The Application

- **Backend** (`POST /feedback`, `GET /feedback`) — Flask + flask-cors, stores feedback in memory.
- **Frontend** (`GET /`, `POST /submit`, `GET /list`) — Express + axios, serves the form and forwards submissions to the backend via the `BACKEND_URL` environment variable, which differs per deployment (localhost → instance IP → ALB DNS name).

---

## Part 1: Single EC2 Instance

**Path:** `terraform/part1-single-ec2/`

Provisions one EC2 instance (Amazon Linux 2023, t3.micro) with a security group opening ports 22, 3000, and 5000. A `user_data` shell script runs automatically on first boot: installs Python and Node.js, clones this repository, sets up a Python venv for the backend, runs `npm install` for the frontend, and starts both apps as background processes with `nohup`.

**Files:** `main.tf`, `variables.tf`, `outputs.tf`, `user-data.sh`, `terraform-key`/`terraform-key.pub` (generated locally, gitignored)

**Run it:**
```bash
cd terraform/part1-single-ec2
ssh-keygen -t rsa -b 2048 -f terraform-key -N ""
terraform init
terraform plan
terraform apply
```

**Outputs:** `instance_public_ip`, `frontend_url`, `backend_url`

**Verified:** EC2 instance provisioned, both apps auto-started via `user_data`, feedback submitted through the frontend and confirmed round-tripping through the backend — all without any manual SSH setup.

---

## Part 2: Separate EC2 Instances

**Path:** `terraform/part2-separate-ec2/`

Provisions two EC2 instances — one for the Flask backend, one for the Express frontend — each with its own security group (backend: 22 + 5000; frontend: 22 + 3000). The backend is created first; its public IP is then injected into the frontend's `user_data` script using Terraform's `templatefile()` function, so the frontend knows where to reach the backend at boot time, with no manual configuration step.

**Files:** `main.tf`, `variables.tf`, `outputs.tf`, `user-data-backend.sh`, `user-data-frontend.sh.tpl`

**Key mechanic:**
```hcl
user_data = templatefile("${path.module}/user-data-frontend.sh.tpl", {
  backend_ip = aws_instance.backend.public_ip
})
```

**Run it:**
```bash
cd terraform/part2-separate-ec2
ssh-keygen -t rsa -b 2048 -f terraform-key -N ""
terraform init
terraform plan
terraform apply
```

**Outputs:** `backend_public_ip`, `frontend_public_ip`, `frontend_url`, `backend_url`

**Verified:** both instances provisioned, frontend on one machine successfully forwarded a form submission over the public internet to the backend on a separate machine, confirmed via the `/list` view.

---

## Part 3: ECR + ECS Fargate + VPC + ALB

**Path:** `terraform/part3-ecs-ecr-vpc-alb/`

The full containerized deployment: a custom VPC with two public subnets across two Availability Zones, two ECR repositories, an ECS cluster running both services on Fargate (no EC2 instances to manage), and an Application Load Balancer routing traffic to each service on its respective port.

**Files:** `backend.tf` (S3 state config), `providers.tf`, `variables.tf`, `vpc.tf`, `security_groups.tf`, `ecr.tf`, `iam.tf`, `ecs.tf`, `alb.tf`, `outputs.tf`

### Networking
- 1 VPC (`10.0.0.0/16`), 2 public subnets across 2 AZs, 1 Internet Gateway, 1 public route table
- **ALB security group**: accepts inbound 3000/5000 from the internet
- **ECS security group**: only accepts traffic *from the ALB's security group* (plus self-referencing rules for inter-task communication) — nothing reaches the containers directly

### Containers
- Both Docker images built locally and pushed to their ECR repositories (`flask-backend-tf`, `express-frontend-tf`)
- Two ECS task definitions (Fargate, 0.5 vCPU / 1GB each), each with CloudWatch log groups
- The frontend task's `BACKEND_URL` environment variable points at `http://<alb-dns-name>:5000` — traffic to the backend flows *through* the load balancer rather than directly to a task, so the backend can scale to multiple tasks later with zero frontend reconfiguration

### Load Balancer
- One ALB serving both tiers: listener on port 3000 → frontend target group; listener on port 5000 → backend target group
- Health checks on `/` for both target groups

**Run it:**
```bash
# One-time: create the S3 bucket for remote state (chicken-and-egg — can't be created by the config that uses it)
aws s3api create-bucket --bucket <your-unique-bucket-name> --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1
aws s3api put-bucket-versioning --bucket <your-unique-bucket-name> --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket <your-unique-bucket-name> \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

cd terraform/part3-ecs-ecr-vpc-alb
terraform init
terraform plan
terraform apply

# Build and push images (after ECR repos exist)
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-south-1.amazonaws.com

cd ../../app/backend
docker build -t flask-backend-tf .
docker tag flask-backend-tf:latest <account-id>.dkr.ecr.ap-south-1.amazonaws.com/flask-backend-tf:latest
docker push <account-id>.dkr.ecr.ap-south-1.amazonaws.com/flask-backend-tf:latest

cd ../frontend
docker build -t express-frontend-tf .
docker tag express-frontend-tf:latest <account-id>.dkr.ecr.ap-south-1.amazonaws.com/express-frontend-tf:latest
docker push <account-id>.dkr.ecr.ap-south-1.amazonaws.com/express-frontend-tf:latest
```

**Outputs:** `vpc_id`, `public_subnet_ids`, `ecr_backend_repository_url`, `ecr_frontend_repository_url`, `alb_dns_name`, `frontend_url`, `backend_url`

**Verified:** target group reported `"State": "healthy"` for the backend task; requests through the ALB on both ports returned correct responses; a feedback item submitted via `curl` through the ALB's frontend port was confirmed present in the `/list` view — proving the full path: client → ALB → frontend Fargate task → ALB → backend Fargate task.

---

## Terraform State Management

Part 3 uses an **S3 backend** for remote state (`backend.tf`), satisfying the assignment's state-management requirement. The bucket has versioning enabled (recoverable state history) and public access fully blocked (state files can contain sensitive values). Parts 1 and 2 use local state, since they're simpler, single-apply learning exercises — only Part 3's more complex, multi-layer infrastructure benefits from remote state's locking and durability.

## Cost Control

Every part was verified working, then torn down immediately with `terraform destroy` to avoid ongoing charges — EC2 instances, the ALB, and Fargate tasks all bill continuously while running. ECR repositories and their images were left in place (storage cost is negligible) so images don't need rebuilding if re-verification is needed.

## Security Notes

- SSH key pairs (`terraform-key`, `terraform-key.pub`) are generated locally per-part and excluded from git via `.gitignore` — only the public key is ever used by Terraform/AWS.
- `.gitignore` also excludes `.terraform/`, `*.tfstate*`, and `*.tfvars` — Terraform state and variable files are never committed.
- The ECS security group only accepts traffic from the ALB's security group, not directly from the internet — the load balancer is the sole entry point to the containers.
