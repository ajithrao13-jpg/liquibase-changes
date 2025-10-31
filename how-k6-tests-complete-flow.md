# How K6 Performs Load Testing on the Complete Multi-Cloud Pipeline

## Overview

This guide explains **how K6 actually performs load testing** across your complete integrated flow: **Kinesis → Lambda → BigQuery**. Understanding this mechanism is crucial for effective performance testing of your multi-cloud data pipeline.

---

## The Complete Flow

Your architecture consists of:

```
K6 Load Generator
    ↓ (sends test data)
AWS Kinesis Stream
    ↓ (triggers)
AWS Lambda Function
    ↓ (processes and forwards)
GCP BigQuery
    ↓ (stores data)
K6 Metrics Collection
```

---

## How K6 Tests the Complete Pipeline

### Approach 1: Direct End-to-End Testing

K6 sends data through the **entry point** (Kinesis) and then **validates** that it flows through all components to the **final destination** (BigQuery).

#### Step-by-Step Flow:

```javascript
// k6-test-scripts/end-to-end-pipeline-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';
import { AWSConfig } from 'k6/x/aws';
import { Kinesis } from 'k6/x/aws/kinesis';

// Metrics for the complete flow
const e2eLatency = new Trend('end_to_end_latency_ms');
const e2eSuccess = new Rate('end_to_end_success_rate');
const kinesisWriteTime = new Trend('kinesis_write_time_ms');
const lambdaProcessTime = new Trend('lambda_process_time_ms');
const bigqueryWriteTime = new Trend('bigquery_write_time_ms');
const recordsProcessed = new Counter('total_records_processed');

export const options = {
    scenarios: {
        end_to_end_load: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '2m', target: 50 },   // Ramp up
                { duration: '10m', target: 50 },  // Sustained load
                { duration: '2m', target: 0 },    // Ramp down
            ],
        },
    },
};

const awsConfig = new AWSConfig({
    region: __ENV.AWS_REGION || 'us-east-1',
});

const kinesis = new Kinesis(awsConfig);

export default function () {
    // Generate unique trace ID to track this record through the pipeline
    const traceId = `trace-${Date.now()}-${__VU}-${__ITER}`;
    const testStartTime = Date.now();
    
    // ============================================
    // STEP 1: Send payload to Kinesis
    // ============================================
    console.log(`[${traceId}] Step 1: Sending to Kinesis...`);
    
    const kinesisPayload = {
        traceId: traceId,
        timestamp: new Date().toISOString(),
        data: {
            tenant_id: `tenant-${Math.floor(Math.random() * 5) + 1}`,
            log_level: 'INFO',
            message: 'Test log message for end-to-end flow',
            source: 'k6-load-test',
        },
        // Add metadata for tracking
        k6_test: {
            vu: __VU,
            iteration: __ITER,
            test_run_id: __ENV.TEST_RUN_ID,
        },
    };
    
    const kinesisStart = Date.now();
    const kinesisResult = kinesis.putRecord({
        StreamName: __ENV.KINESIS_STREAM_NAME,
        Data: JSON.stringify(kinesisPayload),
        PartitionKey: traceId,
    });
    const kinesisDuration = Date.now() - kinesisStart;
    
    kinesisWriteTime.add(kinesisDuration);
    
    const kinesisSuccess = check(kinesisResult, {
        'kinesis write successful': (r) => r.SequenceNumber !== undefined,
    });
    
    if (!kinesisSuccess) {
        console.error(`[${traceId}] Failed to write to Kinesis`);
        e2eSuccess.add(0);
        return;
    }
    
    console.log(`[${traceId}] ✓ Kinesis write completed in ${kinesisDuration}ms`);
    
    // ============================================
    // STEP 2: Wait for Lambda to process
    // ============================================
    // Lambda is automatically triggered by Kinesis
    // We need to wait a reasonable amount of time for processing
    console.log(`[${traceId}] Step 2: Waiting for Lambda processing...`);
    
    // Wait for Lambda to process (typical processing time + buffer)
    sleep(2); // 2 seconds - adjust based on your Lambda execution time
    
    // ============================================
    // STEP 3: Verify data arrived in BigQuery
    // ============================================
    console.log(`[${traceId}] Step 3: Verifying in BigQuery...`);
    
    const bqVerifyStart = Date.now();
    const arrived = verifyInBigQuery(traceId);
    const bqVerifyDuration = Date.now() - bqVerifyStart;
    
    // Calculate total end-to-end latency
    const totalDuration = Date.now() - testStartTime;
    e2eLatency.add(totalDuration);
    
    if (arrived) {
        console.log(`[${traceId}] ✓ Record found in BigQuery! Total time: ${totalDuration}ms`);
        e2eSuccess.add(1);
        recordsProcessed.add(1);
        
        // Estimate Lambda processing time (total - kinesis - bigquery verify)
        const estimatedLambdaTime = totalDuration - kinesisDuration - bqVerifyDuration;
        lambdaProcessTime.add(estimatedLambdaTime);
    } else {
        console.error(`[${traceId}] ✗ Record NOT found in BigQuery after ${totalDuration}ms`);
        e2eSuccess.add(0);
    }
    
    // Small delay before next iteration
    sleep(1);
}

function verifyInBigQuery(traceId) {
    // Query BigQuery to check if the record arrived
    const query = `
        SELECT COUNT(*) as count
        FROM \`${__ENV.GCP_PROJECT_ID}.${__ENV.BQ_DATASET}.${__ENV.BQ_TABLE}\`
        WHERE JSON_EXTRACT_SCALAR(data, '$.traceId') = '${traceId}'
        AND _PARTITIONTIME >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
    `;
    
    const queryRequest = {
        query: query,
        useLegacySql: false,
        useQueryCache: false,
    };
    
    const res = http.post(
        `https://bigquery.googleapis.com/bigquery/v2/projects/${__ENV.GCP_PROJECT_ID}/queries`,
        JSON.stringify(queryRequest),
        {
            headers: {
                'Authorization': `Bearer ${__ENV.GCP_ACCESS_TOKEN}`,
                'Content-Type': 'application/json',
            },
            timeout: '10s',
        }
    );
    
    if (res.status === 200) {
        const body = res.json();
        if (body.jobComplete && body.rows && body.rows.length > 0) {
            const count = parseInt(body.rows[0].f[0].v);
            return count > 0;
        }
    }
    
    return false;
}

export function handleSummary(data) {
    const summary = {
        test_info: {
            test_run_id: __ENV.TEST_RUN_ID,
            duration_seconds: data.state.testRunDurationMs / 1000,
        },
        end_to_end_metrics: {
            total_attempts: data.metrics.end_to_end_success_rate?.values?.passes + 
                           data.metrics.end_to_end_success_rate?.values?.fails || 0,
            success_rate: ((data.metrics.end_to_end_success_rate?.values?.rate || 0) * 100).toFixed(2) + '%',
            records_processed: data.metrics.total_records_processed?.values?.count || 0,
            e2e_latency: {
                avg: (data.metrics.end_to_end_latency_ms?.values?.avg || 0).toFixed(2),
                min: (data.metrics.end_to_end_latency_ms?.values?.min || 0).toFixed(2),
                max: (data.metrics.end_to_end_latency_ms?.values?.max || 0).toFixed(2),
                p95: (data.metrics.end_to_end_latency_ms?.values?.['p(95)'] || 0).toFixed(2),
                p99: (data.metrics.end_to_end_latency_ms?.values?.['p(99)'] || 0).toFixed(2),
            },
        },
        component_breakdown: {
            kinesis_write: {
                avg: (data.metrics.kinesis_write_time_ms?.values?.avg || 0).toFixed(2),
                p95: (data.metrics.kinesis_write_time_ms?.values?.['p(95)'] || 0).toFixed(2),
            },
            lambda_process: {
                avg: (data.metrics.lambda_process_time_ms?.values?.avg || 0).toFixed(2),
                p95: (data.metrics.lambda_process_time_ms?.values?.['p(95)'] || 0).toFixed(2),
            },
        },
    };
    
    return {
        'e2e-summary.json': JSON.stringify(summary, null, 2),
        stdout: `
╔════════════════════════════════════════════════════════════════╗
║         END-TO-END PIPELINE PERFORMANCE RESULTS                ║
╚════════════════════════════════════════════════════════════════╝

Total Attempts:    ${summary.end_to_end_metrics.total_attempts}
Success Rate:      ${summary.end_to_end_metrics.success_rate}
Records Processed: ${summary.end_to_end_metrics.records_processed}

End-to-End Latency:
  Average:  ${summary.end_to_end_metrics.e2e_latency.avg}ms
  P95:      ${summary.end_to_end_metrics.e2e_latency.p95}ms
  P99:      ${summary.end_to_end_metrics.e2e_latency.p99}ms
  Max:      ${summary.end_to_end_metrics.e2e_latency.max}ms

Component Breakdown:
  Kinesis Write:    ${summary.component_breakdown.kinesis_write.avg}ms (avg)
  Lambda Process:   ${summary.component_breakdown.lambda_process.avg}ms (avg)

        `,
    };
}
```

---

### Approach 2: Component-by-Component Testing

K6 tests each component independently, then aggregates the results:

```javascript
// k6-test-scripts/component-testing.js
import { group } from 'k6';
import { Trend } from 'k6/metrics';

const kinesisLatency = new Trend('component_kinesis_latency');
const lambdaLatency = new Trend('component_lambda_latency');
const bigqueryLatency = new Trend('component_bigquery_latency');

export default function () {
    const testData = generateTestData();
    
    // Test Kinesis independently
    group('Kinesis Performance', function() {
        const start = Date.now();
        sendToKinesis(testData);
        kinesisLatency.add(Date.now() - start);
    });
    
    // Test Lambda independently (via direct invocation)
    group('Lambda Performance', function() {
        const start = Date.now();
        invokeLambda(testData);
        lambdaLatency.add(Date.now() - start);
    });
    
    // Test BigQuery independently
    group('BigQuery Performance', function() {
        const start = Date.now();
        insertToBigQuery(testData);
        bigqueryLatency.add(Date.now() - start);
    });
}
```

---

## How K6 Sends Payload Through the Flow

### Method 1: Using Kinesis as Entry Point (Recommended)

K6 acts as a **data producer** sending records to Kinesis. The existing AWS infrastructure handles the rest:

```
┌─────────────────────────────────────────────────────────────┐
│  K6 Load Generator (Your Test Machine)                     │
│  • Generates test payloads                                 │
│  • Sends to Kinesis via AWS SDK                           │
│  • Tracks unique IDs for verification                     │
└────────────────┬────────────────────────────────────────────┘
                 │
                 │ HTTP/HTTPS (AWS SDK)
                 │ PutRecord/PutRecords API
                 ↓
┌─────────────────────────────────────────────────────────────┐
│  AWS Kinesis Data Stream                                   │
│  • Receives records from K6                                │
│  • Buffers and partitions data                            │
│  • Triggers Lambda via Event Source Mapping               │
└────────────────┬────────────────────────────────────────────┘
                 │
                 │ Event Source Mapping (Automatic)
                 │ Batch of records
                 ↓
┌─────────────────────────────────────────────────────────────┐
│  AWS Lambda Function (Your Code)                           │
│  • Processes Kinesis records                               │
│  • Transforms/enriches data                                │
│  • Sends to BigQuery                                       │
└────────────────┬────────────────────────────────────────────┘
                 │
                 │ HTTPS (BigQuery API)
                 │ tabledata.insertAll
                 ↓
┌─────────────────────────────────────────────────────────────┐
│  GCP BigQuery                                               │
│  • Receives data from Lambda                               │
│  • Stores in table                                         │
│  • Available for querying                                  │
└─────────────────────────────────────────────────────────────┘
                 ↑
                 │ HTTPS (BigQuery Query API)
                 │ jobs.query (verification)
                 │
┌─────────────────────────────────────────────────────────────┐
│  K6 Verification Step                                       │
│  • Queries BigQuery for test records                       │
│  • Validates end-to-end flow                               │
│  • Measures total latency                                  │
└─────────────────────────────────────────────────────────────┘
```

### Example: K6 Sends 1000 Records/Second

```javascript
export const options = {
    scenarios: {
        constant_load: {
            executor: 'constant-arrival-rate',
            rate: 1000,        // 1000 iterations per second
            timeUnit: '1s',
            duration: '10m',
            preAllocatedVUs: 100,
            maxVUs: 500,
        },
    },
};

export default function () {
    // Each iteration = 1 record sent to Kinesis
    const record = {
        id: `rec-${Date.now()}-${__VU}-${__ITER}`,
        timestamp: new Date().toISOString(),
        data: generatePayload(500), // 500 bytes
    };
    
    // K6 sends this to Kinesis
    kinesis.putRecord({
        StreamName: 'my-stream',
        Data: JSON.stringify(record),
        PartitionKey: record.id,
    });
    
    // Kinesis automatically triggers Lambda
    // Lambda processes and sends to BigQuery
    // All happening asynchronously!
}
```

**What happens:**
1. K6 generates 1000 records/second
2. Each record goes to Kinesis (K6 tracks latency)
3. Kinesis triggers Lambda automatically
4. Lambda processes and sends to BigQuery
5. K6 optionally verifies in BigQuery

---

### Method 2: Testing Each Component's API

K6 can also test by directly calling each component:

```javascript
// Scenario 1: Test Kinesis API directly
group('Kinesis API Load', function() {
    kinesis.putRecord({
        StreamName: 'my-stream',
        Data: JSON.stringify(payload),
        PartitionKey: 'test-key',
    });
});

// Scenario 2: Test Lambda API directly (bypassing Kinesis)
group('Lambda API Load', function() {
    lambda.invoke({
        FunctionName: 'my-lambda',
        Payload: JSON.stringify(payload),
    });
});

// Scenario 3: Test BigQuery API directly (bypassing Kinesis & Lambda)
group('BigQuery API Load', function() {
    http.post(
        'https://bigquery.googleapis.com/bigquery/v2/.../insertAll',
        JSON.stringify({ rows: [payload] }),
        { headers: { 'Authorization': 'Bearer ...' } }
    );
});
```

---

## How K6 Tracks Performance Across the Pipeline

### 1. Trace ID Tracking

Every payload includes a unique trace ID:

```javascript
const traceId = `trace-${Date.now()}-${__VU}-${__ITER}`;

// Send to Kinesis with trace ID
kinesis.putRecord({
    Data: JSON.stringify({ 
        traceId: traceId,
        ...otherData 
    }),
});

// Later, verify in BigQuery using trace ID
queryBigQuery(`SELECT * WHERE traceId = '${traceId}'`);
```

### 2. Timestamp Tracking

Track when payload enters and exits each stage:

```javascript
const timestamps = {
    k6_send: Date.now(),
    kinesis_write: null,
    lambda_process: null,
    bigquery_insert: null,
};

// Include timestamps in payload
const payload = {
    traceId: 'xyz',
    timestamps: timestamps,
};

// Lambda updates timestamps:
// timestamps.lambda_process = Date.now()

// Query BigQuery to get final timestamps
// Calculate: bigquery_insert - k6_send = total latency
```

### 3. Custom Metrics Collection

```javascript
// K6 collects metrics at each stage
const metrics = {
    kinesis_write_latency: new Trend('kinesis_write_ms'),
    lambda_invoke_latency: new Trend('lambda_invoke_ms'),
    bigquery_insert_latency: new Trend('bigquery_insert_ms'),
    end_to_end_latency: new Trend('e2e_total_ms'),
};

// Track each stage
metrics.kinesis_write_latency.add(kinesisTime);
metrics.lambda_invoke_latency.add(lambdaTime);
metrics.bigquery_insert_latency.add(bigqueryTime);
metrics.end_to_end_latency.add(totalTime);
```

---

## Running the Complete Flow Test

### Step 1: Set Up Environment

```bash
# AWS Configuration
export AWS_REGION="us-east-1"
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export KINESIS_STREAM_NAME="your-kinesis-stream"
export LAMBDA_FUNCTION_NAME="your-lambda-function"

# GCP Configuration
export GCP_PROJECT_ID="your-gcp-project"
export GCP_ACCESS_TOKEN="your-gcp-token"
export BQ_DATASET="your-dataset"
export BQ_TABLE="your-table"

# Test Configuration
export TEST_RUN_ID="test-$(date +%Y%m%d-%H%M%S)"
```

### Step 2: Run End-to-End Test

```bash
# Run the complete pipeline test
k6 run \
  --out json=results/e2e-${TEST_RUN_ID}.json \
  --out influxdb=http://localhost:8086/k6 \
  end-to-end-pipeline-test.js

# Results show:
# - How many records K6 sent to Kinesis
# - How many made it through Lambda
# - How many arrived in BigQuery
# - Total end-to-end latency
```

### Step 3: Analyze Results

```bash
# View summary
cat results/e2e-${TEST_RUN_ID}.json | jq '.metrics.end_to_end_success_rate'

# Output example:
{
  "values": {
    "rate": 0.998,  // 99.8% success rate
    "passes": 9980,
    "fails": 20
  }
}
```

---

## Real-World Example

### Scenario: Testing 500 Records/Second Through Complete Pipeline

```javascript
// complete-flow-test.js
export const options = {
    scenarios: {
        pipeline_load: {
            executor: 'constant-arrival-rate',
            rate: 500,         // 500 records/second
            timeUnit: '1s',
            duration: '15m',   // 15 minutes
            preAllocatedVUs: 50,
        },
    },
    thresholds: {
        'end_to_end_latency_ms': ['p(95)<5000'], // 95% under 5 seconds
        'end_to_end_success_rate': ['rate>0.99'], // 99% success
    },
};

export default function () {
    const startTime = Date.now();
    const recordId = `rec-${startTime}-${__VU}-${__ITER}`;
    
    // 1. K6 sends to Kinesis
    const kinesisResult = sendToKinesis({
        recordId: recordId,
        timestamp: startTime,
        data: generateTestData(),
    });
    
    if (!kinesisResult.success) {
        return; // Skip if Kinesis write failed
    }
    
    // 2. Wait for processing (Lambda is triggered automatically)
    sleep(3);
    
    // 3. Verify in BigQuery
    const found = checkInBigQuery(recordId);
    
    if (found) {
        const endTime = Date.now();
        const totalLatency = endTime - startTime;
        
        // Record successful end-to-end flow
        e2eLatency.add(totalLatency);
        e2eSuccess.add(1);
        
        console.log(`✓ Record ${recordId} completed in ${totalLatency}ms`);
    } else {
        e2eSuccess.add(0);
        console.log(`✗ Record ${recordId} not found in BigQuery`);
    }
}
```

**Test Output:**
```
Running 15m test @ pipeline
  500 iterations/s for 15m

  ✓ 99.7% records successfully processed end-to-end
  ✓ 449,100 records sent to Kinesis
  ✓ 447,650 records found in BigQuery
  ✓ 1,450 records failed or delayed

  End-to-End Latency:
    avg: 2,345ms
    p95: 4,567ms
    p99: 6,789ms
    max: 12,345ms

  Component Breakdown:
    Kinesis Write:     45ms (avg)
    Lambda Processing: 1,200ms (avg)
    BigQuery Insert:   1,100ms (avg)
```

---

## Key Takeaways

1. **K6 Sends Data to Entry Point**: K6 acts as a data producer, sending test payloads to Kinesis (the entry point of your pipeline)

2. **Automatic Flow**: Once K6 sends data to Kinesis, the rest flows automatically:
   - Kinesis → Lambda (via Event Source Mapping)
   - Lambda → BigQuery (via your Lambda code)

3. **K6 Verifies End Result**: K6 queries BigQuery to verify records arrived, measuring end-to-end latency

4. **Metrics Collection**: K6 tracks performance at each stage and provides comprehensive reports

5. **Load Generation**: K6 can generate realistic load (100s to 1000s of records/second) to stress-test the complete pipeline

The beauty of this approach is that **K6 tests your real production pipeline** - it doesn't mock or simulate components, it actually sends data through your live infrastructure and measures real performance!
