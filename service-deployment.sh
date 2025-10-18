source .env
cd service-deployment
terraform init
terraform apply -auto-approve
if [ $? -eq 0 ]; then
    echo -e "\033[0;32m✅ Service deployed successfully\033[0m"
else
    echo -e "\033[0;31m❌ Service deployment failed\033[0m"
    exit 1
fi
cd ..       