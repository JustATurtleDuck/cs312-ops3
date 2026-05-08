# Ops 3: Infrastructure Automation

Obsidian Dynamics acquired a three-person startup last quarter. Their "CTO" (who is also their intern) was given read access to the AWS account as part of onboarding. He deleted your Minecraft EC2 instance on his second day, thinking it was a test environment. It was not a test environment.

Rebuilding from your notes took most of a weekend. Leadership's takeaway was not "let's improve the onboarding process" but rather "we need an audit trail." Every layer of the stack must now be automated: Terraform or OpenTofu declares infrastructure, Ansible configures the host, and a CI/CD pipeline tests and publishes container images. Nothing is hand-configured. Everything is rebuildable.

## Learning Objectives

- Model cloud infrastructure with Terraform or OpenTofu.
- Automate server configuration with Ansible so that it is idempotent and repeatable.
- Automate image publishing with a CI/CD pipeline.
- Design for rebuildability and auditability.

## Constraints (AWS Academy)

- Use Terraform or OpenTofu for provisioning.
- Ansible is required for post-provision server configuration.
- CI/CD pipeline must use GitHub Actions.
- EC2 remains the compute target.
- Use the pre-existing `LabInstanceProfile` to grant the EC2 instance AWS permissions; in AWS Academy this profile contains `LabRole`. Do not place AWS access keys on the host.
- ECR remains the container registry for images.
- You must document how your state is handled.

## Requirements

### A. Provisioned Infrastructure (Terraform or OpenTofu)

Your Terraform or OpenTofu code must create (or explicitly and cleanly reference) the following:

- Networking placement for the instance and public entry point (VPC/subnet strategy must be stated; a direct public IP is acceptable, and a private subnet with a documented TCP-capable load balancer is also acceptable).
- Security Group rules: SSH for admin access and TCP 25565 for Minecraft clients at the appropriate public or internal boundary.
- EC2 instance configuration (AMI choice, instance type, storage choice).
- The pre-existing `LabInstanceProfile` attached to the EC2 instance, enabling it to pull from ECR and write world backups to S3 without credentials on disk.

### B. Configuration Management (Ansible)

An Ansible playbook configures the EC2 instance after Terraform provisions it.

- The playbook must:
  - Install runtime prerequisites (Docker, AWS CLI).
  - Authenticate to ECR using the instance profile credentials exposed on the host; in AWS Academy this comes from `LabInstanceProfile` / `LabRole`.
  - Pull the pinned Minecraft image version from ECR.
  - Mount the `/data` volume for persistent world data.
  - Restore world data from S3 into `/data` before starting the container when performing a rebuild or recovery.
  - Set required environment variables including `EULA=TRUE`.
  - Start the Minecraft server container.
- Cloud-init/user-data may handle initial bootstrap (e.g., installing Ansible, cloning the repo), but all server configuration must live in the Ansible playbook.
- The playbook must be idempotent: re-running it against the same host produces the same result without duplication or errors.

### C. Image Publishing Pipeline (CI/CD)

A GitHub Actions workflow automates image publishing to ECR.

- The workflow triggers when a git tag is pushed.
- The workflow must acquire the deployable image and publish it to ECR. Re-tagging a pinned upstream image is acceptable; building from a Dockerfile is also acceptable if you completed that extra credit in Assignment 2.
- The workflow must include a smoke test: run the image briefly and verify the Minecraft server initializes without errors.
- At least one successful pipeline run must be evidenced (link to the Actions tab or screenshot).

### D. Rebuild Proof

- Demonstrate that `terraform destroy` followed by `terraform apply` plus running the Ansible playbook produces a joinable Minecraft server.
- Document what happens to world data in your rebuild strategy: the playbook should restore the world from S3 before starting the server so that players return to the same world after a rebuild.
- Your rebuild evidence must make it clear whether the same world was restored or a fresh world was created.
- A full end-to-end restore does not need to be shown in video if time-constrained, but the strategy must be documented.

### E. Documentation

Your documentation must include:

- An architecture diagram showing AWS resources, Ansible configuration flow, and the CI/CD pipeline.
- Terraform inputs/variables and what they control.
- A change process: how a teammate would propose and review infrastructure changes.
- A teardown checklist to prevent runaway cost.

## Hints

These pointers cover Minecraft-specific integration points and AWS Academy constraints that are not covered in lectures or activities.

- **Chaining Terraform and Ansible**: Terraform can trigger your Ansible playbook automatically using a `null_resource` with a `local-exec` provisioner. This lets `terraform apply` provision and configure the host in one step. The provisioner runs the `ansible-playbook` command from your local machine, so SSH access and your inventory must be correct before wiring this up.
- **Minecraft EULA and startup environment**: The Minecraft Docker image will exit immediately without starting if `EULA=TRUE` is not set. Pass this via the `environment` key in your Ansible Docker task alongside any memory settings (`JVM_OPTS`, `MEMORY`).
- **Smoke test startup latency**: Minecraft takes 30 to 60 seconds to finish loading. A smoke test that checks for `"Done"` in `docker logs` immediately after `docker run` will always fail. Use a polling loop with a short sleep (e.g., `for i in $(seq 1 12); do sleep 10 && docker logs ...; done`) or the container's `--health-*` flags to wait for the server to be ready.
- **World data volume**: The `itzg/minecraft-server` image stores all world data under `/data` inside the container. Mount a named volume or host directory to `/data` in your Ansible task. Your S3 restore step must populate that path before the server starts, or the server will generate a fresh world on every rebuild.
- **AWS Academy credentials in GitHub Actions**: Academy credentials include `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN`. All three must be stored as GitHub Actions secrets and all three must be passed to `aws-actions/configure-aws-credentials`. These credentials are temporary and should be refreshed each time your Learner Lab session restarts or ends.

## What You'll Submit

1. **PDF** containing: brief design note, architecture diagram, Terraform variables documentation, change process, teardown checklist, world-data recovery strategy, and a link to your GitHub repository with all Terraform, Ansible, and GitHub Actions code.
2. **Narrated screen recording (max 3 minutes)**. Your server MOTD must include your name or student ID. **Submit timestamps alongside the video** (e.g., "Checkpoint 1: 0:00, Checkpoint 2: 0:38, ..."):
1. Show `terraform apply` output with new resources created, then the Ansible playbook running against the provisioned instance, and confirm the Minecraft server is running after the playbook completes.
2. Run `nmap -sV -Pn -p T:25565 <public-endpoint>` against the Terraform/Ansible-provisioned service to show 25565/tcp open and display your custom MOTD.
3. Show a successful GitHub Actions pipeline run in the Actions tab (or screenshot) with the tag trigger, image acquisition/build, smoke test, and push steps visible.
4. Show `terraform destroy` removing resources, then `terraform apply` followed by the Ansible playbook, and confirm the Minecraft server is joinable after rebuild. Make it clear whether the same world was restored or a fresh world was created.

## Rubric

<RubricTable tsv={rubricTsv} sourceLabel="canvas/assignments/assignment-3-rubrics.tsv" caption="Infrastructure Automation on EC2" />

## Extra Credit (up to +10)

- **Remote Terraform state (+3)**: configure an S3 backend with state locking; document the setup and tradeoffs.
- **Ansible role reuse (+4)**: structure the playbook as reusable role(s) with variables; demonstrate running against a second instance or show how the role could be reused.
- **Pipeline hardening (+3)**: add linting, security scanning, or build caching to the CI/CD pipeline; document what each step catches.
