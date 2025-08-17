# GitHub Workflows for Awesome Distroless

This directory contains GitHub Actions workflows that automatically build, test, and maintain the distroless Docker images.

## 🚀 Workflows Overview

### 1. Build and Push (`build-and-push.yml`)

**Purpose**: Automatically builds and pushes all distroless images to GitHub Container Registry (GHCR).

**Triggers**:
- Push to `main` branch (when Dockerfiles change)
- Pull requests (build-only, no push)
- Manual dispatch with force rebuild option

**Features**:
- **Multi-architecture builds** (linux/amd64, linux/arm64)
- **Dependency management** (base image built first)
- **Layer caching** for faster builds
- **Parallel builds** for services
- **Build summary** with image URLs

**Images produced**:
- `ghcr.io/cougz/awesome-distroless/base:1.0.0`
- `ghcr.io/cougz/awesome-distroless/postgres:17.5`
- `ghcr.io/cougz/awesome-distroless/nginx:1.29.1`
- `ghcr.io/cougz/awesome-distroless/redis:7.4.2`

### 2. Security Scan (`security-scan.yml`)

**Purpose**: Performs security vulnerability scanning on all built images.

**Triggers**:
- Weekly schedule (Sundays at 2 AM UTC)
- Manual dispatch
- Push to `main` branch (when Dockerfiles change)

**Features**:
- **Trivy vulnerability scanner** integration
- **SARIF report upload** to GitHub Security tab
- **Matrix strategy** for all services
- **Security summary** in workflow results

### 3. Update Check (`update-check.yml`)

**Purpose**: Monitors upstream projects for new versions and creates issues when updates are available.

**Triggers**:
- Daily schedule (6 AM UTC)
- Manual dispatch

**Features**:
- **Version monitoring** for PostgreSQL, Nginx, and Redis
- **Automated issue creation** when updates are available
- **Update summary** with current vs latest versions
- **Issue deduplication** (updates existing issues)

## 🔧 Setup Requirements

### 1. Repository Permissions

Ensure your repository has the following settings:

**Actions > General**:
- ✅ Allow GitHub Actions to create and approve pull requests
- ✅ Allow GitHub Actions to push to your repository

**Settings > Actions > General > Workflow permissions**:
- ✅ Read and write permissions
- ✅ Allow GitHub Actions to create and approve pull requests

### 2. Package Registry Access

The workflows automatically use `GITHUB_TOKEN` which has the necessary permissions for GHCR.

**No additional secrets required!** 🎉

### 3. Security Tab (Optional)

To view security scan results:
- Go to **Security** tab in your repository
- Navigate to **Code scanning** to see Trivy results

## 📦 Using the Built Images

### Quick Start (Image Mode)
```bash
# Clone the repository
git clone https://github.com/cougz/awesome-distroless.git
cd awesome-distroless

# Use pre-built images from GHCR
docker compose --profile image up
```

### Custom Build (Build Mode)
```bash
# Customize .env files as needed
cp postgres/.env.example postgres/.env
cp nginx/.env.example nginx/.env
cp redis/.env.example redis/.env

# Build from source with your customizations
docker compose up
```

### Manual Image Pull
```bash
# Pull individual images
docker pull ghcr.io/cougz/awesome-distroless/postgres:17.5
docker pull ghcr.io/cougz/awesome-distroless/nginx:1.29.1
docker pull ghcr.io/cougz/awesome-distroless/redis:7.4.2

# Run individually
docker run -d \
  --name postgres \
  -p 5432:5432 \
  -v postgres-data:/var/lib/postgresql/data \
  ghcr.io/cougz/awesome-distroless/postgres:17.5
```

## 🔄 Manual Workflow Execution

### Build All Images
```bash
# Via GitHub CLI
gh workflow run build-and-push.yml

# Via GitHub Web UI
# Go to Actions → Build and Push → Run workflow
```

### Force Rebuild
```bash
# Force rebuild all images (ignores cache)
gh workflow run build-and-push.yml -f force_rebuild=true
```

### Run Security Scan
```bash
gh workflow run security-scan.yml
```

### Check for Updates
```bash
gh workflow run update-check.yml
```

## 🏷️ Image Tagging Strategy

### Automatic Tags
- `latest` - Latest build from main branch
- `<branch-name>` - Builds from feature branches
- `pr-<number>` - Builds from pull requests

### Version Tags
- `17.5` - PostgreSQL version
- `1.29.1` - Nginx version  
- `7.4.2` - Redis version
- `1.0.0` - Base image version

### Examples
```bash
# Latest stable
ghcr.io/cougz/awesome-distroless/postgres:latest

# Specific version
ghcr.io/cougz/awesome-distroless/postgres:17.5

# Development branch
ghcr.io/cougz/awesome-distroless/postgres:feature-branch

# Pull request
ghcr.io/cougz/awesome-distroless/postgres:pr-123
```

## 📊 Monitoring and Maintenance

### Build Status
- Check **Actions** tab for build status
- Build summaries show image URLs and status
- Failed builds will show detailed logs

### Security Monitoring
- **Security** tab shows vulnerability scan results
- Weekly automated scans keep images secure
- SARIF reports integrate with GitHub Security

### Update Tracking
- Daily update checks create issues for available updates
- Issues are labeled with `dependencies` and `automated`
- Issues are updated (not duplicated) on subsequent runs

## 🚨 Troubleshooting

### Common Issues

**Build fails with "permission denied"**:
- Check repository workflow permissions
- Ensure GITHUB_TOKEN has package write access

**Images not appearing in GHCR**:
- Verify package visibility is set to public
- Check if builds are running on main branch

**Security scans failing**:
- May indicate high-severity vulnerabilities
- Review Trivy output in workflow logs
- Consider updating base dependencies

**Update checks not working**:
- GitHub API rate limits may apply
- Check if upstream repositories changed API format

### Getting Help

1. Check workflow logs in **Actions** tab
2. Review GitHub documentation for Actions and Packages
3. Create an issue in the repository for project-specific problems

## 🎯 Best Practices

### Development Workflow
1. Create feature branch
2. Modify Dockerfiles as needed
3. Push to trigger build (test-only)
4. Create PR to main
5. Merge triggers production build and push

### Security
- Monitor weekly security scan results
- Update base images when vulnerabilities are found
- Review update notifications promptly

### Maintenance
- Respond to automated update issues
- Test updated versions before merging
- Monitor build performance and optimize as needed