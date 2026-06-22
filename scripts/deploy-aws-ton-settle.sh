#!/usr/bin/env bash
# deploy-aws-ton-settle.sh — SAM deploy for TON settle engine (us-west-2)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="${ROOT}/deploy/aws/ton-settle-engine"
STACK="${STACK_NAME:-yieldswarm-ton-settle}"
REGION="${AWS_REGION:-us-west-2}"

cd "$ENGINE"
command -v sam >/dev/null 2>&1 || { echo "Install AWS SAM CLI: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html" >&2; exit 1; }

npm ci --omit=dev
sam build
sam deploy \
  --stack-name "$STACK" \
  --region "$REGION" \
  --capabilities CAPABILITY_IAM \
  --resolve-s3 \
  --no-fail-on-empty-changeset \
  ${CORS_ORIGIN:+--parameter-overrides CorsOrigin="${CORS_ORIGIN}"} \
  ${TON_RPC_URL:+--parameter-overrides TonRpcUrl="${TON_RPC_URL}"}

echo "Allocate URL:"
aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='AllocateEndpoint'].OutputValue" --output text
