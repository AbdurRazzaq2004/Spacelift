# Spacelift Demo: Terraform + Ansible Stack

This repository demonstrates how to use **Spacelift** to manage infrastructure with **Terraform** and configure servers with **Ansible**.

## What This Demo Does

1. **Terraform Stack** creates AWS EC2 instances (Ubuntu) with a security group allowing SSH and HTTP.
2. **Ansible Stack** installs nginx and htop on those instances.

## Repository Structure

```
tf-ansible-stack-dependencies/
├── tf/                     # Terraform code (creates EC2 instances)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
└── ansible/                # Ansible playbooks (configures instances)
    ├── install_nginx.yaml
    └── install_htop.yaml
```

---

## Step-by-Step Spacelift Demo Setup

### Prerequisites

- A Spacelift account ([spacelift.io](https://spacelift.io))
- AWS credentials (Access Key ID and Secret Access Key)
- An SSH key pair for accessing EC2 instances:
  - **Option 1:** Use an existing SSH public key (you'll paste its contents into Spacelift)
  - **Option 2:** Generate a new key pair directly in Spacelift hooks (shown below)
  - Note: Terraform will upload the public key to AWS, and Ansible will use the private key to SSH
- This repository connected to Spacelift

---

### Step 1: Create the Terraform Stack in Spacelift

1. **Log in to Spacelift** and click **"Create Stack"**

2. **Configure the stack:**
   - **Name:** `terraform-ec2-stack` (or any name you prefer)
   - **Repository:** Select this repository (`spacelift-demo`)
   - **Branch:** `main` (or your default branch)
   - **Project root:** `tf-ansible-stack-dependencies/tf`
   - **Backend:** Spacelift-managed (default) or use your own S3 backend

3. **Set Environment Variables** (in the stack's Environment tab):
   - `AWS_ACCESS_KEY_ID` → **secret** (your AWS access key)
   - `AWS_SECRET_ACCESS_KEY` → **secret** (your AWS secret key)

4. **Set Terraform Variables** (in the stack's Environment tab):
   - `public_key` → path where your public key will be (e.g., `/mnt/workspace/id_rsa.pub`)
   - `aws_region` → `eu-west-1` (or your preferred region)
   - `instance_count` → `3` (number of instances to create)
   - `instance_type` → `t3.micro`
   - `instances_prefix` → `demo`

5. **Add a Before Init Hook** (to provide your SSH key to the worker):

   **Option A - Use an existing key (recommended for production):**
   - Go to **Hooks** → **Before init**
   - Add this script:
   ```bash
   # Write your public key (store the actual key content as a Spacelift secret: PUBLIC_KEY)
   echo "$PUBLIC_KEY" > /mnt/workspace/id_rsa.pub
   
   # Write your private key (store as a Spacelift secret: PRIVATE_KEY)
   echo "$PRIVATE_KEY" > /root/.ssh/id_rsa
   chmod 600 /root/.ssh/id_rsa
   ```
   - Then add two **mounted files** or **environment secrets**:
     - `PUBLIC_KEY` = your public key contents (e.g., `ssh-rsa AAAAB3NzaC1...`)
     - `PRIVATE_KEY` = your private key contents (entire file including `-----BEGIN OPENSSH PRIVATE KEY-----`)

   **Option B - Generate a new key pair in Spacelift (easier for demos):**
   - Go to **Hooks** → **Before init**
   - Add this script:
   ```bash
   # Generate a new SSH key pair (this happens fresh on every run)
   ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -N ""
   
   # Copy public key to where Terraform expects it
   cp /root/.ssh/id_rsa.pub /mnt/workspace/id_rsa.pub
   
   echo "✅ SSH key pair generated for this run"
   ```
   - ⚠️ Note: This generates a NEW key on every run. You won't be able to SSH to instances from your laptop with this approach (only Ansible within Spacelift can connect).

6. **Save the stack**

---

### Step 2: Run the Terraform Stack

1. **Trigger a run:** Click **"Trigger"** on your Terraform stack
2. **Review the plan:** Spacelift will show you what Terraform will create (3 EC2 instances, 1 security group, 1 key pair)
3. **Confirm/Apply:** Click **"Confirm"** to apply the changes
4. **Wait for completion:** Terraform will create the infrastructure
5. **Check outputs:** After apply completes, you'll see outputs like:
   - `aws_instances` (list of public IPs)
   - `instance_map` (instance names → IPs)
   - `first_instance_ip` (first instance IP for testing)

---

### Step 3: Create the Ansible Stack in Spacelift

1. **Create a new stack:** Click **"Create Stack"**

2. **Configure the stack:**
   - **Name:** `ansible-configuration-stack`
   - **Repository:** Same repository (`spacelift-demo`)
   - **Branch:** `main`
   - **Project root:** `tf-ansible-stack-dependencies/ansible`
   - **Vendor:** Select **"None"** (we'll use a custom runner)

3. **Set Environment Variables:**
   - `AWS_ACCESS_KEY_ID` → **secret** (same as Terraform stack)
   - `AWS_SECRET_ACCESS_KEY` → **secret** (same as Terraform stack)

4. **Add a Task (custom command)** to run Ansible:
   - Go to **Hooks** → **After apply** or create a **Task**
   - Add a script that:
     - Reads the Terraform outputs from the Terraform stack (using Spacelift API or stack dependencies)
     - Creates an Ansible inventory file
     - Runs the playbooks

   Example script:
   ```bash
   #!/bin/bash
   
   # Get the first instance IP from Terraform stack outputs
   # (You'll need to configure stack dependency or use Spacelift API)
   INSTANCE_IP="<IP_FROM_TERRAFORM_OUTPUT>"
   
   # Create inventory file
   cat > inventory.ini <<EOF
   [web]
   ${INSTANCE_IP} ansible_user=ubuntu
   EOF
   
   # Add your private key (store it as a secret)
   echo "$PRIVATE_KEY" > /root/.ssh/id_rsa
   chmod 600 /root/.ssh/id_rsa
   
   # Disable host key checking for demo
   export ANSIBLE_HOST_KEY_CHECKING=False
   
   # Run playbooks
   ansible-playbook -i inventory.ini install_nginx.yaml
   ansible-playbook -i inventory.ini install_htop.yaml
   ```

5. **Set Stack Dependency** (recommended):
   - In the Ansible stack settings, add the Terraform stack as a dependency
   - This allows you to read outputs from the Terraform stack automatically

---

### Step 4: Run the Ansible Stack

1. **Trigger the Ansible stack** (or it will auto-run if you configured stack dependencies)
2. **Review logs:** You'll see Ansible installing nginx and htop on the instances
3. **Verify:** Visit the instance IP in your browser (`http://<instance_ip>`) — you should see the nginx welcome page with the hostname

---

### Step 5: Verify Everything Works

1. **Get the instance IP** from the Terraform stack outputs
2. **Test nginx:** Open `http://<instance_ip>` in your browser
3. **SSH to instance** (optional):
   ```bash
   ssh -i ~/.ssh/id_rsa ubuntu@<instance_ip>
   htop  # Should be installed by Ansible
   ```

---

### Step 6: Clean Up (Destroy Resources)

1. **Go to the Terraform stack** in Spacelift
2. **Click "Destroy"** (three dots menu → Destroy)
3. **Confirm destruction**
4. **Wait for completion** — all EC2 instances and resources will be deleted

---

## Quick Reference: Variables You Need

| Variable | Type | Example | Where to Set |
|----------|------|---------|--------------|
| `AWS_ACCESS_KEY_ID` | Secret | `AKIA...` | Terraform & Ansible stack env vars |
| `AWS_SECRET_ACCESS_KEY` | Secret | `xyz123...` | Terraform & Ansible stack env vars |
| `public_key` | TF Variable | `/mnt/workspace/id_rsa.pub` | Terraform stack |
| `aws_region` | TF Variable | `eu-west-1` | Terraform stack |
| `instance_count` | TF Variable | `3` | Terraform stack |

---

## What You'll Learn

- ✅ How to create and configure Spacelift stacks
- ✅ How to set environment variables and secrets
- ✅ How to use Terraform with Spacelift
- ✅ How to run Ansible from Spacelift
- ✅ How to use stack dependencies and outputs
- ✅ How to manage infrastructure lifecycle (create → configure → destroy)

---

## Tips

- **Stack Dependencies:** Configure the Ansible stack to depend on the Terraform stack — Spacelift will automatically run Ansible after Terraform succeeds
- **Outputs:** Use `spacectl stack output` or the Spacelift API to read Terraform outputs in your Ansible scripts
- **Secrets:** Always use Spacelift secrets for AWS credentials and SSH keys — never commit them to Git

---

## Next Steps

- Add more instances by changing `instance_count` variable
- Create a policy to require manual approval before apply
- Add notifications (Slack, email) on stack runs
- Use Spacelift contexts to share variables across multiple stacks