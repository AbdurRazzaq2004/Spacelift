# Spacelift Demo: Orchestrating Terraform and Ansible

This is a complete, working demo that shows how to use Spacelift to orchestrate infrastructure creation with Terraform and configuration management with Ansible. The Terraform stack creates EC2 instances on AWS, and the Ansible stack automatically configures them by installing software.

## What This Demo Does

1. **Terraform Stack**: Creates 3 Ubuntu EC2 instances in AWS with SSH access configured
2. **Ansible Stack**: Automatically picks up the EC2 instance IPs and installs htop and nginx on all of them
3. **Automatic Integration**: The Ansible stack depends on the Terraform stack and receives the instance IPs automatically

## Prerequisites

Before you start, you need:

1. A GitHub account
2. A Spacelift account (you can sign up for free at spacelift.io)
3. An AWS account with credentials (Access Key ID and Secret Access Key)
4. Basic understanding of Terraform and Ansible (helpful but not required)

## Step 1: Fork This Repository

Go to the top right corner of this repository page on GitHub and click the "Fork" button. This creates your own copy of the repository that you can connect to Spacelift.

## Step 2: Connect GitHub to Spacelift

1. Log into your Spacelift account
2. Go to Settings → Integrations
3. Click "Add Integration" and select GitHub
4. Follow the prompts to authorize Spacelift to access your GitHub account
5. Grant access to the repository you just forked

## Step 3: Generate SSH Keys

You need to generate an SSH key pair that will be used to connect to the EC2 instances. Open your terminal and run these commands:

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/spacelift_demo_rsa -N ""
```

This creates two files:
* `~/.ssh/spacelift_demo_rsa` (private key)
* `~/.ssh/spacelift_demo_rsa.pub` (public key)

Now we need to encode the private key in BASE64 format (this is important because it preserves the line breaks):

```bash
base64 -i ~/.ssh/spacelift_demo_rsa | tr -d '\n'
```

Copy the output. It will be a long string of random characters. Save this somewhere safe because you'll need it in the next step.

Also get your public key:

```bash
cat ~/.ssh/spacelift_demo_rsa.pub
```

Copy this output too. It should start with `ssh-rsa AAAA...`

## Step 4: Create a Context for SSH Keys

Contexts in Spacelift are like shared configuration that multiple stacks can use. We'll create one for our SSH keys.

1. In Spacelift, go to "Contexts" in the left sidebar
2. Click "Add Context"
3. Name it: `ssh-key`
4. Click "Create"
5. Now add two environment variables to this context:
   * Click "Add Environment Variable"
   * Name: `PUBLIC_KEY`
   * Value: Paste the public key you copied (the one starting with ssh-rsa)
   * Leave "Secret" unchecked
   * Click "Add Variable"
   
   * Click "Add Environment Variable" again
   * Name: `PRIVATE_KEY`
   * Value: Paste the BASE64 encoded private key you copied earlier (the long random string)
   * Check the "Secret" checkbox (this keeps it hidden)
   * Click "Add Variable"

6. Click "Save Changes"

## Step 5: Create the Terraform Stack

This stack will create the EC2 instances in AWS.

1. In Spacelift, click "Stacks" in the left sidebar
2. Click "Add Stack"
3. Choose your GitHub integration and select your forked repository
4. Configure the stack:
   * **Name**: `terraform` (you can name it anything, but this makes it clear)
   * **Project root**: `tf-ansible-stack-dependencies/tf`
   * **Runner image**: Leave as default
   * **Branch**: `main`
   * **Administrative**: Check this box (allows the stack to manage infrastructure)
5. Click "Create Stack"

### Add AWS Credentials to Terraform Stack

Now you need to tell Terraform how to connect to AWS:

1. Click on your new Terraform stack
2. Go to the "Environment" tab
3. Add these environment variables:
   * Name: `AWS_ACCESS_KEY_ID`, Value: Your AWS access key, Secret: Yes
   * Name: `AWS_SECRET_ACCESS_KEY`, Value: Your AWS secret key, Secret: Yes
   * Name: `AWS_REGION`, Value: `eu-west-1` (or your preferred region), Secret: No

### Attach the SSH Key Context

1. Still in your Terraform stack, go to the "Contexts" tab
2. Click "Attach Context"
3. Select the `ssh-key` context you created earlier
4. Click "Attach"

### Add Hooks to Write SSH Keys

Hooks are commands that run at specific points in the Spacelift workflow. We need hooks to write the SSH keys to files before Terraform runs.

1. Go to the "Hooks" tab in your Terraform stack
2. Click on "Planning" to expand it
3. Click "BEFORE" under Planning
4. Add these commands one by one (click "Add a command" after each):

```bash
mkdir -p /mnt/workspace
```

```bash
echo "$PUBLIC_KEY" > /mnt/workspace/id_rsa.pub
```

```bash
cat /mnt/workspace/id_rsa.pub
```

5. Click "Save changes"

### Run the Terraform Stack

1. Click the "Trigger" button in the top right
2. Select "Apply run"
3. Wait for the planning phase to complete
4. Review the plan (it should show 3 EC2 instances, 1 security group, and 1 key pair being created)
5. Click "Confirm" to apply the changes
6. Wait for the apply to complete (this takes a few minutes)

You should see output showing the IP addresses of your 3 new EC2 instances.

## Step 6: Create the Ansible Stack

This stack will configure the EC2 instances created by Terraform.

1. Go back to "Stacks" and click "Add Stack"
2. Choose your GitHub integration and repository
3. Configure the stack:
   * **Name**: `ansible`
   * **Project root**: `tf-ansible-stack-dependencies/ansible`
   * **Runner image**: Leave as default
   * **Branch**: `main`
   * **Stack type**: Change from "Terraform" to "Ansible"
   * **Playbook**: `install_htop.yaml`
4. Click "Create Stack"

### Add Dependency on Terraform Stack

This tells Ansible to wait for Terraform to finish and to receive its outputs:

1. In your Ansible stack, go to "Dependencies" tab
2. Click "Add Dependency"
3. Select your Terraform stack from the dropdown
4. Click "Add"

### Attach the SSH Key Context

1. Go to the "Contexts" tab
2. Click "Attach Context"
3. Select the `ssh-key` context
4. Click "Attach"

### Add Hooks for Planning Phase

These hooks prepare the SSH keys and inventory file for Ansible:

1. Go to the "Hooks" tab
2. Click on "Planning" to expand it
3. Click "BEFORE" under Planning
4. Add these 6 commands one by one:

```bash
mkdir -p /mnt/workspace/.ssh
```

```bash
echo "$PRIVATE_KEY" | base64 -d > /mnt/workspace/.ssh/id_rsa && chmod 600 /mnt/workspace/.ssh/id_rsa
```

```bash
export ANSIBLE_CONFIG=/mnt/workspace/source/tf-ansible-stack-dependencies/ansible/ansible.cfg
```

```bash
export ANSIBLE_PRIVATE_KEY_FILE=/mnt/workspace/.ssh/id_rsa
```

```bash
echo "[webservers]" > /mnt/workspace/inventory.ini && python3 -c "import json,os; [print(f'{ip} ansible_user=ubuntu') for ip in json.loads(os.environ.get('instance_ip','[]'))]" >> /mnt/workspace/inventory.ini
```

```bash
cat /mnt/workspace/inventory.ini
```

5. Click "Save changes"

### Add Hooks for Applying Phase

This is the critical part that we discovered during troubleshooting. The same hooks need to be added to the Applying phase:

1. Still in the "Hooks" tab
2. Click on "Applying" to expand it
3. Click "BEFORE" under Applying
4. Add the exact same 6 commands as above
5. Click "Save changes"

### Run the Ansible Stack

1. Click the "Trigger" button
2. Select "Apply run"
3. Wait for the planning phase (this tests the connection to all 3 EC2 instances)
4. If planning succeeds, click "Confirm"
5. Wait for the apply phase to complete

You should see Ansible successfully connect to all 3 instances and install htop and nginx.

## Verifying It Worked

To verify that everything worked:

1. Go to your AWS Console
2. Navigate to EC2 → Instances
3. Find your 3 instances (they'll have the name tag from your Terraform code)
4. Copy the public IP of one instance
5. SSH into it:
   ```bash
   ssh -i ~/.ssh/spacelift_demo_rsa ubuntu@<INSTANCE_IP>
   ```
6. Once connected, verify htop is installed:
   ```bash
   which htop
   htop --version
   ```

## Destroying Everything

When you're done testing and want to clean up all resources:

1. Go to your Terraform stack in Spacelift
2. Click the "Runs" tab
3. Click the "Trigger" button (top right)
4. Select "Destroy" from the dropdown
5. Review the destroy plan
6. Click "Confirm" to destroy all resources

This will delete all 3 EC2 instances, the security group, and the SSH key pair from AWS.

## Common Errors and Solutions

### Error 1: "Permissions 0777 for private key are too open"

**What happened**: The private key file doesn't have the correct permissions. SSH requires private keys to be readable only by the owner (chmod 600).

**Solution**: This is why we need hooks in BOTH the Planning phase AND the Applying phase. The Applying phase hooks recreate the key file with correct permissions before Ansible runs.

### Error 2: "Running 0 custom hooks" during apply

**What happened**: Hooks were only added to the "Performing" phase, but Spacelift doesn't execute hooks in that phase for Ansible stacks.

**Solution**: Add hooks to the "Applying" phase instead. This is the phase where Ansible actually runs the playbook.

### Error 3: "no such identity: /ansible/.ssh/id_rsa"

**What happened**: The SSH key file wasn't created before Ansible tried to use it.

**Solution**: Make sure the hooks are in the correct phase (Applying → BEFORE) and that the PRIVATE_KEY is properly BASE64 encoded in your context.

### Error 4: Private key showing as 1 line instead of 50+ lines

**What happened**: When you paste a multi-line private key directly into Spacelift, the newlines get lost.

**Solution**: Always BASE64 encode your private key before storing it in Spacelift. The hooks will decode it back to the proper format with `base64 -d`.

### Error 5: "error in libcrypto" when using ED25519 key

**What happened**: ED25519 keys must be named `id_ed25519`, not `id_rsa`. SSH is strict about key naming.

**Solution**: Use RSA keys instead, or make sure to name ED25519 keys correctly. This demo uses RSA keys to avoid this issue.

### Error 6: Ansible can't find ansible.cfg

**What happened**: Ansible ignores config files in world-writable directories (a security feature).

**Solution**: Use the `ANSIBLE_CONFIG` environment variable to explicitly point to the config file. This is set in the hooks.

## Important Things to Remember

1. **Always BASE64 encode private keys** before storing them in Spacelift contexts
2. **Add hooks to both Planning and Applying phases** for Ansible stacks
3. **The Performing phase hooks don't execute** for Ansible stacks (we learned this the hard way)
4. **Use RSA keys** to avoid naming complications with ED25519 keys
5. **Chmod 600 the private key** every time it's written to disk
6. **Dependencies matter** Make sure the Ansible stack depends on the Terraform stack
7. **Environment variables persist** between Planning and Applying phases, but file permissions don't

## What Each File Does

**tf-ansible-stack-dependencies/tf/main.tf**: Creates EC2 instances, security group, and SSH key pair in AWS

**tf-ansible-stack-dependencies/tf/outputs.tf**: Exports the instance IPs so Ansible can use them

**tf-ansible-stack-dependencies/ansible/install_htop.yaml**: Ansible playbook that installs htop and nginx

**tf-ansible-stack-dependencies/ansible/ansible.cfg**: Ansible configuration that tells it where to find the inventory and SSH settings

## Architecture Overview

Here's how everything connects:

1. You trigger the Terraform stack in Spacelift
2. Terraform Planning hooks write the public SSH key to a file
3. Terraform creates 3 EC2 instances in AWS with that public key
4. Terraform outputs the instance IPs
5. The Ansible stack sees the Terraform stack completed (dependency)
6. Ansible Planning hooks write the private key and create an inventory file with the IPs
7. Ansible plans the changes (test connection)
8. Ansible Applying hooks recreate the private key with correct permissions
9. Ansible applies the playbook and installs software on all instances

## Troubleshooting Tips

If something isn't working:

1. **Check the logs**: Spacelift shows detailed logs for every phase. Look for error messages.
2. **Verify contexts are attached**: Both stacks need the ssh-key context attached.
3. **Check hook output**: The `cat` commands in the hooks show you what files were created.
4. **Verify dependencies**: Make sure the Ansible stack has the Terraform stack as a dependency.
5. **Check AWS credentials**: Make sure your AWS keys are valid and have permission to create EC2 instances.
6. **Region matters**: Make sure the AWS region in your Terraform stack environment matches where you want to create resources.

## Getting Help

If you run into issues:

1. Check the Spacelift documentation: docs.spacelift.io
2. Look at the run logs in Spacelift for detailed error messages
3. Verify your AWS credentials have the necessary permissions
4. Make sure your GitHub repository is correctly connected to Spacelift

## Credits

This demo was created to show a complete working example of Spacelift orchestrating Terraform and Ansible together. It includes all the lessons learned from debugging various SSH key, permissions, and hook execution issues.

Happy automating!

Author
Abdur Razzaq ( DevOps Engineer )
