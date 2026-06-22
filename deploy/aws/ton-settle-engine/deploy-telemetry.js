#!/usr/bin/env node
/**
 * Provision CloudWatch dashboard for TON MMORPG settle engine telemetry.
 * Usage: LAMBDA_FUNCTION_NAME=AuthoritativePoE-production node deploy-telemetry.js
 */
const { CloudWatchClient, PutDashboardCommand } = require('@aws-sdk/client-cloudwatch');

const region = process.env.AWS_REGION || 'us-west-2';
const lambdaName = process.env.LAMBDA_FUNCTION_NAME || 'AuthoritativePoE-production';
const apiName = process.env.HTTP_API_NAME || 'ton-mmorpg-production-backend';
const dashboardName = process.env.DASHBOARD_NAME || 'TON_MMORPG_Compute_Telemetry';

const client = new CloudWatchClient({ region });

const dashboardBody = {
  widgets: [
    {
      type: 'metric',
      x: 0,
      y: 0,
      width: 12,
      height: 6,
      properties: {
        metrics: [
          ['AWS/ApiGateway', 'Count', 'ApiName', apiName],
          ['.', '4XXError', '.', '.'],
          ['.', '5XXError', '.', '.'],
        ],
        period: 60,
        stat: 'Sum',
        region,
        title: 'API Gateway Invocation and Edge Anomaly Volumetrics',
      },
    },
    {
      type: 'metric',
      x: 12,
      y: 0,
      width: 12,
      height: 6,
      properties: {
        metrics: [
          ['AWS/Lambda', 'Duration', 'FunctionName', lambdaName, { stat: 'p99' }],
          ['.', 'Errors', '.', '.', { stat: 'Sum' }],
          ['.', 'Throttles', '.', '.', { stat: 'Sum' }],
        ],
        period: 60,
        region,
        title: 'Compute Execution Latency (p99) & Infrastructure Fault Rates',
      },
    },
    {
      type: 'metric',
      x: 0,
      y: 6,
      width: 24,
      height: 6,
      properties: {
        metrics: [['AWS/Lambda', 'Invocations', 'FunctionName', lambdaName]],
        period: 60,
        stat: 'Sum',
        region,
        title: 'Lambda Invocation Surges (stress quantification)',
      },
    },
  ],
};

async function run() {
  const response = await client.send(
    new PutDashboardCommand({
      DashboardName: dashboardName,
      DashboardBody: JSON.stringify(dashboardBody),
    }),
  );
  console.log('CloudWatch dashboard provisioned:', dashboardName, response.$metadata?.httpStatusCode);
}

run().catch((err) => {
  console.error('Telemetry sync failure:', err);
  process.exit(1);
});
