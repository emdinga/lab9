#!/bin/bash

# Prompt the user for the User Pool Domain Prefix
read -p "Please enter the User Pool Domain Prefix (e.g., labbirdapp-####): " user_input

# Validate user input
if [[ -z "$user_input" ]]; then
    echo "Error: You must enter a value. Last attempt!"
    read -p "Please enter the User Pool Domain Prefix (e.g., labbirdapp-####): " user_input
if [[ -z "$user_input" ]]; then
    echo "Rerun the script and enter a value."
    exit 1
fi
fi

echo "You entered: $user_input"

# Fetch the first CloudFront domain name
CLOUDFRONT_DOMAIN=$(aws cloudfront list-distributions \
    --query "DistributionList.Items[0].DomainName" \
    --output text)

if [[ -z "$CLOUDFRONT_DOMAIN" ]]; then
    echo "Error: No CloudFront distributions found."
    exit 1
fi

# Check if the User Pool already exists
USER_POOL_ID=$(aws cognito-idp list-user-pools --max-results 10 \
    --query "UserPools[?Name=='bird_app'].Id" \
    --output text)

if [[ -z "$USER_POOL_ID" ]]; then
    echo "Creating User Pool..."
    USER_POOL_ID=$(aws cognito-idp create-user-pool \
        --pool-name bird_app \
        --policies '{"PasswordPolicy":{"MinimumLength":8,"RequireUppercase":false,"RequireLowercase":false,"RequireNumbers":false,"RequireSymbols":false,"TemporaryPasswordValidityDays":7}}' \
        --username-configuration '{"CaseSensitive":false}' \
        --auto-verified-attributes "email" \
        --account-recovery-setting '{"RecoveryMechanisms":[{"Priority":1,"Name":"verified_email"}]}' \
        --admin-create-user-config '{"AllowAdminCreateUserOnly":true}' \
        --email-verification-message "Your verification code is {####}" \
        --email-verification-subject "Verify your email for bird_app" \
        --query "Id" \
        --output text)
echo "Waiting for USER_POOL_ID to be created..."

# Loop until USER_POOL_ID is no longer "None"
while [ "$USER_POOL_ID" == "None" ]; do
   # Fetch the User Pool ID
  USER_POOL_ID=$(aws cognito-idp list-user-pools --max-results 1 --query "UserPools[?Name=='bird_app'].Id" --output text)
  # Check if it is still "None"
  if [ "$USER_POOL_ID" == "None" ]; then
    echo "USER_POOL_ID is still 'None'. Waiting for 10 seconds..."
    sleep 10
  else
    echo "USER_POOL_ID is now created: $USER_POOL_ID"
    break
  fi
done
echo "Created User Pool!"
else
    echo "User Pool already exists with ID: $USER_POOL_ID"
fi

# Wait for 30 seconds 
# sleep 30

# Check if the User Pool Domain already exists
EXISTING_DOMAIN=$(aws cognito-idp describe-user-pool-domain \
    --domain "$user_input" \
    --query "DomainDescription.Domain" \
    --output text 2>/dev/null)

if [[ "$EXISTING_DOMAIN" == "$user_input" ]]; then
    echo "User Pool Domain already exists: $user_input"
else
    echo "Creating User Pool Domain..."
    aws cognito-idp create-user-pool-domain \
        --domain "$user_input" \
        --user-pool-id "$USER_POOL_ID" || {
        echo "Error: Failed to create User Pool Domain.";            exit 1
    }

# Loop until EXISTING_DOMAIN is no longer "None"
while [ "$EXISTING_DOMAIN" == "None" ]; do
   # Fetch the App Client ID
  EXISTING_DOMAIN=$(aws cognito-idp describe-user-pool-domain \
    --domain "$user_input" \
    --query "DomainDescription.Domain" \
    --output text 2>/dev/null)
  # Check if it is still "None"
  if [ "$EXISTING_DOMAIN" == "None" ]; then
    echo "EXISTING_DOMAIN is still 'None'. Waiting for 10 seconds..."
    sleep 10
  else
    echo "User Pool Domain Prefix is now created: $EXISTING_DOMAIN"
    break
  fi
done
fi

# Check if the User Pool Client already exists
EXISTING_CLIENT=$(aws cognito-idp list-user-pool-clients \
    --user-pool-id "$USER_POOL_ID" \
    --query "UserPoolClients[?ClientName=='bird_app_client'].ClientId" \
    --output text)

if [[ -z "$EXISTING_CLIENT" ]]; then
    echo "Creating User Pool Client..."
    aws cognito-idp create-user-pool-client \
        --user-pool-id "$USER_POOL_ID" \
        --client-name bird_app_client \
        --generate-secret \
        --explicit-auth-flows "ALLOW_USER_PASSWORD_AUTH" "ALLOW_REFRESH_TOKEN_AUTH" \
        --supported-identity-providers "COGNITO" \
        --callback-urls "https://$CLOUDFRONT_DOMAIN/callback.html" \
        --logout-urls "https://$CLOUDFRONT_DOMAIN/logout.html" \
        --allowed-o-auth-flows "code" "implicit" \
        --allowed-o-auth-scopes "email" "openid" \
        --allowed-o-auth-flows-user-pool-client || {
        echo "Error: Failed to create User Pool Client."; exit 1
    }

# Loop until EXISTING_CLIENT is no longer "None"
while [[ -z "$EXISTING_CLIENT" ]]; do
   # Fetch the App Client ID
  EXISTING_CLIENT=$(aws cognito-idp list-user-pool-clients \
    --user-pool-id "$USER_POOL_ID" \
    --query "UserPoolClients[?ClientName=='bird_app_client'].ClientId" \
    --output text)
  # Check if no value
  if [[ -z "$EXISTING_CLIENT" ]]; then
    echo "EXISTING_CLIENT is not set. Waiting for 3 seconds..."
    sleep 3
  else
    echo "App Client ID is now created: $EXISTING_CLIENT"
    break
  fi
done 
else
    echo "User Pool Client already exists with ID: $EXISTING_CLIENT"
fi

# Wait for 3 seconds 
sleep 3

# Output results
echo -e "\nScript completed successfully!\n"
echo "CloudFront Domain: $CLOUDFRONT_DOMAIN"
echo "User Pool ID: $USER_POOL_ID"
echo "Cognito Domain Prefix: $EXISTING_DOMAIN"
echo "App Client ID: $EXISTING_CLIENT"
