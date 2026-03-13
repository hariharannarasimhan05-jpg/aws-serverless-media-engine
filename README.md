# ☁️ Global AI Media Engine: 10-Service Serverless Stack

## 🌟 Overview
This project demonstrates a high-scale, event-driven architecture built entirely on AWS using **Infrastructure as Code (Terraform)**. It automates the process of image analysis and global content delivery, moving from raw data to a secure, user-facing dashboard in seconds.

## 🏗️ The 10-Service Architecture
This ecosystem integrates 10 distinct AWS services to handle the full lifecycle of media processing:

1.  **S3 (Ingest)**: Landing zone for raw image uploads.
2.  **Lambda**: Serverless compute "brain" that orchestrates the workflow.
3.  **Rekognition (AI)**: Deep learning-based object and label detection.
4.  **DynamoDB**: NoSQL storage for high-speed metadata persistence.
5.  **SNS**: Real-time email notification system for processing alerts.
6.  **S3 (Hosting)**: Static website hosting for the results dashboard.
7.  **CloudFront**: Global CDN providing low-latency access to results.
8.  **Origin Access Control (OAC)**: Latest security standard to protect S3 origins.
9.  **IAM**: Granular "Least Privilege" roles and policies for inter-service security.
10. **CloudWatch**: Centralized logging and observability for troubleshooting.

---

## 🛠️ Technical Deep Dive

### **Event-Driven Workflow**
- **Trigger**: An `ObjectCreated` event in the S3 upload bucket invokes the Lambda function.
- **Processing**: Lambda extracts metadata, calls the Rekognition API, and formats the labels.
- **Persistence**: Results are indexed in DynamoDB using a unique `ImageID`.
- **Security**: The dashboard is strictly locked down; only CloudFront can access the S3 assets via **OAC signing**.

### **Infrastructure as Code**
The entire stack is managed via **Terraform**, ensuring:
- **Idempotency**: Repeatable deployments across any AWS region.
- **State Management**: Secure tracking of resource dependencies.
- **Scalability**: Pay-as-you-go pricing model (100% Free Tier compatible).

---

## 🚀 Deployment Instructions
1. Clone the repository.
2. Ensure you have the **AWS CLI** configured with appropriate permissions.
3. Update `terraform.tfvars` with your AWS credentials (see `terraform.tfvars.example`).
4. Initialize and apply:
   ```bash
   terraform init
   terraform apply
