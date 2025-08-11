#!/bin/bash
# Version Validation Script
# Checks consistency between YAML configs and Dockerfiles
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
TOOLS_CONFIG_DIR="${PROJECT_DIR}/tools/config"
TOOLS_DOCKERFILES_DIR="${PROJECT_DIR}/tools/dockerfiles"
APPS_CONFIG_DIR="${PROJECT_DIR}/apps/config"
APPS_DOCKERFILES_DIR="${PROJECT_DIR}/apps/dockerfiles"
BASE_CONFIG_DIR="${PROJECT_DIR}/base/config"
BASE_DOCKERFILES_DIR="${PROJECT_DIR}/base/dockerfiles"

cd "${PROJECT_DIR}"

# Global validation status
VALIDATION_ERRORS=0

# Validate tool versions
validate_tool_versions() {
    echo -e "${BLUE}Validating tool versions...${NC}"
    
    if [ ! -d "${TOOLS_CONFIG_DIR}" ]; then
        echo -e "${YELLOW}No tools config directory found${NC}"
        return
    fi
    
    for config_file in "${TOOLS_CONFIG_DIR}"/*.yml; do
        if [ -f "${config_file}" ]; then
            local tool_name=$(basename "${config_file}" .yml)
            local dockerfile="${TOOLS_DOCKERFILES_DIR}/${tool_name}.Dockerfile"
            
            if [ -f "${dockerfile}" ]; then
                # Get version from YAML config
                local yaml_version=$(grep '^version:' "${config_file}" | cut -d'"' -f2)
                
                # Get version from Dockerfile ARG
                local dockerfile_version=""
                if grep -q "ARG TOOL_VERSION=" "${dockerfile}"; then
                    dockerfile_version=$(grep "ARG TOOL_VERSION=" "${dockerfile}" | cut -d'=' -f2)
                fi
                
                if [ -n "${yaml_version}" ] && [ -n "${dockerfile_version}" ]; then
                    if [ "${yaml_version}" = "${dockerfile_version}" ]; then
                        echo -e "${GREEN}✓ ${tool_name}: ${yaml_version} (consistent)${NC}"
                    else
                        echo -e "${RED}✗ ${tool_name}: YAML=${yaml_version}, Dockerfile=${dockerfile_version}${NC}"
                        ((VALIDATION_ERRORS++))
                    fi
                elif [ -n "${yaml_version}" ]; then
                    echo -e "${YELLOW}⚠ ${tool_name}: YAML has version ${yaml_version}, but Dockerfile has no ARG TOOL_VERSION${NC}"
                    ((VALIDATION_ERRORS++))
                else
                    echo -e "${YELLOW}⚠ ${tool_name}: No version found in YAML${NC}"
                fi
            else
                echo -e "${RED}✗ ${tool_name}: No Dockerfile found${NC}"
                ((VALIDATION_ERRORS++))
            fi
        fi
    done
}

# Validate URL templates vs hardcoded URLs
validate_url_usage() {
    echo -e "${BLUE}Validating URL template usage...${NC}"
    
    for config_file in "${TOOLS_CONFIG_DIR}"/*.yml; do
        if [ -f "${config_file}" ]; then
            local tool_name=$(basename "${config_file}" .yml)
            local dockerfile="${TOOLS_DOCKERFILES_DIR}/${tool_name}.Dockerfile"
            
            if [ -f "${dockerfile}" ] && [ -f "${config_file}" ]; then
                # Check if YAML has URL template
                if grep -q 'url:.*{version}' "${config_file}"; then
                    local yaml_url=$(grep 'url:' "${config_file}" | cut -d'"' -f2)
                    local yaml_version=$(grep '^version:' "${config_file}" | cut -d'"' -f2)
                    local expected_url=$(echo "${yaml_url}" | sed "s/{version}/${yaml_version}/g")
                    
                    # Check if Dockerfile uses hardcoded URL
                    if grep -q "wget.*${yaml_version}" "${dockerfile}"; then
                        echo -e "${GREEN}✓ ${tool_name}: Using version-consistent URL${NC}"
                    else
                        echo -e "${YELLOW}⚠ ${tool_name}: YAML has URL template but Dockerfile may use hardcoded URL${NC}"
                        echo -e "    Expected: ${expected_url}"
                    fi
                fi
            fi
        fi
    done
}

# Validate multi-tools dockerfile versions
validate_multi_tools() {
    echo -e "${BLUE}Validating Dockerfile.multi-tools versions...${NC}"
    
    local multi_dockerfile="${PROJECT_DIR}/Dockerfile.multi-tools"
    if [ ! -f "${multi_dockerfile}" ]; then
        echo -e "${YELLOW}No Dockerfile.multi-tools found${NC}"
        return
    fi
    
    # Check each tool mentioned in multi-tools dockerfile
    for tool in git go node; do
        local tool_config="${TOOLS_CONFIG_DIR}/${tool}.yml"
        if [ -f "${tool_config}" ]; then
            local yaml_version=$(grep '^version:' "${tool_config}" | cut -d'"' -f2)
            
            # Check if multi-tools dockerfile uses this version
            case "${tool}" in
                git)
                    if grep -q "v${yaml_version}" "${multi_dockerfile}"; then
                        echo -e "${GREEN}✓ multi-tools ${tool}: ${yaml_version} (consistent)${NC}"
                    else
                        echo -e "${RED}✗ multi-tools ${tool}: Expected ${yaml_version} but not found in Dockerfile.multi-tools${NC}"
                        ((VALIDATION_ERRORS++))
                    fi
                    ;;
                go)
                    if grep -q "go${yaml_version}" "${multi_dockerfile}"; then
                        echo -e "${GREEN}✓ multi-tools ${tool}: ${yaml_version} (consistent)${NC}"
                    else
                        echo -e "${RED}✗ multi-tools ${tool}: Expected ${yaml_version} but not found in Dockerfile.multi-tools${NC}"
                        ((VALIDATION_ERRORS++))
                    fi
                    ;;
                node)
                    if grep -q "v${yaml_version}" "${multi_dockerfile}"; then
                        echo -e "${GREEN}✓ multi-tools ${tool}: ${yaml_version} (consistent)${NC}"
                    else
                        echo -e "${RED}✗ multi-tools ${tool}: Expected ${yaml_version} but not found in Dockerfile.multi-tools${NC}"
                        ((VALIDATION_ERRORS++))
                    fi
                    ;;
            esac
        fi
    done
}

# Validate app versions
validate_app_versions() {
    echo -e "${BLUE}Validating app versions...${NC}"
    
    if [ ! -d "${APPS_CONFIG_DIR}" ]; then
        echo -e "${YELLOW}No apps config directory found${NC}"
        return
    fi
    
    for config_file in "${APPS_CONFIG_DIR}"/*.yml; do
        if [ -f "${config_file}" ]; then
            local app_name=$(basename "${config_file}" .yml)
            local dockerfile="${APPS_DOCKERFILES_DIR}/${app_name}.Dockerfile"
            
            if [ -f "${dockerfile}" ]; then
                local yaml_version=$(grep '^version:' "${config_file}" | cut -d'"' -f2 2>/dev/null || echo "")
                
                if [ -n "${yaml_version}" ]; then
                    # Check if dockerfile references the app version (e.g., in git checkout)
                    if grep -q "v${yaml_version}" "${dockerfile}"; then
                        echo -e "${GREEN}✓ ${app_name}: ${yaml_version} (consistent)${NC}"
                    else
                        echo -e "${YELLOW}⚠ ${app_name}: YAML version ${yaml_version} not found in Dockerfile${NC}"
                    fi
                else
                    echo -e "${YELLOW}⚠ ${app_name}: No version found in YAML${NC}"
                fi
            else
                echo -e "${RED}✗ ${app_name}: No Dockerfile found${NC}"
                ((VALIDATION_ERRORS++))
            fi
        fi
    done
}

# Main validation function
main() {
    echo -e "${GREEN}Docker Distroless Version Validation${NC}"
    echo "======================================"
    
    validate_tool_versions
    echo ""
    validate_url_usage
    echo ""
    validate_multi_tools
    echo ""
    validate_app_versions
    echo ""
    
    if [ ${VALIDATION_ERRORS} -eq 0 ]; then
        echo -e "${GREEN}✓ All version validations passed!${NC}"
        exit 0
    else
        echo -e "${RED}✗ Found ${VALIDATION_ERRORS} validation error(s)${NC}"
        exit 1
    fi
}

main "$@"