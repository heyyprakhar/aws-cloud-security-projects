## 1. Project Overview

### 1.1 Purpose

This project delivers a **production-grade Virtual Private Cloud (VPC)** on AWS, provisioned entirely through **Infrastructure as Code (IaC)** using Terraform. Security is treated as a first-class concern Ievery network decision is deliberate, documented, and enforced through code.

The infrastructure is designed for a standard **3-tier web application** (web → application → database) and follows AWS Well-Architected Framework principles for security, reliability, and operational excellence.

### 1.2 Objectives

- Eliminate manual console-based provisioning
- Enforce network segmentation through subnet tiers
- Implement defense-in-depth using Security Groups and Network ACLs
- Achieve high availability across two Availability Zones
- Provide full network visibility through VPC Flow Logs
- Enable private AWS service access without internet exposure

### 1.3 Scope

|In Scope|Out of Scope|
|---|---|
|VPC, subnets, route tables|Application code|
|Internet Gateway, NAT Gateways|EC2 instance provisioning|
|Security Groups, NACLs|Load balancer configuration|
|VPC Endpoints|DNS (Route 53)|
|VPC Flow Logs|VPN / Direct Connect|
|IAM roles for Flow Logs|Multi-account setup|

### 1.4 Technology Stack

|Component|Version / Service|
|---|---|
|IaC Tool|Terraform ≥ 1.5.0|
|AWS Provider|hashicorp/aws ~> 5.0|
|Cloud Platform|AWS|
|Region|ap-south-1 (Mumbai)|
|Availability Zones|ap-south-1a, ap-south-1b|

---

## 2. Architecture

### 2.1 High-Level Architecture Diagram

![[aws-3-tier-vpc-architecture.svg]]

### 2.2 Architecture Description

The VPC (`10.0.0.0/16`) is divided into **three network tiers** across **two Availability Zones**:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    AWS REGION: ap-south-1                            │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    VPC: 10.0.0.0/16                           │  │
│  │                                                               │  │
│  │   ┌─────────────────────┐    ┌─────────────────────┐         │  │
│  │   │   AZ: ap-south-1a   │    │   AZ: ap-south-1b   │         │  │
│  │   │                     │    │                     │         │  │
│  │   │  PUBLIC  10.0.1.0/24│    │  PUBLIC  10.0.2.0/24│         │  │
│  │   │  ┌───────────────┐  │    │  ┌───────────────┐  │         │  │
│  │   │  │  NAT Gateway  │  │    │  │  NAT Gateway  │  │         │  │
│  │   │  └───────────────┘  │    │  └───────────────┘  │         │  │
│  │   │                     │    │                     │         │  │
│  │   │  PRIVATE 10.0.10.0/24│   │  PRIVATE 10.0.11.0/24│        │  │
│  │   │  ┌───────────────┐  │    │  ┌───────────────┐  │         │  │
│  │   │  │  App Servers  │  │    │  │  App Servers  │  │         │  │
│  │   │  └───────────────┘  │    │  └───────────────┘  │         │  │
│  │   │                     │    │                     │         │  │
│  │   │  DATA   10.0.100.0/24│   │  DATA   10.0.101.0/24│        │  │
│  │   │  ┌───────────────┐  │    │  ┌───────────────┐  │         │  │
│  │   │  │   Databases   │  │    │  │   Databases   │  │         │  │
│  │   │  └───────────────┘  │    │  └───────────────┘  │         │  │
│  │   └─────────────────────┘    └─────────────────────┘         │  │
│  │                                                               │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│         ┌──────────────────┐                                        │
│         │ Internet Gateway │◀────── Public Internet                │
│         └──────────────────┘                                        │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.3 Architectural Principles

|Principle|Implementation|
|---|---|
|**Segmentation**|Three distinct subnet tiers with isolated route tables|
|**Least Privilege**|Security Groups reference each other, never CIDR blocks for internal traffic|
|**Defense in Depth**|NACLs (subnet) + Security Groups (instance) + host controls|
|**High Availability**|All resources span two AZs|
|**Isolation**|Data tier has no internet route|
|**Observability**|VPC Flow Logs to CloudWatch and S3|
|**Automation**|100% Terraform-managed|

---

## 3. Network Design

### 3.1 VPC Configuration

|Parameter|Value|
|---|---|
|CIDR Block|`10.0.0.0/16`|
|Total IP Addresses|65,536|
|DNS Support|Enabled|
|DNS Hostnames|Enabled|
|Tenancy|Default|

### 3.2 Subnet Design

![[subnet.png]]

|Subnet Name|CIDR|AZ|Tier|Internet Access|Purpose|
|---|---|---|---|---|---|
|`vpc-iac-public-ap-south-1a`|`10.0.1.0/24`|ap-south-1a|Public|Direct (IGW)|ALB, NAT, Bastion|
|`vpc-iac-public-ap-south-1b`|`10.0.2.0/24`|ap-south-1b|Public|Direct (IGW)|ALB, NAT (HA)|
|`vpc-iac-private-ap-south-1a`|`10.0.10.0/24`|ap-south-1a|Private|Outbound (NAT-1a)|Application servers|
|`vpc-iac-private-ap-south-1b`|`10.0.11.0/24`|ap-south-1b|Private|Outbound (NAT-1b)|Application servers|
|`vpc-iac-data-ap-south-1a`|`10.0.100.0/24`|ap-south-1a|Data|**None**|Databases|
|`vpc-iac-data-ap-south-1b`|`10.0.101.0/24`|ap-south-1b|Data|**None**|Databases|

**CIDR Allocation Rationale:**

- `/24` subnets provide 251 usable IPs each — sufficient for most workloads and aligned with AWS best practice.
- Public subnets use offsets `1–2`, private use `10–11`, data use `100–101` — this creates a clear addressing scheme with room for growth.

### 3.3 Route Tables

![[route-tables.png]]

|Route Table|Associated Subnets|Routes|
|---|---|---|
|`vpc-iac-public-rt`|Public 1a, Public 1b|`10.0.0.0/16 → local`  <br>`0.0.0.0/0 → IGW`|
|`vpc-iac-private-rt-ap-south-1a`|Private 1a|`10.0.0.0/16 → local`  <br>`0.0.0.0/0 → NAT-1a`|
|`vpc-iac-private-rt-ap-south-1b`|Private 1b|`10.0.0.0/16 → local`  <br>`0.0.0.0/0 → NAT-1b`|
|`vpc-iac-data-rt`|Data 1a, Data 1b|`10.0.0.0/16 → local`  <br>**(No default route)**|

**Data Tier Isolation — Critical Design Point:**

The data route table intentionally has **no `0.0.0.0/0` route**. Databases cannot initiate outbound internet connections under any circumstances. AWS service access is provided exclusively through Gateway VPC Endpoints.

![[data-route-table.png]]

### 3.4 NAT Gateways

![[nat-gateway.png]]

|NAT Gateway|Elastic IP|Public Subnet|AZ|
|---|---|---|---|
|`vpc-iac-nat-ap-south-1a`|EIP-1|public-1a|ap-south-1a|
|`vpc-iac-nat-ap-south-1b`|EIP-2|public-1b|ap-south-1b|

**Design Rationale:**

- **One NAT per AZ** eliminates cross-AZ data transfer charges and latency.
- **AZ failure resilience** — if one AZ becomes unavailable, the other NAT continues serving its local private subnet.
- Each NAT has its own Elastic IP for stable outbound source addresses.

### 3.5 Internet Gateway

|Parameter|Value|
|---|---|
|Name|`vpc-iac-igw`|
|Attached to|`vpc-iac-vpc`|
|State|Attached|
|Purpose|Inbound/outbound internet for public subnets|

---

## 4. Security Architecture

### 4.1 Defense-in-Depth Layers

```
┌─────────────────────────────────────────────────────────────┐
│  LAYER 1: Network ACLs (Subnet-level, Stateless)            │
│  • Default deny + explicit allows                           │
│  • Evaluated in rule-number order                           │
│  • Supports DENY rules                                      │
├─────────────────────────────────────────────────────────────┤
│  LAYER 2: Security Groups (Instance-level, Stateful)        │
│  • Allow rules only                                         │
│  • SG-to-SG references (dynamic least privilege)            │
│  • Return traffic automatically permitted                   │
├─────────────────────────────────────────────────────────────┤
│  LAYER 3: Host-Based Controls (OS-level)                    │
│  • iptables/nftables                                        │
│  • Application authentication                               │
│  • TLS everywhere                                           │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Security Groups

![[security-groups.png]]

|Security Group|Inbound|Source|Outbound|Destination|
|---|---|---|---|---|
|`vpc-iac-alb-sg`|TCP 443|`0.0.0.0/0`|TCP 8080|**App SG**|
|`vpc-iac-app-sg`|TCP 8080|**ALB SG**|TCP 5432|**DB SG**|
|`vpc-iac-db-sg`|TCP 5432|**App SG**|Stateful return only|—|

**Security Group Chaining:**

```
Internet ──▶ ALB-SG ──▶ App-SG ──▶ DB-SG
            :443        :8080       :5432
            from any    from        from
                        ALB-SG      App-SG
```

No internal traffic uses CIDR blocks. Each tier references the previous tier's Security Group ID, ensuring dynamic and precise access control.

![[app-sg-rules.png]]
### 4.3 Network ACLs

|NACL|Inbound Rules|Outbound Rules|
|---|---|---|
|`vpc-iac-public-nacl`|100: TCP 443 from `0.0.0.0/0`  <br>200: TCP 1024–65535 from `0.0.0.0/0`|100: All to `0.0.0.0/0`|
|`vpc-iac-private-nacl`|100: All from `10.0.0.0/16`  <br>200: TCP 1024–65535 from `0.0.0.0/0`|100: All to `0.0.0.0/0`|
|`vpc-iac-data-nacl`|100: All from `10.0.0.0/16`|100: All to `10.0.0.0/16`|

**Key Differentiator:** NACLs are stateless — they require explicit rules for return traffic (ephemeral ports 1024–65535). Security Groups are stateful and handle this automatically.

### 4.4 VPC Endpoints

![[vpc-endpoints.png]]

|Endpoint|Service|Type|Attached Route Tables|
|---|---|---|---|
|`vpc-iac-s3-endpoint`|`com.amazonaws.ap-south-1.s3`|Gateway|data-rt, private-rt-1a, private-rt-1b|
|`vpc-iac-dynamodb-endpoint`|`com.amazonaws.ap-south-1.dynamodb`|Gateway|data-rt, private-rt-1a, private-rt-1b|

**Purpose:** Data subnets have no internet route. Gateway Endpoints allow them to reach S3 and DynamoDB without traversing the public internet — traffic stays entirely within the AWS private network.

### 4.5 VPC Flow Logs

![[vpc-flow-logs.png]]

|Flow Log|Destination|Traffic Type|Retention|
|---|---|---|---|
|`vpc-iac-flow-log-cloudwatch`|CloudWatch Logs (`/aws/vpc/vpc-iac/flow-logs`)|ALL|90 days|
|`vpc-iac-flow-log-s3`|S3 (`vpc-iac-flow-logs-<account-id>`)|ALL|Indefinite|

**Log Format:**

```
<version> <account-id> <interface-id> <srcaddr> <dstaddr>
<srcport> <dstport> <protocol> <packets> <bytes>
<start> <end> <action> <log-status>
```

**Dual-Destination Rationale:**

- **CloudWatch** enables real-time monitoring, metric filters, and alarms (e.g., "alert on rejected traffic spike").
- **S3** provides cheap long-term storage and integration with Athena for forensic analysis.

---

## 5. Traffic Flow

### 5.1 Inbound User Request

```
Internet
   │
   ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Internet     │───▶│     ALB      │───▶│  App Server  │───▶│   Database   │
│ Gateway      │    │  (Public)    │    │  (Private)   │    │    (Data)    │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
                         │                    │                    │
                    SG: 443               SG: 8080             SG: 5432
                    from 0.0.0.0/0        from ALB-SG          from App-SG
```

### 5.2 Outbound Server Updates (Private Tier)

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  App Server  │───▶│ NAT Gateway  │───▶│ Internet     │───▶ Internet
│  (Private)   │    │  (Public)    │    │ Gateway      │
└──────────────┘    └──────────────┘    └──────────────┘
   0.0.0.0/0 → NAT        0.0.0.0/0 → IGW
```

### 5.3 Data Tier (Isolated)

```
┌──────────────┐         ┌──────────────────────┐
│   Database   │  ✗───▶  │      Internet        │   NO outbound access
│   (Data)     │         │                      │
└──────────────┘         └──────────────────────┘
        │
        └──▶ VPC Endpoint ──▶ AWS S3 / DynamoDB
```

**The data tier has no internet route.** The only path to AWS services is via Gateway VPC Endpoints, which keep traffic on the AWS private network.

---

## 6. Terraform Project Structure

```
vpc-infrastructure-as-code/
├── README.md                    # This documentation
├── .gitignore                   # Git ignore rules
├── main.tf                      # Provider & backend configuration
├── variables.tf                 # Input variables
├── terraform.tfvars             # Variable values
├── outputs.tf                   # Output values
├── vpc.tf                       # VPC, subnets, Internet Gateway
├── routing.tf                   # Route tables & associations
├── nat.tf                       # NAT Gateways & Elastic IPs
├── security_groups.tf           # Security groups & rules
├── nacls.tf                     # Network ACLs
├── endpoints.tf                 # VPC Gateway Endpoints
├── flow_logs.tf                 # VPC Flow Logs (CloudWatch + S3)
├── docs/
│   ├── architecture.md          # Detailed architecture notes
│   └── security-decisions.md    # Security rationale
└── screenshots/
    ├── 01-vpc-list.png
    ├── 02-subnets.png
    ├── 03-nat-gateways.png
    ├── 04-route-tables.png
    ├── 05-data-route-no-internet.png
    ├── 06-security-groups.png
    ├── 07-app-sg-rules.png
    ├── 08-vpc-endpoints.png
    ├── 09-flow-logs.png
    └── 10-apply-output.png
```

### 6.1 File Responsibilities

|File|Responsibility|
|---|---|
|`main.tf`|Terraform block, provider configuration, backend|
|`variables.tf`|Variable declarations with defaults and descriptions|
|`terraform.tfvars`|Environment-specific values (region, CIDR, AZs)|
|`vpc.tf`|VPC, Internet Gateway, all subnets|
|`routing.tf`|Route tables and subnet associations|
|`nat.tf`|Elastic IPs and NAT Gateways|
|`security_groups.tf`|Security groups and separate rule resources|
|`nacls.tf`|Network ACLs for all three tiers|
|`endpoints.tf`|S3 and DynamoDB Gateway Endpoints|
|`flow_logs.tf`|Flow logs, IAM role, CloudWatch log group, S3 bucket|
|`outputs.tf`|Exported resource IDs and names|

---

## 7. Resource Inventory

### 7.1 Complete Resource List

|#|Resource Type|Count|Terraform Name|
|---|---|---|---|
|1|VPC|1|`aws_vpc.main`|
|2|Internet Gateway|1|`aws_internet_gateway.igw`|
|3|Public Subnets|2|`aws_subnet.public`|
|4|Private Subnets|2|`aws_subnet.private`|
|5|Data Subnets|2|`aws_subnet.data`|
|6|Route Tables|4|`aws_route_table.{public,private,data}`|
|7|Route Table Associations|6|`aws_route_table_association.*`|
|8|Elastic IPs|2|`aws_eip.nat`|
|9|NAT Gateways|2|`aws_nat_gateway.nat`|
|10|Security Groups|3|`aws_security_group.{alb,app,db}`|
|11|Security Group Rules|5|`aws_security_group_rule.*`|
|12|Network ACLs|3|`aws_network_acl.*`|
|13|VPC Endpoints|2|`aws_vpc_endpoint.{s3,dynamodb}`|
|14|Flow Logs|2|`aws_flow_log.{cloudwatch,s3}`|
|15|CloudWatch Log Group|1|`aws_cloudwatch_log_group.flow_logs`|
|16|S3 Bucket|1|`aws_s3_bucket.flow_logs`|
|17|IAM Role|1|`aws_iam_role.flow_logs`|
|18|IAM Role Policy|1|`aws_iam_role_policy.flow_logs_cloudwatch`|

**Total: ~40 AWS resources**

### 7.2 Terraform Outputs

|Output|Description|
|---|---|
|`vpc_id`|VPC identifier|
|`public_subnet_ids`|List of public subnet IDs|
|`private_subnet_ids`|List of private subnet IDs|
|`data_subnet_ids`|List of data subnet IDs|
|`nat_gateway_ids`|List of NAT Gateway IDs|
|`alb_security_group_id`|ALB Security Group ID|
|`app_security_group_id`|App Security Group ID|
|`db_security_group_id`|DB Security Group ID|
|`flow_logs_cloudwatch_group`|CloudWatch log group name|
|`flow_logs_s3_bucket`|S3 bucket name|

---

## 8. Deployment Guide

### 8.1 Prerequisites

|Requirement|Verification Command|
|---|---|
|AWS account with programmatic access|`aws sts get-caller-identity`|
|Terraform ≥ 1.5.0|`terraform --version`|
|AWS CLI configured|`aws configure get region`|
|IAM permissions (VPC, EC2, S3, CloudWatch, IAM)|—|

### 8.2 Deployment Commands

```bash
# Step 1: Navigate to project directory
cd vpc-infrastructure-as-code

# Step 2: Initialize Terraform (downloads AWS provider)
terraform init

# Step 3: Validate configuration syntax
terraform validate

# Step 4: Preview the execution plan
terraform plan -var-file="terraform.tfvars"

# Step 5: Apply the configuration
terraform apply -var-file="terraform.tfvars"
# → Type "yes" when prompted
```

**Deployment time:** 5–8 minutes (NAT Gateways are the slowest resource at ~2 minutes each).

### 8.3 Expected Apply Output

![[terminal completed.png]]

### 8.4 Deployment Regions

|Parameter|Value|
|---|---|
|AWS Region|`ap-south-1` (Mumbai)|
|Availability Zones|`ap-south-1a`, `ap-south-1b`|

---

## 9. Verification & Screenshots

All screenshots were captured from the AWS Console with region set to **ap-south-1 (Mumbai)**.

### 9.1 VPC

![[vpc-list.png]]

- VPC `vpc-iac-vpc` exists with CIDR `10.0.0.0/16`
- DNS resolution and hostnames enabled

### 9.2 Subnets

![[subnet.png]]

- 6 subnets across 2 AZs
- 2 public, 2 private, 2 data
- Correct CIDR allocation per tier

### 9.3 NAT Gateways

![[nat-gateway.png]]

- 2 NAT Gateways in `Available` state
- One per AZ, each with its own Elastic IP
- Each associated with the correct public subnet

### 9.4 Route Tables

![[route-tables.png]]

- 4 route tables (public, 2 private, data)
- Public → IGW, Private → NAT, Data → no default

### 9.5 Data Route Table Isolation

![[data-route-table.png]]

- Only the local route (`10.0.0.0/16`) exists
- No `0.0.0.0/0` route — data tier cannot reach the internet
- This is the critical proof of data tier isolation

### 9.6 Security Groups

![[security-groups.png]]

- 3 custom security groups: `alb-sg`, `app-sg`, `db-sg`
- Each with least-privilege rules

### 9.7 Security Group Chaining

![[app-sg-rules.png]]

- App SG inbound rule source is **ALB SG ID** (not a CIDR block)
- Demonstrates dynamic least-privilege access control

### 9.8 VPC Endpoints

![[vpc-endpoints.png]]

- S3 and DynamoDB Gateway Endpoints
- Status: `Available`
- Attached to data and private route tables

### 9.9 VPC Flow Logs

![[vpc-flow-logs.png]]

- 2 flow logs: CloudWatch + S3
- Traffic type: `ALL`
- Status: `Active`

### 9.10 Deployment Output
![[terminal completed.png]]


- `Apply complete! Resources: 40 added`
- All outputs displayed correctly

---

## 10. Design Decisions

### 10.1 Why are certain resources in private subnets?

Public subnets are directly reachable from the internet and are therefore subject to port scanning, DDoS attacks, and direct exploitation of vulnerabilities. By placing application servers and databases in **private** and **data** subnets, they become **unreachable from the internet**. An attacker would first need to compromise the ALB, then pivot through the application tier — a significantly harder attack path.

|Aspect|Public Subnet|Private Subnet|
|---|---|---|
|Internet reachability|Direct|Via ALB only|
|Port scanning exposure|Yes|No|
|DDoS exposure|Yes|No|
|Vulnerability impact|Direct access|Requires pivot|

### 10.2 What traffic is allowed in and out?

|Tier|Inbound|Outbound|
|---|---|---|
|**ALB**|TCP 443 from `0.0.0.0/0`|TCP 8080 → App SG|
|**App**|TCP 8080 from ALB SG only|TCP 5432 → DB SG; internet via NAT (for OS updates)|
|**DB**|TCP 5432 from App SG only|None (stateful SG allows return traffic)|
|**Data**|Only VPC-internal (NACL)|No internet; VPC endpoints for AWS services|

### 10.3 How do Security Groups and NACLs complement each other?

|Aspect|Security Groups|Network ACLs|
|---|---|---|
|Level|Instance/ENI|Subnet|
|Statefulness|Stateful|Stateless|
|Rule types|Allow only|Allow + Deny|
|Evaluation|All rules combined|Ordered by rule number|
|Source types|CIDR + SG references|CIDR only|
|Primary use|Fine-grained app access|Subnet-wide blocks, explicit denies|

**Complementary roles:** Security Groups enforce application-level access (e.g., "only the ALB can reach the app on 8080"). NACLs provide subnet-level guardrails (e.g., "the data subnet denies all non-VPC traffic"). Together they implement defense in depth — if a security group is misconfigured, the NACL still blocks the traffic.

### 10.4 Where would inspection or logging live?

**Logging:** VPC Flow Logs are sent to **CloudWatch Logs** (for real-time monitoring, metric filters, and alarms) and **S3** (for long-term archival and Athena-based forensic analysis).

**Inspection options for production:**

|Option|Mechanism|Use Case|
|---|---|---|
|**AWS Network Firewall**|Stateful inspection in a dedicated firewall subnet|IPS/IDS, domain filtering, TLS inspection|
|**Gateway Load Balancer**|Inline traffic inspection via third-party appliances|Advanced threat detection|
|**VPC Traffic Mirroring**|Passive copy of traffic to an IDS appliance|Out-of-band analysis|

In this project, logging is fully implemented. Inspection would be added in front of the public subnets in a production deployment.

### 10.5 How does this design reduce attack surface?

- **No public IPs** on application or database instances.
- **Security Group chaining** — the DB accepts traffic only from the app SG; the app only from the ALB SG.
- **Data subnets have no internet route** — even with code execution on a database, data exfiltration to the internet is impossible.
- **NACLs provide a second deny layer** at the subnet boundary.
- **Least privilege** applied at every tier.
- **Flow Logs** enable detection of anomalous traffic patterns.

### 10.6 How does it support future growth?

- The VPC uses a `/16` CIDR (`10.0.0.0/16`) with 65,536 IPs — ample room for additional subnets and tiers.
- Subnets are `/24` (251 usable IPs) — AWS best practice, easy to add more.
- Multi-AZ design — additional AZs can be added by extending the `azs` variable.
- **Modular Terraform structure** — new tiers (e.g., a container tier, a bastion tier) can be added without modifying existing files.
- Gateway Endpoints can be extended to other AWS services (e.g., SQS, KMS) as requirements grow.

---

## 11. Cost Analysis

> **Important:** NAT Gateways are **not covered by AWS Free Tier**.

### 11.1 Cost Breakdown (ap-south-1)

|Resource|Quantity|Approximate Cost|
|---|---|---|
|VPC, Subnets, Route Tables|—|Free|
|Internet Gateway|1|Free|
|Security Groups, NACLs|—|Free|
|Gateway VPC Endpoints|2|Free|
|Elastic IPs (attached)|2|Free|
|**NAT Gateway (hourly)**|2|**~$0.056/hour each**|
|**NAT Gateway (data processing)**|—|~$0.056/GB|
|CloudWatch Logs|—|Free tier (5 GB/month)|
|S3|—|Free tier (5 GB/month)|

### 11.2 Cost by Duration

|Duration|Estimated Cost (INR)|
|---|---|
|10 minutes|~₹2|
|20 minutes|~₹4–5|
|1 hour|~₹10|
|1 day|~₹225|
|1 month|~₹6,700|

**Recommendation:** For demonstration purposes, deploy, capture screenshots, and destroy within 15–20 minutes. Total cost is typically under ₹5.

### 11.3 Cost Controls

- Create a **Zero-Spend Budget** in AWS Billing to receive alerts on any charge.
- Always run `terraform destroy` after verification.
- Verify Elastic IPs are released after destroy (stray EIPs incur charges).

---

## 12. Cleanup

### 12.1 Destroy Command

```bash
terraform destroy -var-file="terraform.tfvars"
# → Type "yes" when prompted
```

**Teardown time:** 8–12 minutes (NAT Gateways are the slowest to delete).

### 12.2 Expected Destroy Output

```
Destroy complete! Resources: 40 destroyed.
```

### 12.3 Post-Destroy Verification

Verify in the AWS Console (region `ap-south-1`):

|Check|Expected Result|
|---|---|
|VPC → Your VPCs|`vpc-iac-vpc` not present|
|VPC → NAT Gateways|0 NAT Gateways|
|EC2 → Elastic IPs|0 Elastic IPs (release manually if any remain)|
|S3 → Buckets|`vpc-iac-flow-logs-*` not present|
|CloudWatch → Log groups|`/aws/vpc/vpc-iac/flow-logs` not present|
|VPC → Endpoints|0 endpoints|

### 12.4 Troubleshooting Cleanup

|Issue|Resolution|
|---|---|
|NAT Gateway stuck in "Deleting"|Wait 5 minutes; then re-run `terraform destroy`|
|Elastic IP not released|Manually release via EC2 → Elastic IPs → Actions → Release|
|S3 bucket not empty|`force_destroy = true` is set in code; if manual, empty the bucket first|

---

## 13. Appendix

### 13.1 Variables Reference

|Variable|Default|Description|
|---|---|---|
|`aws_region`|`ap-south-1`|AWS region for deployment|
|`vpc_cidr`|`10.0.0.0/16`|VPC CIDR block|
|`project_name`|`vpc-iac`|Prefix for all resource names and tags|
|`azs`|`["ap-south-1a", "ap-south-1b"]`|Availability Zones|

