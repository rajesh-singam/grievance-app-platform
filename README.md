# Grievance Management System

[![CI](https://github.com/rajesh-singam/grievance-app-platform/actions/workflows/ci.yml/badge.svg)](https://github.com/rajesh-singam/grievance-app-platform/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## Table of Contents

- [Overview](#overview)
- [System Architecture](#system-architecture)
- [Technology Stack](#technology-stack)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Deployment Strategy](#deployment-strategy)
- [CI/CD Pipeline](#cicd-pipeline)
- [Security Model](#security-model)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

The **Grievance Management System** is a production‑ready microservices platform designed to handle user registration, authentication, grievance lifecycle management, and audit logging. It comprises four independently deployable Flask services, each backed by its own MongoDB database, orchestrated on Kubernetes.

**Core capabilities:**

- User registration and secure login (JWT‑based)
- Role‑based access control (RBAC)
- Full CRUD operations for grievances
- Status transition workflow (submitted → in review → resolved/rejected)
- Append‑only audit trail for compliance
- Health checks and readiness probes for Kubernetes

**Environment strategy:**

- **Local development** – Docker Compose
- **Staging** – Kind (Kubernetes in Docker) on EC2, mirroring production
- **Production** – Amazon EKS with multi‑AZ, managed services, and enterprise security

The system is built with a **Backend‑for‑Frontend (BFF)** pattern where only the frontend service is exposed externally; all internal services communicate via ClusterIP and require JWT validation.

---

## System Architecture

```
                              ┌─────────────────┐
                              │     Browser     │
                              └────────┬────────┘
                                       │ HTTP (NodePort 30080)
                                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                     FRONTEND-SERVICE (:5000)                    │
│  • Serves HTML/CSS/JS (Jinja2 templates)                       │
│  • Manages HTTP sessions and user context                      │
│  • Aggregates backend calls                                    │
│  • ONLY external entry point                                   │
└─────────────────────────────────────────────────────────────────┘
           │ JWT                │ JWT                │ JWT
           ▼                    ▼                    ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│   auth-service   │  │grievance-service │  │  audit-service   │
│      :5001       │  │      :5002       │  │      :5003       │
│                  │  │                  │  │                  │
│ • Registration   │  │ • CRUD           │  │ • Append‑only    │
│ • Login / JWT    │  │ • Status mgmt    │  │ • Action logs    │
│ • auth_db        │  │ • grievance_db   │  │ • audit_db       │
└──────────────────┘  └──────────────────┘  └──────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                   MONGODB STATEFULSET                           │
│           ┌───────────┐  ┌───────────┐  ┌───────────┐        │
│           │  auth_db  │  │grievance_db│  │ audit_db  │        │
│           └───────────┘  └───────────┘  └───────────┘        │
└─────────────────────────────────────────────────────────────────┘
```

### Design Rationale

| Decision | Justification |
|----------|---------------|
| **Stateless JWT** | Each service validates tokens locally via shared `JWT_SECRET`; no per‑request network calls to auth‑service, reducing latency and eliminating a single point of failure. |
| **Database per Service** | Ensures loose coupling, independent schema evolution, and isolated scaling. Each service owns its data store. |
| **BFF Pattern** | Centralises session management and UI logic; hides internal microservice topology from clients. |
| **ClusterIP for Backend** | Minimises attack surface – internal services are not reachable from outside the cluster. |
| **Asynchronous Audit Logging** | Audit calls are fire‑and‑forget with a short timeout; audit failures do not block business operations, ensuring high availability. |

---

## Technology Stack

| Layer | Technology |
|-------|------------|
| **Runtime** | Python 3.11 |
| **Web Framework** | Flask |
| **Database** | MongoDB 7.0 (StatefulSet) |
| **Authentication** | PyJWT + bcrypt |
| **Containerisation** | Docker (multi‑stage builds) |
| **Orchestration** | Kubernetes (Deployments, StatefulSets, HPA, NetworkPolicies, Ingress) |
| **CI/CD** | GitHub Actions (lint, build, vulnerability scan, deploy) |
| **Security Scanning** | Trivy |
| **Infrastructure as Code** | Terraform (EKS, VPC, IAM) |
| **Package Management** | Helm (production charts) |

---

## Project Structure

```
grievance-app-platform/
├── auth-service/               # Identity & access management
│   ├── app.py
│   ├── Dockerfile
│   └── requirements.txt
├── grievance-service/          # Core grievance operations
│   ├── app.py
│   ├── Dockerfile
│   └── requirements.txt
├── audit-service/              # Compliance audit trail (append‑only)
│   ├── app.py
│   ├── Dockerfile
│   └── requirements.txt
├── frontend-service/           # BFF / UI layer
│   ├── app.py
│   ├── Dockerfile
│   ├── templates/
│   └── static/
    
├── helm/rajeshapp/             # Production Helm chart
├── .github/workflows/          # CI/CD pipelines
├── terraform/                  # EKS & VPC provisioning
├── docker-compose.yml          # Local development
├── HLD_DESIGN_DOCUMENT.md
└── README.md
```

---

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Kubernetes cluster (Kind for staging, EKS for production)
- `kubectl` and `helm`

### Local Development (Docker Compose)

```bash
git clone https://github.com/rajesh-singam/grievance-app-platform.git
cd grievance-app-platform

docker compose up --build
# Access at http://localhost:5000
# Register a user, create a grievance, and view audit logs

docker compose down -v   # Remove volumes
```

### Staging Deployment (Kind on EC2)

```bash
# On the staging EC2 instance (or local with Kind)
kind create cluster --name staging
eval $(kind get kubeconfig --name staging)

# Deploy using the helper script
chmod +x k8s/deploy-kind.sh
./k8s/deploy-kind.sh

# Verify pods
kubectl get pods -n grievance-system

# Access the application (NodePort 30080)
curl http://localhost:30080
```

### Production Deployment (EKS)

The production deployment uses Terraform to provision the EKS cluster and Helm to install the application. Refer to [HLD_DESIGN_DOCUMENT.md](HLD_DESIGN_DOCUMENT.md) for the complete migration checklist.

```bash
# Provision EKS (via Terraform)
cd terraform
terraform init && terraform apply -auto-approve

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name grievance-cluster

# Install the Helm chart
helm upgrade --install grievance-app ./helm/rajeshapp \
  --namespace grievance-system \
  --set image.tag=v1.2.3 \
  --set ingress.enabled=true \
  --set ingress.host=grievance.example.com
```

---


### Protected Grievance Creation

```bash
curl -X POST http://frontend-service:5000/api/grievances \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Workplace harassment complaint",
    "description": "Detailed description...",
    "category": "hr",
    "priority": "high"
  }'
```

### Health Endpoints (for Kubernetes)

| Endpoint | Probe Type | Action |
|----------|------------|--------|
| `GET /healthz` | Liveness | Restart pod on failure |
| `GET /readyz` | Readiness | Stop sending traffic until ready |

---

## Deployment Strategy

The system supports multiple deployment environments with consistent configurations.

| Environment | Platform | Purpose |
|-------------|----------|---------|
| **Local** | Docker Compose | Development and unit testing |
| **Staging** | Kind on EC2 | Integration and end‑to‑end validation; mirrors production Kubernetes |
| **Production** | EKS (Amazon) | Live traffic, multi‑AZ, auto‑scaling, managed control plane |

**Key production‑grade features in the Helm chart:**

- Horizontal Pod Autoscaler (HPA) based on CPU/memory
- Network Policies (default‑deny, explicit allow)
- Ingress with TLS termination (via AWS ALB or NGINX)
- External Secrets Operator for AWS Secrets Manager integration
- Persistent volumes for MongoDB (StatefulSet)
- Readiness/liveness probes on all services

---

## CI/CD Pipeline

All pipelines are implemented with GitHub Actions and triggered on pull requests and merges to `main`.

```yaml
# .github/workflows/ci.yml
- Lint Python (flake8)
- Build multi‑stage Docker images
- Scan images with Trivy (fail on CRITICAL vulnerabilities)
- Push images to Docker Hub (or Amazon ECR for production)
- Generate image tags as artifacts
```

```yaml
# .github/workflows/deploy.yml (manual or auto)
- Locate EC2 staging instance (tagged)
- SSH and create/update Kind cluster
- Load images from Docker Hub into Kind
- Run Helm upgrade with versioned tags
- Verify rollout status and smoke‑test endpoints
```

For production, the deployment workflow extends to EKS using `kubectl` and Helm, with separate secrets and IAM roles.

---

## Security Model

### Authentication & Authorisation

- **JWT tokens** – signed with `JWT_SECRET`, validated locally by each service.
- **Password hashing** – bcrypt with salt rounds.
- **RBAC** – role claims (`user`, `admin`, `reviewer`) enforced at service level.
- **Token expiry** – configurable TTL (default 24 hours).

### Network Security

- **NetworkPolicies** – default deny all ingress/egress; only explicitly allowed traffic (e.g., frontend → grievance, frontend → auth, etc.).
- **ClusterIP services** – no external exposure for auth, grievance, or audit.
- **TLS termination** – at the ingress layer (ALB or NGINX) for production.

### Container Security

- **Non‑root user** – all containers run as `appuser`.
- **Multi‑stage builds** – production images exclude build‑time dependencies.
- **Trivy scanning** – blocks CRITICAL and HIGH severity CVEs during CI.

### Secrets Management

| Environment | Approach |
|-------------|----------|
| **Development** | Kubernetes Secrets with base64‑encoded placeholders (committed for convenience) |
| **Staging** | Kubernetes Secrets injected via Helm values (external to repo) |
| **Production** | External Secrets Operator + AWS Secrets Manager (encrypted, audited, rotation) |

---

## Contributing

We follow a standard GitHub flow. To contribute:

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/your-feature`.
3. Write code and ensure linting passes: `flake8 . --max-line-length=120`.
4. Write clear commit messages (conventional commits preferred).
5. Push to your fork and open a pull request against `main`.

All PRs must pass CI checks (lint, build, scan) before merging.

---

## License

This project is licensed under the MIT License reachraj3.ind@gmail.com.

---

