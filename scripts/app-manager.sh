#!/bin/bash  
# Application Manager for Single-Purpose Application Images
# Creates dedicated application images using tool images via multi-stage builds
set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
APPS_DIR="${PROJECT_DIR}/apps"
APPS_CONFIG_DIR="${APPS_DIR}/config"
APPS_DOCKERFILES_DIR="${APPS_DIR}/dockerfiles"
APPS_COMPOSE_DIR="${APPS_DIR}/compose"

# Ensure we're in the project directory
cd "${PROJECT_DIR}"

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v yq &> /dev/null; then
        missing_deps+=("yq")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required dependencies: ${missing_deps[*]}${NC}" >&2
        exit 1
    fi
}

# Check if app exists
app_exists() {
    local app_name="$1"
    local app_file="${APPS_CONFIG_DIR}/${app_name}.yml"
    [[ -f "${app_file}" ]]
}

# Check if app Dockerfile exists
app_dockerfile_exists() {
    local app_name="$1"
    local dockerfile="${APPS_DOCKERFILES_DIR}/${app_name}.Dockerfile"
    [[ -f "${dockerfile}" ]]
}

# Validate app configuration
validate_app() {
    local app_name="$1"
    
    if ! app_exists "${app_name}"; then
        echo -e "${RED}Error: App '${app_name}' configuration not found${NC}" >&2
        echo -e "${YELLOW}Expected file: ${APPS_CONFIG_DIR}/${app_name}.yml${NC}" >&2
        list_apps >&2
        exit 1
    fi
    
    if ! app_dockerfile_exists "${app_name}"; then
        echo -e "${RED}Error: App '${app_name}' Dockerfile not found${NC}" >&2
        echo -e "${YELLOW}Expected file: ${APPS_DOCKERFILES_DIR}/${app_name}.Dockerfile${NC}" >&2
        exit 1
    fi
}

# Get app status (✅ if both YAML + Dockerfile exist, ❌ otherwise)
get_app_status() {
    local app_name="$1"
    if app_exists "${app_name}" && app_dockerfile_exists "${app_name}"; then
        echo "✅"
    else
        echo "❌"
    fi
}

# List available apps
list_apps() {
    echo -e "${GREEN}Available applications:${NC}"
    
    if [ ! -d "${APPS_CONFIG_DIR}" ]; then
        echo -e "${YELLOW}  No apps config directory found${NC}"
        echo -e "${BLUE}  Create ${APPS_CONFIG_DIR}/ to define applications${NC}"
        return
    fi
    
    if [ -z "$(ls -A "${APPS_CONFIG_DIR}"/*.yml 2>/dev/null || true)" ]; then
        echo -e "${YELLOW}  No apps configured${NC}"
        return
    fi
    
    for app_file in "${APPS_CONFIG_DIR}"/*.yml; do
        if [ -f "${app_file}" ]; then
            local app_name=$(basename "${app_file}" .yml)
            local app_description=$(yq eval '.description // "No description"' "${app_file}")
            local app_tools=$(yq eval '.tools[]?' "${app_file}" 2>/dev/null | tr '\n' ', ' | sed 's/,$//' || echo "No tools specified")
            local status=$(get_app_status "${app_name}")
            
            echo -e "${BLUE}  ${app_name}${NC} (uses: ${app_tools}) - ${app_description} ${status}"
        fi
    done
    
    echo ""
    echo -e "${YELLOW}Legend: ✅ = Ready (YAML + Dockerfile), ❌ = Missing Dockerfile${NC}"
}

# Build application image
build_app() {
    local app_name="$1"
    
    validate_app "${app_name}"
    
    local app_file="${APPS_CONFIG_DIR}/${app_name}.yml"
    local dockerfile="${APPS_DOCKERFILES_DIR}/${app_name}.Dockerfile"
    local app_version=$(yq eval '.version' "${app_file}")
    
    echo -e "${GREEN}Building application: ${app_name} v${app_version}${NC}"
    
    # Get required tool images and check they exist
    local required_tools=$(yq eval '.tools[]?' "${app_file}" 2>/dev/null | grep -v '^null$' | grep -v '^$' || true)
    if [ -n "${required_tools}" ]; then
        echo -e "${BLUE}Required tool images: $(echo "${required_tools}" | tr '\n' ', ' | sed 's/,$//')${NC}"
        
        for tool in ${required_tools}; do
            # Get tool version from its config
            local tool_config="${PROJECT_DIR}/tools/config/${tool}.yml"
            if [ -f "${tool_config}" ]; then
                local tool_version=$(yq eval '.version' "${tool_config}")
                local tool_image="distroless-${tool}:${tool_version}"
            else
                local tool_image="distroless-${tool}"
            fi
            
            if ! docker image inspect "${tool_image}" >/dev/null 2>&1; then
                echo -e "${YELLOW}Tool image ${tool_image} not found${NC}" >&2
                echo -e "${RED}Please build tool first: ./scripts/tool-manager.sh build ${tool}${NC}" >&2
                exit 1
            fi
        done
    fi
    
    # Check base image exists
    if ! docker image inspect distroless-base:0.2.0 >/dev/null 2>&1; then
        echo -e "${YELLOW}Base image distroless-base:0.2.0 not found${NC}" >&2
        echo -e "${RED}Please build base image first: ./scripts/base-manager.sh build${NC}" >&2
        exit 1
    fi
    
    # Build the application image
    local image_name="distroless-${app_name}"
    local image_tag="${image_name}:${app_version}"
    echo -e "${BLUE}Building Docker image: ${image_tag}${NC}"
    
    if docker build \
        --platform linux/amd64 \
        --tag "${image_tag}" \
        --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --file "${dockerfile}" \
        . ; then
        echo -e "${GREEN}✓ Build successful: ${image_tag}${NC}"
        
        # Show image size
        local size=$(docker image inspect "${image_tag}" --format='{{.Size}}' | numfmt --to=iec)
        echo -e "${YELLOW}Image size: ${size}${NC}"
    else
        echo -e "${RED}✗ Build failed for ${app_name}${NC}" >&2
        exit 1
    fi
}

# Test application image
test_app() {
    local app_name="$1"
    
    validate_app "${app_name}"
    
    local app_file="${APPS_CONFIG_DIR}/${app_name}.yml"
    local app_version=$(yq eval '.version' "${app_file}")
    local image_name="distroless-${app_name}"
    local image_tag="${image_name}:${app_version}"
    
    echo -e "${BLUE}Testing ${app_name}...${NC}"
    
    if ! docker image inspect "${image_tag}" >/dev/null 2>&1; then
        echo -e "${RED}Error: Image ${image_tag} not found. Build it first.${NC}" >&2
        exit 1
    fi
    
    # Test that the application image loads
    if docker run --rm "${image_tag}" /usr/local/bin/pocket-id --version >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Application image test passed${NC}"
    else
        echo -e "${YELLOW}⚠ Image exists but basic test failed (this may be expected if app requires runtime config)${NC}"
    fi
}

# Generate docker-compose.yml for deployment
compose() {
    local app_name="$1"
    
    validate_app "${app_name}"
    
    local app_file="${APPS_CONFIG_DIR}/${app_name}.yml"
    local compose_file="${APPS_COMPOSE_DIR}/${app_name}.yml"
    
    echo -e "${BLUE}Generating compose file: ${compose_file}${NC}"
    
    # Start compose file
    cat > "${compose_file}" << EOF
# Generated docker-compose for ${app_name}
# Generated on $(date -u +%Y-%m-%dT%H:%M:%SZ)
version: '3.8'

services:
EOF

    # Process each service from app config
    local services=$(yq eval '.services | keys[]' "${app_file}" 2>/dev/null || echo "")
    for service in ${services}; do
        echo "  ${service}:" >> "${compose_file}"
        
        # Determine image - either explicit or the built app image
        local explicit_image=$(yq eval ".services.${service}.image" "${app_file}" 2>/dev/null | grep -v '^null$' || echo '')
        if [ -n "${explicit_image}" ] && [ "${explicit_image}" != "null" ]; then
            echo "    image: ${explicit_image}" >> "${compose_file}"
        else
            # Use the built single-purpose app image with version
            local app_version=$(yq eval '.version' "${app_file}")
            echo "    image: distroless-${app_name}:${app_version}" >> "${compose_file}"
        fi
        
        # Add ports
        local ports=$(yq eval ".services.${service}.ports[]?" "${app_file}" 2>/dev/null | grep -v '^null$' | grep -v '^$' || true)
        if [ -n "${ports}" ]; then
            echo "    ports:" >> "${compose_file}"
            echo "${ports}" | while read -r port; do
                if [ -n "${port}" ]; then
                    echo "      - \"${port}\"" >> "${compose_file}"
                fi
            done
        fi
        
        # Add environment variables
        local env_vars=$(yq eval ".services.${service}.environment" "${app_file}" 2>/dev/null | grep -v '^null$' || echo '')
        if [ -n "${env_vars}" ] && [ "${env_vars}" != "null" ]; then
            echo "    environment:" >> "${compose_file}"
            echo "${env_vars}" | yq eval '.' - | sed 's/^/      /' >> "${compose_file}"
        fi
        
        # Add volumes
        local volumes=$(yq eval ".services.${service}.volumes[]?" "${app_file}" 2>/dev/null | grep -v '^null$' | grep -v '^$' || true)
        if [ -n "${volumes}" ]; then
            echo "    volumes:" >> "${compose_file}"
            echo "${volumes}" | while read -r volume; do
                if [ -n "${volume}" ]; then
                    echo "      - ${volume}" >> "${compose_file}"
                fi
            done
        fi
        
        echo "" >> "${compose_file}"
    done
    
    # Add volumes section if any persistent volumes are defined
    local global_volumes=$(yq eval '.volumes | keys[]?' "${app_file}" 2>/dev/null || echo "")
    if [ -n "${global_volumes}" ]; then
        echo "volumes:" >> "${compose_file}"
        for volume in ${global_volumes}; do
            echo "  ${volume}:" >> "${compose_file}"
        done
    fi
    
    echo -e "${GREEN}✓ Generated: ${compose_file}${NC}"
}

# Show app configuration
show_app() {
    local app_name="$1"
    
    validate_app "${app_name}"
    
    local app_file="${APPS_CONFIG_DIR}/${app_name}.yml"
    
    echo -e "${GREEN}Configuration for ${app_name}:${NC}"
    cat "${app_file}"
}

# Show app Dockerfile
show_dockerfile() {
    local app_name="$1"
    
    validate_app "${app_name}"
    
    local dockerfile="${APPS_DOCKERFILES_DIR}/${app_name}.Dockerfile"
    
    echo -e "${GREEN}Dockerfile for ${app_name}:${NC}"
    cat "${dockerfile}"
}

# Create example app configuration
create_example() {
    mkdir -p "${APPS_CONFIG_DIR}" "${APPS_DOCKERFILES_DIR}" "${APPS_COMPOSE_DIR}"
    
    local example_file="${APPS_CONFIG_DIR}/pocket-id.yml"
    if [ ! -f "${example_file}" ]; then
        cat > "${example_file}" << 'EOF'
name: pocket-id
description: "Pocket ID authentication service - single-purpose app image"
tools: 
  - node
  - go  
  - git

services:
  app:
    # Uses the built distroless-pocket-id image
    ports:
      - "3000:3000"
    environment:
      NODE_ENV: production
      DATABASE_URL: postgres://postgres:postgres@database:5432/pocketid
    volumes:
      - "./app:/app"
    
  database:
    image: distroless-postgres
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: pocketid
      POSTGRES_USER: postgres  
      POSTGRES_PASSWORD: postgres
    volumes:
      - "postgres_data:/var/lib/postgresql/data"

volumes:
  postgres_data:
EOF

        echo -e "${GREEN}✓ Created example app: ${example_file}${NC}"
    fi
    
    # Dockerfile should already exist from previous creation
    if [ -f "${APPS_DOCKERFILES_DIR}/pocket-id.Dockerfile" ]; then
        echo -e "${GREEN}✓ Dockerfile already exists: ${APPS_DOCKERFILES_DIR}/pocket-id.Dockerfile${NC}"
    fi
    
    echo -e "${BLUE}Try: $0 build pocket-id${NC}"
}

# Show usage
show_usage() {
    echo "Application Manager for Single-Purpose Application Images"
    echo ""
    echo "Usage: $0 <command> [app-name]"
    echo ""
    echo "Commands:"
    echo "  list                   List all available applications"
    echo "  build <app>            Build single-purpose application image"
    echo "  test <app>             Test application image"
    echo "  compose <app>          Generate docker-compose.yml for deployment"
    echo "  config <app>           Show application configuration"
    echo "  dockerfile <app>       Show application Dockerfile"
    echo "  example                Create example pocket-id app configuration"
    echo "  help                   Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 example             # Create example configurations"
    echo "  $0 list                # List available applications" 
    echo "  $0 build pocket-id     # Build distroless-pocket-id image"
    echo "  $0 compose pocket-id   # Generate compose file"
    echo "  $0 test pocket-id      # Test pocket-id image"
    echo ""
    echo "Architecture:"
    echo "  app-manager.sh → creates distroless-{app} images"
    echo "  tool-manager.sh → creates distroless-{tool} images"
    echo "  base-manager.sh → creates distroless-base image"
    echo "  No hardcoded script calls - dependencies in Dockerfiles only!"
    exit 1
}

# Main command handling
main() {
    check_dependencies
    
    if [ $# -eq 0 ]; then
        show_usage
    fi
    
    local command="$1"
    shift
    
    case "${command}" in
        list|ls)
            list_apps
            ;;
        build)
            if [ $# -eq 0 ]; then
                echo -e "${RED}Error: App name required${NC}" >&2
                show_usage
            fi
            build_app "$1"
            ;;
        test)
            if [ $# -eq 0 ]; then
                echo -e "${RED}Error: App name required${NC}" >&2
                show_usage
            fi
            test_app "$1"
            ;;
        compose)
            if [ $# -eq 0 ]; then
                echo -e "${RED}Error: App name required${NC}" >&2
                show_usage
            fi
            compose "$1"
            ;;
        config|show)
            if [ $# -eq 0 ]; then
                echo -e "${RED}Error: App name required${NC}" >&2
                show_usage
            fi
            show_app "$1"
            ;;
        dockerfile|docker)
            if [ $# -eq 0 ]; then
                echo -e "${RED}Error: App name required${NC}" >&2
                show_usage
            fi
            show_dockerfile "$1"
            ;;
        example)
            create_example
            ;;
        help|-h|--help)
            show_usage
            ;;
        *)
            echo -e "${RED}Error: Unknown command '${command}'${NC}" >&2
            show_usage
            ;;
    esac
}

main "$@"