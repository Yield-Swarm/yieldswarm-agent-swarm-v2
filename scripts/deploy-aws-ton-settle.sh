#!/usr/bin/env bash
# deploy-aws-ton-settle.sh — SAM deploy + optional CloudWatch dashboard
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="${ROOT}/deploy/aws/ton-settle-engine"
LAMBDA_SRC="${ROOT}/src/backend-lambda"
STACK="${STACK_NAME:-yieldswarm-ton-settle}"
REGION="${AWS_REGION:-us-west-2}"
ENV_NAME="${ENVIRONMENT_NAME:-production}"

command -v sam >/dev/null 2>&1 || { echo "Install AWS SAM CLI" >&2; exit 1; }

cd "$LAMBDA_SRC"
npm ci --omit=dev

cd "$ENGINE"
npm ci --omit=dev
sam build --template-file template.yaml
sam deploy \
  --stack-name "$STACK" \
  --region "$REGION" \
  --capabilities CAPABILITY_IAM \
  --resolve-s3 \
  --no-fail-on-empty-changeset \
  --parameter-overrides \
    "EnvironmentName=${ENV_NAME}" \
    "CorsOrigin=${CORS_ORIGIN:-https://yieldswarm.crypto}" \
    "TonRpcUrl=${TON_RPC_URL:-https://toncenter.com/api/v2/jsonRPC}" \
    "PlayerSbtContract=${PLAYER_SBT_CONTRACT:-}"

CLAIM_URL="$(aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='ClaimEndpoint'].OutputValue" --output text)"
LAMBDA_FN="$(aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='LambdaFunctionName'].OutputValue" --output text)"

echo "Claim API: ${CLAIM_URL}"
echo "Lambda:    ${LAMBDA_FN}"

if [[ "${DEPLOY_TELEMETRY:-1}" == "1" ]]; then
  LAMBDA_FUNCTION_NAME="$LAMBDA_FN" AWS_REGION="$REGION" npm run telemetry
fi
