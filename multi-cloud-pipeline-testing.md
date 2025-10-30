# Multi-Cloud Pipeline Performance Testing Guide

## Overview: AWS to GCP Data Pipeline Architecture

This guide covers performance testing and monitoring for a multi-cloud log aggregation pipeline that spans:
- **Client AWS Accounts** → Multiple tenants sending logs
- **SRE AWS Account** → Central aggregation and processing
- **Transit Layer** → Cross-cloud connectivity (AWS ↔ GCP)
- **GCP BigQuery** → Final analytics destination

## Architecture Flow

```
Client AWS Accounts (ECS/CloudWatch)
  ↓ (Log Forwarder Lambda)
SRE AWS Account (Tenant Kinesis Streams)
  ↓ (Aggregation Lambda)
Central Kinesis / DLQ Processing
  ↓ (S3 Archive + Export Lambda)
Transit VPC (AWS)
  ↓ (VPN/Interconnect)
Transit VPC (GCP)
  ↓ (Data Transfer Function)
GCP BigQuery
```

## Performance Testing Strategy by Component

### 1. Client-Side Log Forwarder Lambda Performance

#### Metrics to Monitor
| Metric | Description | Target | How to Collect |
|--------|-------------|--------|----------------|
| `Lambda Invocations` | Log batches processed | Match log volume | CloudWatch |
| `Lambda Duration` | Processing time per batch | < 5000ms | CloudWatch |
| `Lambda Errors` | Failed log forwarding | < 0.1% | CloudWatch |
| `Lambda Throttles` | Rejected invocations | 0 | CloudWatch |
| `CloudWatch Subscription Filter Latency` | Time from log to Lambda | < 1000ms | Custom metric |
| `Kinesis PutRecords Success` | Successful forwarding | > 99.9% | CloudWatch |

#### K6 Testing Approach
Since log forwarders are triggered by CloudWatch Logs, simulate log generation:

```javascript
// k6-test-scripts/client-log-generation.js
import http from 'k6/http';
import { check } from 'k6';

export const options = {
    stages: [
        { duration: '2m', target: 100 },  // 100 log events/sec
        { duration: '5m', target: 500 },  // Ramp to 500/sec
        { duration: '5m', target: 1000 }, // Peak load
    ],
};

export default function () {
    // Simulate CloudWatch Log event
    const logEntry = {
        timestamp: Date.now(),
        level: 'INFO',
        service: 'client-service-a',
        message: generateLogMessage(),
        requestId: `req-${__VU}-${__ITER}`,
    };
    
    // Send to CloudWatch Logs API or test endpoint
    const res = http.post(
        `${__ENV.CLOUDWATCH_ENDPOINT}/log-groups/${__ENV.LOG_GROUP}/log-streams/${__ENV.LOG_STREAM}`,
        JSON.stringify(logEntry)
    );
    
    check(res, {
        'log accepted': (r) => r.status === 200,
    });
}
```

**Monitoring Points:**
1. CloudWatch Logs → Lambda trigger latency
2. Lambda → Kinesis write latency
3. End-to-end: Log creation → Kinesis arrival

---

### 2. Tenant-Specific Kinesis Stream Performance

#### Per-Tenant Stream Metrics
| Metric | Description | Target | Multi-Tenant Consideration |
|--------|-------------|--------|---------------------------|
| `IncomingRecords` (per stream) | Records from each tenant | Varies by tenant | Monitor each tenant separately |
| `IteratorAge` (per stream) | Processing lag per tenant | < 1000ms | Alert if any tenant falls behind |
| `WriteProvisionedThroughputExceeded` | Tenant throttling | 0 | May need per-tenant shard allocation |
| `Tenant Isolation Verification` | Cross-tenant data leakage | 0 | Custom validation |

#### K6 Multi-Tenant Testing

```javascript
// k6-test-scripts/multi-tenant-load.js
import { scenario } from 'k6/execution';

export const options = {
    scenarios: {
        tenant_a: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '5m', target: 100 },
            ],
            tags: { tenant: 'tenant-a' },
        },
        tenant_b: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '5m', target: 200 },
            ],
            tags: { tenant: 'tenant-b' },
        },
        tenant_c: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '5m', target: 50 },
            ],
            tags: { tenant: 'tenant-c' },
        },
    },
};

export default function () {
    const tenant = scenario.name.replace('tenant_', 'tenant-');
    const streamName = `kinesis-${tenant}`;
    
    // Send tenant-specific data
    sendToKinesis(streamName, {
        tenantId: tenant,
        data: generateTenantData(tenant),
    });
}
```

---

### 3. Central Aggregation Lambda Performance

#### Aggregation Lambda Metrics
| Metric | Description | Target | Monitoring Tool |
|--------|-------------|--------|-----------------|
| `Batch Size` | Records processed per invocation | Optimize for cost/latency | CloudWatch Logs Insights |
| `Processing Rate` | Records/second processed | Match incoming rate | Custom metric |
| `DLQ Messages` | Failed records | < 0.01% | SQS/SNS metrics |
| `S3 Write Latency` | Archive write time | < 500ms | X-Ray |
| `Cross-Stream Aggregation Time` | Multi-tenant merge time | < 2000ms | Custom metric |
| `Memory Pressure` | Memory utilization | < 80% | CloudWatch |

#### Lambda Code Instrumentation

```python
# Example Lambda function with performance instrumentation
import time
import boto3
from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.core import patch_all

patch_all()

cloudwatch = boto3.client('cloudwatch')

@xray_recorder.capture('process_records')
def lambda_handler(event, context):
    start_time = time.time()
    records_processed = 0
    records_failed = 0
    
    for record in event['Records']:
        try:
            # Record processing start
            record_start = time.time()
            
            # Process record
            process_record(record)
            
            # Track record processing time
            record_duration = (time.time() - record_start) * 1000
            publish_metric('RecordProcessingDuration', record_duration, 'Milliseconds')
            
            records_processed += 1
        except Exception as e:
            records_failed += 1
            publish_metric('RecordProcessingFailures', 1, 'Count')
    
    # Publish batch metrics
    total_duration = (time.time() - start_time) * 1000
    publish_metric('BatchProcessingDuration', total_duration, 'Milliseconds')
    publish_metric('RecordsProcessed', records_processed, 'Count')
    publish_metric('RecordsFailed', records_failed, 'Count')
    
    return {
        'statusCode': 200,
        'recordsProcessed': records_processed,
        'recordsFailed': records_failed,
    }

def publish_metric(name, value, unit):
    cloudwatch.put_metric_data(
        Namespace='MultiCloud/Pipeline',
        MetricData=[{
            'MetricName': name,
            'Value': value,
            'Unit': unit,
            'Dimensions': [
                {'Name': 'Component', 'Value': 'AggregationLambda'},
                {'Name': 'Environment', 'Value': 'Production'},
            ],
        }]
    )
```

---

### 4. Cross-Cloud Data Transfer Performance

#### Transit Layer Metrics
| Metric | Description | Target | Tool |
|--------|-------------|--------|------|
| `VPN Throughput` | Data transfer rate | > 1 Gbps | VPC Flow Logs |
| `VPN Latency` | Cross-cloud latency | < 50ms | CloudWatch/GCP Monitoring |
| `Packet Loss` | Network reliability | < 0.01% | VPC Flow Logs |
| `Export Lambda Duration` | AWS → GCP transfer time | < 10000ms | CloudWatch |
| `NAT Gateway Throughput` | Network capacity | Monitor utilization | CloudWatch |
| `Data Transfer Costs` | Cross-cloud egress fees | Budget tracking | Cost Explorer |

#### Export Lambda to GCP Testing

```javascript
// k6-test-scripts/cross-cloud-export.js
import http from 'k6/http';
import { check } from 'k6';

export const options = {
    stages: [
        { duration: '5m', target: 50 }, // Conservative for cross-cloud
    ],
    thresholds: {
        'http_req_duration': ['p(95)<10000'], // 10s for cross-cloud
        'http_req_failed': ['rate<0.01'],
    },
};

export default function () {
    const payload = {
        records: generateBatchRecords(100), // Batch for efficiency
        destination: 'gcp-bigquery',
        timestamp: Date.now(),
    };
    
    // Call export Lambda via API Gateway or direct invoke
    const res = http.post(
        `${__ENV.EXPORT_LAMBDA_URL}`,
        JSON.stringify(payload),
        {
            headers: {
                'Content-Type': 'application/json',
                'X-Api-Key': __ENV.API_KEY,
            },
            timeout: '30s', // Higher timeout for cross-cloud
        }
    );
    
    check(res, {
        'export successful': (r) => r.status === 200,
        'latency acceptable': (r) => r.timings.duration < 10000,
    });
}
```

---

### 5. GCP BigQuery Performance Monitoring

#### BigQuery Metrics
| Metric | Description | Target | Tool |
|--------|-------------|--------|------|
| `Streaming Insert Success Rate` | Successful inserts | > 99.9% | GCP Monitoring |
| `Streaming Insert Latency` | Time to insert | < 1000ms | GCP Monitoring |
| `Query Performance` | Analytics query time | Varies by query | BigQuery Console |
| `Slot Utilization` | Compute resource usage | < 80% | BigQuery Console |
| `Storage Growth Rate` | Data accumulation | Monitor trends | BigQuery Console |
| `Cost per GB Inserted` | Streaming insert costs | Budget tracking | GCP Billing |
| `Table Schema Drift` | Data quality issues | 0 | Custom validation |

#### GCP Monitoring Setup

```python
# Python script to monitor BigQuery streaming inserts
from google.cloud import monitoring_v3
from google.cloud import bigquery

def monitor_bigquery_performance():
    client = monitoring_v3.MetricServiceClient()
    project_name = f"projects/{project_id}"
    
    # Query for streaming insert metrics
    interval = monitoring_v3.TimeInterval(
        {
            "end_time": {"seconds": int(time.time())},
            "start_time": {"seconds": int(time.time() - 3600)},
        }
    )
    
    # Streaming insert success rate
    results = client.list_time_series(
        request={
            "name": project_name,
            "filter": 'metric.type="bigquery.googleapis.com/streaming/row_count"',
            "interval": interval,
        }
    )
    
    for result in results:
        print(f"Rows inserted: {result.points[0].value.int64_value}")
    
    # Query performance metrics
    bq_client = bigquery.Client()
    query_job = bq_client.query("""
        SELECT
            job_id,
            creation_time,
            total_bytes_processed,
            total_slot_ms,
            TIMESTAMP_DIFF(end_time, start_time, MILLISECOND) as duration_ms
        FROM
            `region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT`
        WHERE
            creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
            AND job_type = 'QUERY'
        ORDER BY creation_time DESC
        LIMIT 100
    """)
    
    for row in query_job:
        print(f"Query {row.job_id}: {row.duration_ms}ms, {row.total_bytes_processed} bytes")
```

#### BigQuery Load Testing with K6

```javascript
// k6-test-scripts/bigquery-streaming-insert.js
import http from 'k6/http';
import { check } from 'k6';

export const options = {
    stages: [
        { duration: '2m', target: 100 },  // 100 inserts/sec
        { duration: '5m', target: 500 },  // 500 inserts/sec
        { duration: '5m', target: 1000 }, // 1000 inserts/sec
    ],
};

export default function () {
    const rows = [
        {
            insertId: `insert-${__VU}-${__ITER}`,
            json: {
                timestamp: new Date().toISOString(),
                tenant_id: `tenant-${Math.floor(Math.random() * 10)}`,
                log_level: 'INFO',
                service_name: 'aggregation-pipeline',
                message: generateLogMessage(),
                metadata: {
                    source_account: 'client-aws-account',
                    processing_duration_ms: Math.floor(Math.random() * 1000),
                },
            },
        },
    ];
    
    const res = http.post(
        `https://bigquery.googleapis.com/bigquery/v2/projects/${__ENV.GCP_PROJECT}/datasets/${__ENV.DATASET}/tables/${__ENV.TABLE}/insertAll`,
        JSON.stringify({ rows }),
        {
            headers: {
                'Authorization': `Bearer ${__ENV.GCP_ACCESS_TOKEN}`,
                'Content-Type': 'application/json',
            },
        }
    );
    
    check(res, {
        'insert successful': (r) => r.status === 200,
        'no insert errors': (r) => {
            const body = JSON.parse(r.body);
            return !body.insertErrors || body.insertErrors.length === 0;
        },
    });
}
```

---

## End-to-End Pipeline Testing

### Complete Flow Performance Test

```javascript
// k6-test-scripts/end-to-end-pipeline.js
import { check, group } from 'k6';
import { Counter, Trend } from 'k6/metrics';

const e2eLatency = new Trend('e2e_pipeline_latency');
const recordsProcessed = new Counter('e2e_records_processed');

export const options = {
    scenarios: {
        end_to_end_test: {
            executor: 'constant-vus',
            vus: 50,
            duration: '10m',
        },
    },
};

export default function () {
    const traceId = `trace-${__VU}-${__ITER}`;
    const startTime = Date.now();
    
    group('Client Log Generation', function() {
        // Step 1: Generate log in client account
        const logResult = generateClientLog(traceId);
        check(logResult, { 'log generated': (r) => r.success });
    });
    
    group('Tenant Stream Processing', function() {
        // Step 2: Wait for log to appear in tenant Kinesis stream
        waitForKinesisRecord(traceId, 'tenant-stream');
    });
    
    group('Central Aggregation', function() {
        // Step 3: Verify processing by aggregation Lambda
        waitForS3Archive(traceId);
    });
    
    group('Cross-Cloud Transfer', function() {
        // Step 4: Verify transfer to GCP
        waitForTransitProcessing(traceId);
    });
    
    group('BigQuery Insert', function() {
        // Step 5: Verify arrival in BigQuery
        const arrived = waitForBigQueryRecord(traceId);
        
        if (arrived) {
            const e2eDuration = Date.now() - startTime;
            e2eLatency.add(e2eDuration);
            recordsProcessed.add(1);
            
            check(e2eDuration, {
                'e2e latency < 30s': (d) => d < 30000,
                'e2e latency < 60s': (d) => d < 60000,
            });
        }
    });
}
```

---

## Comprehensive Monitoring Dashboard

### Multi-Cloud Dashboard Configuration

Create a unified monitoring view across AWS and GCP:

**AWS CloudWatch Dashboard:**
```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "title": "Client Log Forwarders",
        "metrics": [
          ["AWS/Lambda", "Invocations", {"stat": "Sum", "label": "Client A"}],
          ["...", {"stat": "Sum", "label": "Client B"}],
          ["...", {"stat": "Sum", "label": "Client C"}]
        ]
      }
    },
    {
      "type": "metric",
      "properties": {
        "title": "Tenant Kinesis Streams",
        "metrics": [
          ["AWS/Kinesis", "IncomingRecords", {"dimensions": {"StreamName": "tenant-a"}}],
          ["...", {"dimensions": {"StreamName": "tenant-b"}}],
          ["...", {"dimensions": {"StreamName": "tenant-c"}}]
        ]
      }
    },
    {
      "type": "metric",
      "properties": {
        "title": "Cross-Cloud Transfer",
        "metrics": [
          ["MultiCloud/Pipeline", "ExportLambdaDuration"],
          ["...", "ExportSuccess"],
          ["...", "ExportFailures"]
        ]
      }
    }
  ]
}
```

**GCP Monitoring Dashboard (via gcloud):**
```bash
# Create GCP monitoring dashboard
gcloud monitoring dashboards create --config-from-file=- <<EOF
{
  "displayName": "BigQuery Pipeline Performance",
  "mosaicLayout": {
    "columns": 12,
    "tiles": [
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Streaming Insert Rate",
          "xyChart": {
            "dataSets": [{
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"bigquery.googleapis.com/streaming/row_count\""
                }
              }
            }]
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Query Performance",
          "xyChart": {
            "dataSets": [{
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"bigquery.googleapis.com/query/execution_times\""
                }
              }
            }]
          }
        }
      }
    ]
  }
}
EOF
```

---

## Performance Testing Execution Plan

### Week 1: Component Testing
- **Day 1-2**: Test client log forwarders (100-1000 logs/sec)
- **Day 3-4**: Test tenant Kinesis streams (multi-tenant isolation)
- **Day 5**: Test central aggregation Lambda

### Week 2: Integration Testing
- **Day 1-2**: Test AWS internal pipeline (logs → S3)
- **Day 3-4**: Test cross-cloud transfer (AWS → GCP)
- **Day 5**: Test BigQuery streaming inserts

### Week 3: End-to-End Testing
- **Day 1-3**: Full pipeline load test (100-1000 records/sec)
- **Day 4-5**: Stress testing and failure scenarios

### Week 4: Optimization
- **Day 1-3**: Identify bottlenecks and optimize
- **Day 4-5**: Retest and validate improvements

---

## Key Performance Indicators (KPIs)

| KPI | Target | Critical Threshold |
|-----|--------|-------------------|
| End-to-End Latency (P95) | < 30 seconds | < 60 seconds |
| Client Log Forwarder Success Rate | > 99.9% | > 99% |
| Tenant Stream Processing Lag | < 1 second | < 5 seconds |
| Cross-Cloud Transfer Success | > 99.5% | > 99% |
| BigQuery Insert Success | > 99.9% | > 99% |
| Daily Cost per Million Records | < $50 | < $100 |

---

## Troubleshooting Guide

### Common Issues

**Issue 1: High End-to-End Latency**
- Check: Transit VPN latency
- Check: Lambda cold starts in export function
- Check: BigQuery streaming quota limits

**Issue 2: Data Loss Between Components**
- Check: Lambda DLQ for failed records
- Check: Kinesis iterator age
- Check: S3 archive completeness
- Check: BigQuery insert errors

**Issue 3: Cost Overruns**
- Check: BigQuery streaming insert volume (most expensive)
- Check: Cross-cloud data transfer (AWS → GCP egress)
- Check: Lambda execution time optimization
- Check: Kinesis shard count optimization

---

## Cost Optimization Strategies

1. **Batch Processing**: Aggregate multiple records before BigQuery insert
2. **Compression**: Compress data before cross-cloud transfer
3. **Smart Routing**: Use regional endpoints to minimize data transfer
4. **Right-sizing**: Optimize Lambda memory and Kinesis shards
5. **Reserved Capacity**: Use BigQuery flat-rate pricing for predictable loads

---

## Next Steps

1. Deploy monitoring instrumentation across all components
2. Set up unified alerting (AWS CloudWatch + GCP Monitoring)
3. Run baseline performance tests
4. Establish performance budgets for each component
5. Create runbooks for common failure scenarios
