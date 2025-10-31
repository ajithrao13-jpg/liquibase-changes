# K6 Report Generation for Lambda and BigQuery Metrics

## Overview

This guide explains how to capture AWS Lambda and GCP BigQuery metrics in K6 test reports, allowing you to view performance data in HTML, JSON, CSV, or other formats alongside your standard K6 metrics.

## K6 Report Output Options

K6 supports multiple output formats for test results:

1. **HTML Reports** - Visual dashboards with charts
2. **JSON Output** - Structured data for analysis
3. **CSV Output** - Spreadsheet-friendly format
4. **InfluxDB** - Time-series database integration
5. **Grafana Cloud** - Real-time visualization
6. **CloudWatch** - AWS native monitoring

---

## 1. HTML Reports with Lambda and BigQuery Metrics

### Install K6 HTML Report Extension

```bash
# Install k6-reporter for HTML reports
npm install -g k6-to-html

# Or use xk6 to build k6 with HTML reporter
xk6 build --with github.com/benc-uk/k6-reporter@latest
```

### Lambda Metrics in HTML Report

```javascript
// k6-test-scripts/lambda-with-html-report.js
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js";
import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.1/index.js";
import { AWSConfig } from 'k6/x/aws';
import { Lambda } from 'k6/x/aws/lambda';
import { Trend, Rate, Counter, Gauge } from 'k6/metrics';

// Lambda-specific custom metrics
const lambdaInvocationDuration = new Trend('lambda_invocation_duration', true);
const lambdaSuccessRate = new Rate('lambda_success_rate');
const lambdaInvocations = new Counter('lambda_invocations');
const lambdaColdStarts = new Counter('lambda_cold_starts');
const lambdaErrors = new Counter('lambda_errors');
const lambdaMemoryUsed = new Trend('lambda_memory_used_mb');
const lambdaBilledDuration = new Trend('lambda_billed_duration_ms');
const lambdaConcurrentExecutions = new Gauge('lambda_concurrent_executions');

export const options = {
    stages: [
        { duration: '2m', target: 50 },
        { duration: '5m', target: 100 },
        { duration: '2m', target: 0 },
    ],
    thresholds: {
        'lambda_invocation_duration': ['p(95)<3000', 'p(99)<5000'],
        'lambda_success_rate': ['rate>0.99'],
        'lambda_errors': ['count<10'],
    },
};

const awsConfig = new AWSConfig({
    region: __ENV.AWS_REGION || 'us-east-1',
});

const lambda = new Lambda(awsConfig);

export default function () {
    const startTime = Date.now();
    
    const result = lambda.invoke({
        FunctionName: __ENV.LAMBDA_FUNCTION_NAME,
        InvocationType: 'RequestResponse',
        Payload: JSON.stringify({
            requestId: `req-${__VU}-${__ITER}`,
            timestamp: Date.now(),
        }),
    });

    const duration = Date.now() - startTime;
    
    // Track Lambda metrics
    lambdaInvocationDuration.add(duration);
    lambdaInvocations.add(1);
    
    const success = result.StatusCode === 200 && !result.FunctionError;
    lambdaSuccessRate.add(success);
    
    if (!success) {
        lambdaErrors.add(1);
    }
    
    // Extract Lambda metadata from response
    if (result.Payload) {
        try {
            const responseData = JSON.parse(result.Payload);
            
            // Track memory and duration if Lambda returns these values
            if (responseData.memoryUsed) {
                lambdaMemoryUsed.add(responseData.memoryUsed);
            }
            if (responseData.billedDuration) {
                lambdaBilledDuration.add(responseData.billedDuration);
            }
        } catch (e) {
            // Ignore parse errors
        }
    }
    
    // Cold start detection
    if (duration > 1000) {
        lambdaColdStarts.add(1);
    }
    
    lambdaConcurrentExecutions.add(__VU);
}

export function handleSummary(data) {
    // Extract Lambda metrics for the report
    const lambdaMetrics = {
        invocation_duration: {
            avg: data.metrics.lambda_invocation_duration?.values?.avg || 0,
            min: data.metrics.lambda_invocation_duration?.values?.min || 0,
            max: data.metrics.lambda_invocation_duration?.values?.max || 0,
            p50: data.metrics.lambda_invocation_duration?.values?.['p(50)'] || 0,
            p95: data.metrics.lambda_invocation_duration?.values?.['p(95)'] || 0,
            p99: data.metrics.lambda_invocation_duration?.values?.['p(99)'] || 0,
        },
        success_rate: (data.metrics.lambda_success_rate?.values?.rate * 100 || 0).toFixed(2) + '%',
        total_invocations: data.metrics.lambda_invocations?.values?.count || 0,
        cold_starts: data.metrics.lambda_cold_starts?.values?.count || 0,
        errors: data.metrics.lambda_errors?.values?.count || 0,
        cold_start_percentage: ((data.metrics.lambda_cold_starts?.values?.count || 0) / 
                                 (data.metrics.lambda_invocations?.values?.count || 1) * 100).toFixed(2) + '%',
    };

    return {
        'summary.html': htmlReport(data, { 
            title: 'Lambda Performance Test Report',
            description: `Test Run: ${__ENV.TEST_RUN_ID || 'default'}`,
        }),
        'summary.json': JSON.stringify({
            ...data,
            lambda_metrics: lambdaMetrics,
        }, null, 2),
        stdout: textSummary(data, { indent: ' ', enableColors: true }) + 
                '\n\nLambda Metrics:\n' + 
                JSON.stringify(lambdaMetrics, null, 2),
    };
}
```

### BigQuery Metrics in HTML Report

```javascript
// k6-test-scripts/bigquery-with-html-report.js
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js";
import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.1/index.js";
import http from 'k6/http';
import { check } from 'k6';
import { Trend, Rate, Counter, Gauge } from 'k6/metrics';

// BigQuery-specific custom metrics
const bqInsertDuration = new Trend('bigquery_insert_duration', true);
const bqInsertSuccess = new Rate('bigquery_insert_success');
const bqRowsInserted = new Counter('bigquery_rows_inserted');
const bqInsertErrors = new Counter('bigquery_insert_errors');
const bqBytesInserted = new Counter('bigquery_bytes_inserted');
const bqQuotaErrors = new Counter('bigquery_quota_errors');
const bqValidationErrors = new Counter('bigquery_validation_errors');
const bqCurrentRPS = new Gauge('bigquery_current_rps');

export const options = {
    stages: [
        { duration: '2m', target: 100 },
        { duration: '5m', target: 500 },
        { duration: '2m', target: 0 },
    ],
    thresholds: {
        'bigquery_insert_duration': ['p(95)<1000', 'p(99)<2000'],
        'bigquery_insert_success': ['rate>0.999'],
        'bigquery_insert_errors': ['count<100'],
    },
};

export default function () {
    const insertId = `insert-${__VU}-${__ITER}-${Date.now()}`;
    
    const rows = [{
        insertId: insertId,
        json: {
            timestamp: new Date().toISOString(),
            tenant_id: `tenant-${Math.floor(Math.random() * 10)}`,
            data: generateTestData(),
        },
    }];

    const payload = JSON.stringify({
        kind: 'bigquery#tableDataInsertAllRequest',
        rows: rows,
    });

    const url = `https://bigquery.googleapis.com/bigquery/v2/projects/${__ENV.GCP_PROJECT_ID}/datasets/${__ENV.BQ_DATASET}/tables/${__ENV.BQ_TABLE}/insertAll`;
    
    const startTime = Date.now();
    const res = http.post(url, payload, {
        headers: {
            'Authorization': `Bearer ${__ENV.GCP_ACCESS_TOKEN}`,
            'Content-Type': 'application/json',
        },
    });
    const duration = Date.now() - startTime;

    bqInsertDuration.add(duration);
    bqCurrentRPS.add(__ITER);

    const success = check(res, {
        'status is 200': (r) => r.status === 200,
        'no insert errors': (r) => {
            const body = r.json();
            return !body.insertErrors || body.insertErrors.length === 0;
        },
    });

    bqInsertSuccess.add(success);

    if (success) {
        bqRowsInserted.add(rows.length);
        bqBytesInserted.add(payload.length);
    } else {
        bqInsertErrors.add(1);
        
        // Track specific error types
        const body = res.json();
        if (body.error && body.error.code === 403) {
            bqQuotaErrors.add(1);
        }
        if (body.insertErrors) {
            bqValidationErrors.add(body.insertErrors.length);
        }
    }
}

function generateTestData() {
    return {
        message: 'Test log entry',
        level: 'INFO',
        metadata: {
            source: 'k6-test',
            size_bytes: Math.floor(Math.random() * 5000),
        },
    };
}

export function handleSummary(data) {
    // Extract BigQuery metrics
    const bqMetrics = {
        insert_duration: {
            avg: data.metrics.bigquery_insert_duration?.values?.avg || 0,
            min: data.metrics.bigquery_insert_duration?.values?.min || 0,
            max: data.metrics.bigquery_insert_duration?.values?.max || 0,
            p50: data.metrics.bigquery_insert_duration?.values?.['p(50)'] || 0,
            p95: data.metrics.bigquery_insert_duration?.values?.['p(95)'] || 0,
            p99: data.metrics.bigquery_insert_duration?.values?.['p(99)'] || 0,
        },
        success_rate: (data.metrics.bigquery_insert_success?.values?.rate * 100 || 0).toFixed(2) + '%',
        total_rows_inserted: data.metrics.bigquery_rows_inserted?.values?.count || 0,
        total_bytes_inserted: data.metrics.bigquery_bytes_inserted?.values?.count || 0,
        insert_errors: data.metrics.bigquery_insert_errors?.values?.count || 0,
        quota_errors: data.metrics.bigquery_quota_errors?.values?.count || 0,
        validation_errors: data.metrics.bigquery_validation_errors?.values?.count || 0,
        rows_per_second: ((data.metrics.bigquery_rows_inserted?.values?.count || 0) / 
                          (data.state.testRunDurationMs / 1000)).toFixed(2),
    };

    // Calculate cost estimate
    const totalGB = (bqMetrics.total_bytes_inserted / (1024 * 1024 * 1024)).toFixed(4);
    const estimatedCost = (totalGB * 1024 * 0.01 / 200).toFixed(4); // $0.01 per 200MB

    return {
        'summary.html': htmlReport(data, { 
            title: 'BigQuery Performance Test Report',
            description: `Test Run: ${__ENV.TEST_RUN_ID || 'default'}`,
        }),
        'summary.json': JSON.stringify({
            ...data,
            bigquery_metrics: bqMetrics,
            cost_estimate: {
                total_gb: totalGB,
                estimated_cost_usd: estimatedCost,
            },
        }, null, 2),
        stdout: textSummary(data, { indent: ' ', enableColors: true }) + 
                '\n\nBigQuery Metrics:\n' + 
                JSON.stringify(bqMetrics, null, 2) + 
                '\n\nEstimated Cost: $' + estimatedCost,
    };
}
```

---

## 2. Combined Lambda + BigQuery Report

For end-to-end pipeline testing, combine both sets of metrics:

```javascript
// k6-test-scripts/combined-pipeline-report.js
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js";
import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.1/index.js";
import http from 'k6/http';
import { check } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';

// Lambda metrics
const lambdaDuration = new Trend('lambda_duration', true);
const lambdaSuccess = new Rate('lambda_success');
const lambdaInvocations = new Counter('lambda_invocations');

// BigQuery metrics
const bqInsertDuration = new Trend('bigquery_insert_duration', true);
const bqInsertSuccess = new Rate('bigquery_insert_success');
const bqRowsInserted = new Counter('bigquery_rows_inserted');

// Pipeline metrics
const endToEndLatency = new Trend('e2e_pipeline_latency', true);
const pipelineSuccess = new Rate('pipeline_success');

export const options = {
    scenarios: {
        pipeline_test: {
            executor: 'constant-vus',
            vus: 50,
            duration: '10m',
        },
    },
};

export default function () {
    const traceId = `trace-${__VU}-${__ITER}`;
    const pipelineStart = Date.now();
    
    // Step 1: Invoke Lambda (Log Forwarder)
    const lambdaStart = Date.now();
    const lambdaRes = invokeLambda(traceId);
    const lambdaDur = Date.now() - lambdaStart;
    
    lambdaDuration.add(lambdaDur);
    lambdaInvocations.add(1);
    lambdaSuccess.add(lambdaRes.success);
    
    // Step 2: Insert to BigQuery (after processing)
    const bqStart = Date.now();
    const bqRes = insertToBigQuery(traceId);
    const bqDur = Date.now() - bqStart;
    
    bqInsertDuration.add(bqDur);
    bqInsertSuccess.add(bqRes.success);
    if (bqRes.success) {
        bqRowsInserted.add(1);
    }
    
    // Calculate end-to-end latency
    const e2eDuration = Date.now() - pipelineStart;
    endToEndLatency.add(e2eDuration);
    
    const overallSuccess = lambdaRes.success && bqRes.success;
    pipelineSuccess.add(overallSuccess);
}

function invokeLambda(traceId) {
    // Lambda invocation logic
    const res = http.post(
        __ENV.LAMBDA_ENDPOINT,
        JSON.stringify({ traceId }),
        { headers: { 'Content-Type': 'application/json' } }
    );
    return { success: res.status === 200 };
}

function insertToBigQuery(traceId) {
    // BigQuery insert logic
    const res = http.post(
        `https://bigquery.googleapis.com/bigquery/v2/projects/${__ENV.GCP_PROJECT_ID}/datasets/${__ENV.BQ_DATASET}/tables/${__ENV.BQ_TABLE}/insertAll`,
        JSON.stringify({
            rows: [{
                insertId: traceId,
                json: { traceId, timestamp: new Date().toISOString() },
            }],
        }),
        {
            headers: {
                'Authorization': `Bearer ${__ENV.GCP_ACCESS_TOKEN}`,
                'Content-Type': 'application/json',
            },
        }
    );
    return { success: res.status === 200 };
}

export function handleSummary(data) {
    const report = {
        test_info: {
            test_run_id: __ENV.TEST_RUN_ID || 'default',
            duration: data.state.testRunDurationMs / 1000,
            timestamp: new Date().toISOString(),
        },
        lambda_metrics: {
            total_invocations: data.metrics.lambda_invocations?.values?.count || 0,
            success_rate: ((data.metrics.lambda_success?.values?.rate || 0) * 100).toFixed(2) + '%',
            duration_avg: (data.metrics.lambda_duration?.values?.avg || 0).toFixed(2),
            duration_p95: (data.metrics.lambda_duration?.values?.['p(95)'] || 0).toFixed(2),
            duration_p99: (data.metrics.lambda_duration?.values?.['p(99)'] || 0).toFixed(2),
        },
        bigquery_metrics: {
            total_rows_inserted: data.metrics.bigquery_rows_inserted?.values?.count || 0,
            success_rate: ((data.metrics.bigquery_insert_success?.values?.rate || 0) * 100).toFixed(2) + '%',
            insert_duration_avg: (data.metrics.bigquery_insert_duration?.values?.avg || 0).toFixed(2),
            insert_duration_p95: (data.metrics.bigquery_insert_duration?.values?.['p(95)'] || 0).toFixed(2),
            insert_duration_p99: (data.metrics.bigquery_insert_duration?.values?.['p(99)'] || 0).toFixed(2),
        },
        pipeline_metrics: {
            success_rate: ((data.metrics.pipeline_success?.values?.rate || 0) * 100).toFixed(2) + '%',
            e2e_latency_avg: (data.metrics.e2e_pipeline_latency?.values?.avg || 0).toFixed(2),
            e2e_latency_p95: (data.metrics.e2e_pipeline_latency?.values?.['p(95)'] || 0).toFixed(2),
            e2e_latency_p99: (data.metrics.e2e_pipeline_latency?.values?.['p(99)'] || 0).toFixed(2),
        },
    };

    return {
        'pipeline-report.html': htmlReport(data, {
            title: 'Multi-Cloud Pipeline Performance Report',
            description: 'AWS Lambda + GCP BigQuery End-to-End Test',
        }),
        'pipeline-report.json': JSON.stringify(report, null, 2),
        'stdout': textSummary(data, { indent: ' ', enableColors: true }) + 
                  '\n\n=== Pipeline Metrics ===\n' + 
                  JSON.stringify(report, null, 2),
    };
}
```

---

## 3. Running Tests and Generating Reports

### Generate HTML Report

```bash
# Lambda test with HTML report
k6 run --out json=lambda-results.json lambda-with-html-report.js
k6-to-html lambda-results.json -o lambda-report.html

# BigQuery test with HTML report
k6 run --out json=bq-results.json bigquery-with-html-report.js
k6-to-html bq-results.json -o bigquery-report.html

# Combined pipeline test
k6 run combined-pipeline-report.js
# HTML report is automatically generated in handleSummary()
```

### Generate JSON Report with Custom Metrics

```bash
# Lambda metrics to JSON
k6 run --out json=lambda-metrics.json lambda-with-html-report.js

# BigQuery metrics to JSON
k6 run --out json=bigquery-metrics.json bigquery-with-html-report.js

# View formatted JSON
cat lambda-metrics.json | jq '.metrics | with_entries(select(.key | startswith("lambda_")))'
cat bigquery-metrics.json | jq '.metrics | with_entries(select(.key | startswith("bigquery_")))'
```

### Generate CSV Report

```bash
# Custom script to convert JSON to CSV
cat lambda-metrics.json | jq -r '
  .metrics | 
  to_entries | 
  map(select(.key | startswith("lambda_"))) | 
  map([.key, .value.values.avg, .value.values.min, .value.values.max, .value.values["p(95)"], .value.values["p(99)"]]) | 
  ["Metric", "Avg", "Min", "Max", "P95", "P99"], .[] | 
  @csv
' > lambda-metrics.csv
```

---

## 4. Export to CloudWatch

Send Lambda and BigQuery metrics to AWS CloudWatch:

```javascript
// In your K6 script
import { CloudWatch } from 'k6/x/cloudwatch';

const cloudwatch = new CloudWatch({ region: 'us-east-1' });

export function handleSummary(data) {
    // Send Lambda metrics to CloudWatch
    cloudwatch.putMetricData({
        Namespace: 'K6/PerformanceTests',
        MetricData: [
            {
                MetricName: 'LambdaInvocationDuration',
                Value: data.metrics.lambda_invocation_duration?.values?.avg || 0,
                Unit: 'Milliseconds',
                Dimensions: [
                    { Name: 'TestType', Value: 'LoadTest' },
                    { Name: 'Component', Value: 'Lambda' },
                ],
            },
            {
                MetricName: 'LambdaSuccessRate',
                Value: (data.metrics.lambda_success_rate?.values?.rate || 0) * 100,
                Unit: 'Percent',
                Dimensions: [
                    { Name: 'TestType', Value: 'LoadTest' },
                    { Name: 'Component', Value: 'Lambda' },
                ],
            },
        ],
    });

    // Send BigQuery metrics to CloudWatch
    cloudwatch.putMetricData({
        Namespace: 'K6/PerformanceTests',
        MetricData: [
            {
                MetricName: 'BigQueryInsertDuration',
                Value: data.metrics.bigquery_insert_duration?.values?.avg || 0,
                Unit: 'Milliseconds',
                Dimensions: [
                    { Name: 'TestType', Value: 'LoadTest' },
                    { Name: 'Component', Value: 'BigQuery' },
                ],
            },
            {
                MetricName: 'BigQuerySuccessRate',
                Value: (data.metrics.bigquery_insert_success?.values?.rate || 0) * 100,
                Unit: 'Percent',
                Dimensions: [
                    { Name: 'TestType', Value: 'LoadTest' },
                    { Name: 'Component', Value: 'BigQuery' },
                ],
            },
        ],
    });

    return {
        'stdout': 'Metrics sent to CloudWatch',
    };
}
```

---

## 5. Export to InfluxDB + Grafana

For real-time visualization:

```bash
# Start InfluxDB
docker run -d -p 8086:8086 influxdb:2.0

# Run K6 test with InfluxDB output
k6 run --out influxdb=http://localhost:8086/k6db \
       -e INFLUXDB_DB=k6 \
       lambda-with-html-report.js

# Create Grafana dashboard to visualize lambda_ and bigquery_ metrics
```

**Grafana Dashboard Query Examples:**

```sql
-- Lambda invocation duration (P95)
SELECT percentile("lambda_invocation_duration", 95) 
FROM "k6" 
WHERE time > now() - 1h 
GROUP BY time(1m)

-- BigQuery insert success rate
SELECT mean("bigquery_insert_success") * 100 
FROM "k6" 
WHERE time > now() - 1h 
GROUP BY time(1m)
```

---

## 6. Complete Example: End-to-End Report

```bash
#!/bin/bash
# run-pipeline-test-with-reports.sh

echo "Running Multi-Cloud Pipeline Performance Test..."

# Set environment variables
export AWS_REGION="us-east-1"
export LAMBDA_FUNCTION_NAME="log-forwarder"
export GCP_PROJECT_ID="my-project"
export BQ_DATASET="logs"
export BQ_TABLE="application_logs"
export TEST_RUN_ID="test-$(date +%Y%m%d-%H%M%S)"

# Run K6 test
k6 run \
  --out json=results/${TEST_RUN_ID}.json \
  --out influxdb=http://localhost:8086/k6db \
  combined-pipeline-report.js

# Generate HTML report
echo "Generating HTML report..."
k6-to-html results/${TEST_RUN_ID}.json -o reports/${TEST_RUN_ID}.html

# Extract Lambda metrics
echo "Extracting Lambda metrics..."
cat results/${TEST_RUN_ID}.json | jq '.metrics | with_entries(select(.key | startswith("lambda_")))' > reports/${TEST_RUN_ID}-lambda.json

# Extract BigQuery metrics
echo "Extracting BigQuery metrics..."
cat results/${TEST_RUN_ID}.json | jq '.metrics | with_entries(select(.key | startswith("bigquery_")))' > reports/${TEST_RUN_ID}-bigquery.json

# Extract pipeline metrics
echo "Extracting Pipeline metrics..."
cat results/${TEST_RUN_ID}.json | jq '.metrics | with_entries(select(.key | startswith("e2e_") or .key | startswith("pipeline_")))' > reports/${TEST_RUN_ID}-pipeline.json

echo "Reports generated in reports/ directory:"
echo "  - ${TEST_RUN_ID}.html (Full HTML report)"
echo "  - ${TEST_RUN_ID}-lambda.json (Lambda metrics)"
echo "  - ${TEST_RUN_ID}-bigquery.json (BigQuery metrics)"
echo "  - ${TEST_RUN_ID}-pipeline.json (Pipeline metrics)"
```

---

## 7. Sample Report Structure

The generated reports will include:

### HTML Report Sections

1. **Test Overview**
   - Test duration
   - Total VUs
   - Success rate

2. **Lambda Metrics**
   - Invocation duration (avg, p50, p95, p99)
   - Success rate
   - Cold start percentage
   - Error count
   - Memory usage
   - Concurrent executions

3. **BigQuery Metrics**
   - Insert duration (avg, p50, p95, p99)
   - Success rate
   - Rows inserted
   - Bytes inserted
   - Quota errors
   - Validation errors
   - Estimated cost

4. **Pipeline Metrics** (if combined test)
   - End-to-end latency
   - Overall success rate
   - Component breakdown

5. **Charts**
   - Time-series graphs for all metrics
   - Success rate over time
   - Latency percentiles
   - Error distribution

### JSON Report Structure

```json
{
  "test_info": {
    "test_run_id": "test-20241030-123456",
    "duration": 600,
    "timestamp": "2024-10-30T12:34:56Z"
  },
  "lambda_metrics": {
    "total_invocations": 30000,
    "success_rate": "99.95%",
    "duration_avg": 245.67,
    "duration_p95": 456.23,
    "duration_p99": 789.12,
    "cold_starts": 150,
    "cold_start_percentage": "0.50%",
    "errors": 15
  },
  "bigquery_metrics": {
    "total_rows_inserted": 29985,
    "success_rate": "99.98%",
    "insert_duration_avg": 567.34,
    "insert_duration_p95": 890.45,
    "insert_duration_p99": 1234.56,
    "total_bytes_inserted": 14992500,
    "rows_per_second": 49.975,
    "estimated_cost_usd": "0.7496"
  },
  "pipeline_metrics": {
    "success_rate": "99.93%",
    "e2e_latency_avg": 1523.45,
    "e2e_latency_p95": 2456.78,
    "e2e_latency_p99": 3890.12
  }
}
```

---

## 8. Best Practices

1. **Use Descriptive Metric Names**: Prefix with component (lambda_, bigquery_, pipeline_)
2. **Track Both Success and Failure**: Monitor error rates alongside success metrics
3. **Include Percentiles**: Always track p95 and p99 for latency metrics
4. **Add Metadata**: Include test run ID, environment, and configuration in reports
5. **Automate Report Generation**: Use scripts to generate reports automatically
6. **Store Historical Data**: Keep reports for trend analysis
7. **Set Up Alerts**: Configure thresholds and alerts based on metrics
8. **Use Tags**: Tag metrics by component, environment, test type
9. **Export to Multiple Formats**: JSON for analysis, HTML for viewing, CSV for spreadsheets
10. **Include Cost Estimates**: Calculate and report estimated AWS/GCP costs

---

## Summary

With these configurations, you can now:

✅ **Capture Lambda metrics** in K6 reports (duration, success rate, cold starts, errors)  
✅ **Capture BigQuery metrics** in K6 reports (insert duration, success rate, rows, bytes, cost)  
✅ **Generate HTML reports** with visual charts and tables  
✅ **Export to JSON/CSV** for further analysis  
✅ **Send metrics to CloudWatch** for AWS-native monitoring  
✅ **Visualize in Grafana** with real-time dashboards  
✅ **Combine multi-component metrics** in unified reports  

All Lambda and BigQuery metrics are now visible in your K6 test reports! 🎉
