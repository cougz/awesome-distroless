# GitHub Workflows for Awesome Distroless

Simple automation for building and scanning distroless Docker images.

## 🚀 Workflows

### 1. Build and Push (`build-and-push.yml`)

**Purpose**: Automatically builds and pushes distroless images to GitHub Container Registry (GHCR).

**Triggers**:
- Push to `main` branch (when Dockerfiles change)
- Pull requests (build-only, no push)
- Manual dispatch

**Features**:
- Multi-architecture builds (linux/amd64, linux/arm64)
- Parallel builds for all services
- Build summary with image URLs

**Images produced**:
- `ghcr.io/cougz/awesome-distroless/base:1.0.0`
- `ghcr.io/cougz/awesome-distroless/postgres:17.5`
- `ghcr.io/cougz/awesome-distroless/nginx:1.29.1`
- `ghcr.io/cougz/awesome-distroless/redis:7.4.2`

### 2. Vulnerability Scan (`security-scan.yml`)

**Purpose**: Simple vulnerability scanning with Trivy.

**Triggers**:
- After successful image builds
- Weekly schedule (Sundays at 6 AM UTC)
- Manual dispatch

**Features**:
- Scans for HIGH and CRITICAL vulnerabilities only
- Simple table output in workflow logs
- No complex automation or issue creation

## 🔧 Setup

### Repository Settings
Go to **Settings** → **Actions** → **General**:
```
✅ Allow all actions and reusable workflows
✅ Read and write permissions
✅ Allow GitHub Actions to create and approve pull requests
```

### Usage

**Build images:**
```bash
git push origin main
```

**Manual build:**
```bash
gh workflow run build-and-push.yml
```

**Manual vulnerability scan:**
```bash
gh workflow run security-scan.yml
```

**Use images:**
```bash
# Pull pre-built images
docker compose --profile image up

# Or build locally
docker compose up
```

## 📦 Image URLs

```bash
docker pull ghcr.io/cougz/awesome-distroless/postgres:17.5
docker pull ghcr.io/cougz/awesome-distroless/nginx:1.29.1
docker pull ghcr.io/cougz/awesome-distroless/redis:7.4.2
```

That's it! Simple and focused on what you need. 🎯