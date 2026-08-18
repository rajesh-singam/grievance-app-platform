# Grievance Management System

![CI](https://github.com/shivscloud/rajesh-grivenceapp/actions/workflows/ci.yml/badge.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Technology Stack](#technology-stack)
- [Project Structure](#project-structure)
- [API Documentation](#api-documentation)
- [Deployment](#deployment)
- [Security](#security)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

This is a grievance management platform I built to practice microservices, Kubernetes, and real‑world deployment. It consists of four independent Flask services, each with its own MongoDB database, orchestrated in Kubernetes. The system handles user registration, JWT‑based authentication, grievance CRUD operations, and an audit trail.

**What I wanted to achieve:**

- Understand service‑to‑service communication in a cluster
- Implement stateless JWT authentication without a central session store
- Use database‑per‑service to keep things loosely coupled
- Deploy everything on Kubernetes with proper health checks, network policies, and horizontal scaling

The project is fully containerised, runs in a Kind cluster on EC2 for staging, and is ready for production migration to EKS.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                           BROWSER                               │
└────────────────────────────────┬─────────────────────────────────┘
                                 │ HTTP (NodePort 30080)
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│                    FRONTEND-SERVICE (:5000)                      │
│  • Renders HTML/CSS/JS                                          │
│  • Manages user sessions                                        │
│  • Aggregates calls to backend services                         │
│  • ONLY external entrypoint (NodePort)                          │
└────────────────────────────────┬─────────────────────────────────┘
          │ JWT               │ JWT               │ JWT
          ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  auth-service   │  │grievance-service│  │  audit-service  │
│    (:5001)      │  │    (:5002)      │  │    (:5003)      │
│                 │  │                 │  │                 │
│ • Register      │  │ • CRUD ops      │  │ • Append‑only   │
│ • Login / JWT   │  │ • Status update │  │ • Action logs   │
│ • auth_db       │  │ • grievance_db  │  │ • audit_db      │
└─────────────────┘  └─────────────────┘  └─────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│                 MONGODB STATEFULSET                              │
│        ┌──────────┐  ┌──────────┐  ┌──────────┐               │
│        │ auth_db  │  │grievance_db│  │ audit_db│               │
│        └──────────┘  └──────────┘  └──────────┘               │
└──────────────────────────────────────────────────────────────────┘
```

### Why I Made These Choices

| Decision | Rationale |
|----------|-----------|
| **Stateless JWT** | No need to hit auth‑service on every request; each service validates the token locally using a shared `JWT_SECRET`. |
| **Database per Service** | Loose coupling – I can scale or change one service without affecting the others. |
| **Backend‑for‑Frontend (BFF)** | The frontend service is the only public entrypoint; it hides internal service topology and centralises session handling. |
| **ClusterIP for Internal Services** | Only the frontend is exposed. The backend services (auth, grievance, audit) are internal‑only for security. |
| **Async Audit Logging** | Audit calls are fire‑and‑forget with a short timeout – if audit fails, the main business operation still succeeds. |

---

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Minikube (for Kubernetes deployment)
- kubectl

### Local Development (Docker Compose)

```bash
git clone https://github.com/shivscloud/rajesh-grivenceapp.git
cd rajesh-grivenceapp

docker compose up --build

# Open http://localhost:5000
# Register a user, file a grievance, and see audit logs appear

docker compose down -v   # Clean up volumes
```

### Kubernetes Deployment (Minikube)

```bash
minikube start
eval $(minikube docker-env)   # Build images inside Minikube

chmod +x k8s/deploy-minikube.sh
./k8s/deploy-minikube.sh      # One‑command deployment

minikube service frontend-service -n grievance-system
```

> If you prefer manual steps, check the script or the [HLD_DESIGN_DOCUMENT.md](HLD_DESIGN_DOCUMENT.md).

---

## Technology Stack

| Layer | Tools |
|-------|-------|
| **Language** | Python 3.11 |
| **Web Framework** | Flask |
| **Database** | MongoDB 7 (StatefulSet) |
| **Authentication** | PyJWT + bcrypt |
| **Containerisation** | Docker (multi‑stage) |
| **Orchestration** | Kubernetes (Deployments, StatefulSets, HPA, NetworkPolicies) |
| **CI/CD** | GitHub Actions (lint, build, Trivy scan, deploy) |
| **Security Scanning** | Trivy |
| **Infrastructure** | Terraform (EKS, VPC, IAM) – optional |

---

## Project Structure

```
rajesh-grivenceapp/
├── auth-service/              # Auth microservice
│   ├── app.py                 # Registration, login, JWT issuance
│   ├── Dockerfile
│   └── requirements.txt
├── grievance-service/         # Core business logic
│   ├── app.py                 # CRUD, status workflow, audit integration
│   ├── Dockerfile
│   └── requirements.txt
├── audit-service/             # Audit trail (append‑only)
│   ├── app.py                 # Action logging
│   ├── Dockerfile
│   └── requirements.txt
├── frontend-service/          # BFF / UI layer
│   ├── app.py                 # HTML rendering, session mgmt, aggregation
│   ├── Dockerfile
│   ├── templates/             # Jinja2 templates
│   └── static/                # CSS/JS assets
├── k8s/                       # Kubernetes manifests (numbered apply order)
│   ├── 00-namespace.yaml
│   ├── 01-configmap.yaml
│   ├── 02-secret.yaml
│   ├── 04-mongo-statefulset.yaml
│   ├── 05-mongo-service.yaml
│   ├── 06-13-*-deployment.yaml & *-service.yaml
│   ├── 14-network-policies.yaml
│   ├── 15-ingress.yaml
│   ├── 16-hpa.yaml
│   └── deploy-minikube.sh
├── helm/rajeshapp/            # Helm chart for production
├── .github/workflows/         # CI/CD pipelines
├── docker-compose.yml
├── HLD_DESIGN_DOCUMENT.md     # Full architecture guide
└── README.md
```

---

## API Documentation

### Authentication

```http
POST /api/login
Content-Type: application/json

{
  "username": "john_doe",
  "password": "secret123"
}

Response:
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "507f1f77bcf86cd799439011",
    "username": "john_doe",
    "role": "user"
  }
}
```

### Protected Endpoints

All backend‑to‑backend calls require the `Authorization: Bearer <token>` header.

```bash
curl -X POST http://frontend-service:5000/api/grievances \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Workplace harassment",
    "description": "Details...",
    "category": "hr",
    "priority": "high"
  }'
```

### Health Checks

| Endpoint | Purpose |
|----------|---------|
| `GET /healthz` | Liveness probe – restarts unhealthy pods |
| `GET /readyz` | Readiness probe – stops traffic until ready |

---

## Deployment

### Environments

| Environment | Platform | Purpose |
|-------------|----------|---------|
| **Local** | Docker Compose | Rapid development |
| **Development** | Minikube | Kubernetes integration testing |
| **Staging** | Kind on EC2 | Production‑like validation |
| **Production** | EKS | Live traffic, multi‑AZ |

### CI/CD Pipeline

```
Push to main
    │
    ▼
CI Workflow (GitHub Actions)
    ├─ Discover services
    ├─ Helm lint & template validation
    ├─ Matrix build per service:
    │   • Python lint (flake8)
    │   • Docker build
    │   • Trivy security scan (fails on CRITICAL findings)
    │   • Push to Docker Hub (on push)
    └─ Publish image tags
    │
    ▼
Deploy Workflow (manual or on completion)
    ├─ Find EC2 instance (tagged for staging)
    ├─ SSH to EC2
    ├─ Create Kind cluster if needed
    ├─ Pull images from Docker Hub
    ├─ `kind load docker-image` into cluster
    ├─ `helm upgrade --install rajeshapp`
    ├─ Verify pods, services, HPA, Helm release
    └─ Test with `curl http://localhost:30080`
```

For production migration to EKS, refer to the [HLD_DESIGN_DOCUMENT.md](HLD_DESIGN_DOCUMENT.md) (includes ECR, ALB, DocumentDB, External Secrets, CloudWatch, etc.).

---

## Security

### Authentication & Authorisation

- **Stateless JWT** – signed with a shared secret, verified locally by each service.
- **bcrypt** for password hashing.
- **RBAC** – each JWT includes a `role` claim, used for service‑level authorisation.
- **Token expiry** – configurable TTL to prevent indefinite reuse.

### Network Security

- **Default Deny** – NetworkPolicies block all ingress/egress by default.
- **Explicit Allow** – only required service‑to‑service communication is permitted.
- **ClusterIP Isolation** – backend services are not reachable from outside the cluster.

### Container Security

- **Non‑root user** – all containers run as `appuser`.
- **Multi‑stage builds** – production images contain only runtime dependencies, no build tools.
- **Vulnerability scanning** – Trivy blocks any CRITICAL CVEs in CI.

### Secrets Management

| Environment | Approach |
|-------------|----------|
| **Development** | Kubernetes Secrets with placeholder values (committed). |
| **Production** | External Secrets Operator + AWS Secrets Manager (encrypted, audited). |

---

## Contributing

I welcome contributions! Here’s how:

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/your-feature`.
3. Make your changes and ensure the linter passes: `flake8 . --max-line-length=120`.
4. Commit with a clear message: `git commit -m "feat: add your feature"`.
5. Push: `git push origin feature/your-feature`.
6. Open a Pull Request.

**Code style:** PEP 8 (enforced in CI), max line length 120, type hints recommended, docstrings for public functions.

---

## License

This project is licensed under the MIT License – see the [LICENSE](LICENSE) file for details.

---
