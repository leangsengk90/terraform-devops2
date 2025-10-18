#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Configuration
AWS_REGION=${AWS_REGION:-ap-southeast-1}
ECR_REPOSITORY_NAME=${ECR_REPOSITORY_NAME:-docker-swarm-app}

print_status "Docker Image Cleanup Utility"

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ $? -ne 0 ]; then
    print_warning "Cannot get AWS Account ID. Skipping ECR image cleanup."
    ECR_CLEANUP=false
else
    ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
    ECR_CLEANUP=true
fi

# Function to cleanup local Docker images
cleanup_local_images() {
    print_status "Cleaning up local Docker images..."
    
    # Get all local images related to our ECR repository
    if [ "$ECR_CLEANUP" = true ]; then
        LOCAL_ECR_IMAGES=$(docker images --format "table {{.Repository}}:{{.Tag}}" | grep "${ECR_REGISTRY}/${ECR_REPOSITORY_NAME}" | awk '{print $1}' || true)
        
        if [ -n "$LOCAL_ECR_IMAGES" ]; then
            print_status "Found local ECR images:"
            echo "$LOCAL_ECR_IMAGES"
            echo ""
            
            read -p "Remove these local ECR images? (y/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "$LOCAL_ECR_IMAGES" | while read -r image; do
                    if [ -n "$image" ]; then
                        print_status "Removing: $image"
                        docker rmi "$image" 2>/dev/null || print_warning "Failed to remove: $image"
                    fi
                done
                print_success "Local ECR images cleanup completed"
            else
                print_status "Skipped local ECR images cleanup"
            fi
        else
            print_status "No local ECR images found"
        fi
    fi
    
    # Clean up dangling images
    DANGLING_IMAGES=$(docker images -f "dangling=true" -q)
    if [ -n "$DANGLING_IMAGES" ]; then
        print_status "Found dangling images"
        read -p "Remove dangling images? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker rmi $DANGLING_IMAGES
            print_success "Dangling images removed"
        fi
    else
        print_status "No dangling images found"
    fi
    
    # Clean up unused images
    print_status "Docker system cleanup options:"
    echo "1. Remove unused images (docker image prune)"
    echo "2. Remove all unused containers, networks, images (docker system prune)"
    echo "3. Remove everything including volumes (docker system prune -a --volumes)"
    echo "4. Skip system cleanup"
    read -p "Choose option (1-4): " -n 1 -r
    echo ""
    
    case $REPLY in
        1)
            docker image prune -f
            print_success "Unused images removed"
            ;;
        2)
            docker system prune -f
            print_success "System cleanup completed"
            ;;
        3)
            read -p "This will remove ALL unused Docker data including volumes. Continue? (y/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                docker system prune -a -f --volumes
                print_success "Complete system cleanup completed"
            else
                print_status "Skipped complete cleanup"
            fi
            ;;
        *)
            print_status "Skipped system cleanup"
            ;;
    esac
}

# Function to list ECR images
list_ecr_images() {
    if [ "$ECR_CLEANUP" = true ]; then
        print_status "ECR Repository Images:"
        aws ecr describe-images --repository-name ${ECR_REPOSITORY_NAME} --region ${AWS_REGION} --query 'imageDetails[*].[imageTags[0],imageDigest,imagePushedAt]' --output table 2>/dev/null || print_warning "Failed to list ECR images"
    else
        print_warning "ECR access not available"
    fi
}

# Function to cleanup old ECR images
cleanup_ecr_images() {
    if [ "$ECR_CLEANUP" != true ]; then
        print_warning "ECR access not available"
        return
    fi
    
    print_status "ECR Image Cleanup"
    print_warning "This will permanently delete images from ECR!"
    
    list_ecr_images
    
    echo ""
    echo "Cleanup options:"
    echo "1. Delete images older than 30 days"
    echo "2. Keep only last 10 images"
    echo "3. Delete specific images (interactive)"
    echo "4. Skip ECR cleanup"
    read -p "Choose option (1-4): " -n 1 -r
    echo ""
    
    case $REPLY in
        1)
            print_status "Deleting images older than 30 days..."
            THIRTY_DAYS_AGO=$(date -d '30 days ago' '+%Y-%m-%d')
            aws ecr describe-images --repository-name ${ECR_REPOSITORY_NAME} --region ${AWS_REGION} --query "imageDetails[?imagePushedAt<'${THIRTY_DAYS_AGO}'].imageDigest" --output text | while read digest; do
                if [ -n "$digest" ] && [ "$digest" != "None" ]; then
                    print_status "Deleting image: $digest"
                    aws ecr batch-delete-image --repository-name ${ECR_REPOSITORY_NAME} --region ${AWS_REGION} --image-ids imageDigest=$digest
                fi
            done
            print_success "Old images cleanup completed"
            ;;
        2)
            print_status "Keeping only last 10 images..."
            aws ecr describe-images --repository-name ${ECR_REPOSITORY_NAME} --region ${AWS_REGION} --query 'sort_by(imageDetails,&imagePushedAt)[:-10].imageDigest' --output text | while read digest; do
                if [ -n "$digest" ] && [ "$digest" != "None" ]; then
                    print_status "Deleting image: $digest"
                    aws ecr batch-delete-image --repository-name ${ECR_REPOSITORY_NAME} --region ${AWS_REGION} --image-ids imageDigest=$digest
                fi
            done
            print_success "Image retention cleanup completed"
            ;;
        3)
            print_status "Interactive image deletion not implemented yet"
            print_warning "Use AWS CLI or console for specific image deletion"
            ;;
        *)
            print_status "Skipped ECR cleanup"
            ;;
    esac
}

# Main menu
echo ""
echo "Docker Image Cleanup Utility"
echo "=============================="
echo "1. Clean up local Docker images"
echo "2. List ECR images"
echo "3. Clean up ECR images"
echo "4. Full cleanup (local + ECR)"
echo "5. Exit"
echo ""
read -p "Choose option (1-5): " -n 1 -r
echo ""

case $REPLY in
    1)
        cleanup_local_images
        ;;
    2)
        list_ecr_images
        ;;
    3)
        cleanup_ecr_images
        ;;
    4)
        cleanup_local_images
        echo ""
        cleanup_ecr_images
        ;;
    *)
        print_status "Exiting cleanup utility"
        exit 0
        ;;
esac

print_success "🎉 Cleanup completed!"