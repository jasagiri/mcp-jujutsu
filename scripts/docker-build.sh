#!/bin/bash
# Docker build script for MCP-Jujutsu

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
TAG="latest"
PUSH=false
PLATFORMS=""
REGISTRY=""

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --tag TAG         Docker image tag (default: latest)"
    echo "  -p, --push            Push image to registry after build"
    echo "  -r, --registry REG    Docker registry (e.g., docker.io/username)"
    echo "  --platform PLATFORMS  Build for specific platforms (e.g., linux/amd64,linux/arm64)"
    echo "  -h, --help            Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -t v1.0.0"
    echo "  $0 -t latest -p -r docker.io/myuser"
    echo "  $0 --platform linux/amd64,linux/arm64 -t multiarch"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -p|--push)
            PUSH=true
            shift
            ;;
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        --platform)
            PLATFORMS="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Build image name
if [ -n "$REGISTRY" ]; then
    IMAGE_NAME="${REGISTRY}/mcp-jujutsu:${TAG}"
else
    IMAGE_NAME="mcp-jujutsu:${TAG}"
fi

echo -e "${GREEN}Building MCP-Jujutsu Docker image...${NC}"
echo -e "Image: ${YELLOW}${IMAGE_NAME}${NC}"

# Build command
BUILD_CMD="docker build"

# Add platform flag if specified
if [ -n "$PLATFORMS" ]; then
    BUILD_CMD="$BUILD_CMD --platform $PLATFORMS"
    echo -e "Platforms: ${YELLOW}${PLATFORMS}${NC}"
fi

# Add build arguments
BUILD_CMD="$BUILD_CMD -t $IMAGE_NAME ."

# Execute build
echo -e "${GREEN}Executing: ${BUILD_CMD}${NC}"
$BUILD_CMD

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Build successful!${NC}"
    
    # Show image info
    echo -e "\n${GREEN}Image information:${NC}"
    docker images | grep -E "REPOSITORY|${IMAGE_NAME%%:*}"
    
    # Push if requested
    if [ "$PUSH" = true ]; then
        if [ -z "$REGISTRY" ]; then
            echo -e "${RED}Error: Registry must be specified when pushing${NC}"
            exit 1
        fi
        
        echo -e "\n${GREEN}Pushing image to registry...${NC}"
        docker push $IMAGE_NAME
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Push successful!${NC}"
        else
            echo -e "${RED}✗ Push failed!${NC}"
            exit 1
        fi
    fi
    
    # Show usage examples
    echo -e "\n${GREEN}To run the image:${NC}"
    echo "  docker run -p 8080:8080 -v \$(pwd)/repos:/app/repos $IMAGE_NAME"
    echo ""
    echo -e "${GREEN}To run with docker-compose:${NC}"
    echo "  docker-compose --profile single up"
    
else
    echo -e "${RED}✗ Build failed!${NC}"
    exit 1
fi