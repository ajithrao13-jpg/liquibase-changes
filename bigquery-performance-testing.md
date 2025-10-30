# GCP BigQuery Performance Testing Guide

## Overview

This guide covers performance testing and monitoring for Google BigQuery in a multi-cloud data pipeline, including streaming inserts, query performance, and cost optimization.

## BigQuery Performance Testing with K6

### 1. Streaming Insert Performance Testing

```javascript
// k6-test-scripts/bigquery-streaming-insert-load.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';
import { SharedArray } from 'k6/data';

// Custom metrics
const bqInsertDuration = new Trend('bigquery_insert_duration');
const bqInsertSuccess = new Rate('bigquery_insert_success');
const bqRowsInserted = new Counter('bigquery_rows_inserted');
const bqInsertErrors = new Counter('bigquery_insert_errors');

export const options = {
    stages: [
        { duration: '2m', target: 50 },    // Warm up
        { duration: '5m', target: 200 },   // Normal load
        { duration: '5m', target: 500 },   // High load
        { duration: '3m', target: 1000 },  // Stress test
        { duration: '2m', target: 100 },   // Cool down
        { duration: '1m', target: 0 },
    ],
    thresholds: {
        'bigquery_insert_duration': ['p(95)<1000', 'p(99)<2000'],
        'bigquery_insert_success': ['rate>0.999'],
        'http_req_duration': ['p(95)<1500'],
    },
};

// GCP authentication setup
const GCP_PROJECT = __ENV.GCP_PROJECT_ID;
const BQ_DATASET = __ENV.BQ_DATASET;
const BQ_TABLE = __ENV.BQ_TABLE;
const ACCESS_TOKEN = __ENV.GCP_ACCESS_TOKEN;

export default function () {
    const insertId = `insert-${__VU}-${__ITER}-${Date.now()}`;
    
    // Prepare streaming insert payload
    const rows = [
        {
            insertId: insertId,
            json: {
                timestamp: new Date().toISOString(),
                tenant_id: `tenant-${Math.floor(Math.random() * 10) + 1}`,
                log_level: selectRandom(['INFO', 'WARN', 'ERROR', 'DEBUG']),
                service_name: selectRandom(['log-forwarder', 'aggregation-lambda', 'export-function']),
                source_account: selectRandom(['client-a', 'client-b', 'client-c']),
                message: generateLogMessage(),
                metadata: {
                    aws_region: 'us-east-1',
                    processing_duration_ms: Math.floor(Math.random() * 1000),
                    record_size_bytes: Math.floor(Math.random() * 5000),
                    pipeline_stage: selectRandom(['ingestion', 'processing', 'export']),
                },
                custom_labels: {
                    environment: 'production',
                    test_run: __ENV.TEST_RUN_ID || 'default',
                    k6_vu: __VU.toString(),
                },
            },
        },
    ];

    const url = `https://bigquery.googleapis.com/bigquery/v2/projects/${GCP_PROJECT}/datasets/${BQ_DATASET}/tables/${BQ_TABLE}/insertAll`;
    
    const payload = JSON.stringify({
        kind: 'bigquery#tableDataInsertAllRequest',
        rows: rows,
        skipInvalidRows: false,
        ignoreUnknownValues: false,
    });

    const params = {
        headers: {
            'Authorization': `Bearer ${ACCESS_TOKEN}`,
            'Content-Type': 'application/json',
        },
        timeout: '10s',
    };

    const startTime = Date.now();
    const res = http.post(url, payload, params);
    const duration = Date.now() - startTime;

    bqInsertDuration.add(duration);

    const success = check(res, {
        'status is 200': (r) => r.status === 200,
        'no insert errors': (r) => {
            const body = r.json();
            return !body.insertErrors || body.insertErrors.length === 0;
        },
        'response is valid': (r) => r.json('kind') !== undefined,
    });

    if (success) {
        bqInsertSuccess.add(1);
        bqRowsInserted.add(rows.length);
    } else {
        bqInsertSuccess.add(0);
        bqInsertErrors.add(1);
        
        // Log errors for debugging
        if (res.status !== 200) {
            console.error(`BigQuery insert failed: ${res.status} - ${res.body}`);
        } else {
            const body = res.json();
            if (body.insertErrors) {
                console.error(`Insert errors: ${JSON.stringify(body.insertErrors)}`);
            }
        }
    }

    sleep(0.01); // Small delay to avoid overwhelming the API
}

function selectRandom(array) {
    return array[Math.floor(Math.random() * array.length)];
}

function generateLogMessage() {
    const messages = [
        'Successfully processed batch of records',
        'Record validation completed',
        'Data transformation successful',
        'Export to BigQuery initiated',
        'Cross-cloud transfer completed',
    ];
    return selectRandom(messages);
}

export function handleSummary(data) {
    const summary = {
        testRunId: __ENV.TEST_RUN_ID,
        testType: 'bigquery-streaming-insert',
        timestamp: new Date().toISOString(),
        metrics: {
            insert_duration_avg: data.metrics.bigquery_insert_duration?.values?.avg,
            insert_duration_p95: data.metrics.bigquery_insert_duration?.values?.['p(95)'],
            insert_duration_p99: data.metrics.bigquery_insert_duration?.values?.['p(99)'],
            insert_success_rate: data.metrics.bigquery_insert_success?.values?.rate,
            rows_inserted: data.metrics.bigquery_rows_inserted?.values?.count,
            insert_errors: data.metrics.bigquery_insert_errors?.values?.count,
        },
    };

    return {
        'summary-bigquery.json': JSON.stringify(summary, null, 2),
        'stdout': generateTextSummary(summary),
    };
}

function generateTextSummary(summary) {
    return `
BigQuery Streaming Insert Test Results
${'='.repeat(60)}
Test Run ID: ${summary.testRunId}
Timestamp: ${summary.timestamp}

Performance Metrics:
  Avg Insert Duration: ${summary.metrics.insert_duration_avg?.toFixed(2)}ms
  P95 Insert Duration: ${summary.metrics.insert_duration_p95?.toFixed(2)}ms
  P99 Insert Duration: ${summary.metrics.insert_duration_p99?.toFixed(2)}ms
  Success Rate: ${(summary.metrics.insert_success_rate * 100)?.toFixed(2)}%
  Rows Inserted: ${summary.metrics.rows_inserted}
  Insert Errors: ${summary.metrics.insert_errors}

${'='.repeat(60)}
    `.trim();
}
```

### 2. Batch Insert Testing

```javascript
// k6-test-scripts/bigquery-batch-insert.js
import http from 'k6/http';
import { check } from 'k6';
import { Trend, Counter } from 'k6/metrics';

const batchInsertDuration = new Trend('batch_insert_duration');
const totalRowsInserted = new Counter('total_rows_inserted');

export const options = {
    scenarios: {
        batch_inserts: {
            executor: 'constant-arrival-rate',
            rate: 10, // 10 batches per second
            timeUnit: '1s',
            duration: '10m',
            preAllocatedVUs: 20,
            maxVUs: 50,
        },
    },
};

const BATCH_SIZE = 500; // Insert 500 rows per batch

export default function () {
    const rows = [];
    
    // Generate batch of rows
    for (let i = 0; i < BATCH_SIZE; i++) {
        rows.push({
            insertId: `batch-${__VU}-${__ITER}-${i}`,
            json: generateRowData(),
        });
    }

    const url = `https://bigquery.googleapis.com/bigquery/v2/projects/${__ENV.GCP_PROJECT_ID}/datasets/${__ENV.BQ_DATASET}/tables/${__ENV.BQ_TABLE}/insertAll`;
    
    const startTime = Date.now();
    const res = http.post(url, JSON.stringify({ rows }), {
        headers: {
            'Authorization': `Bearer ${__ENV.GCP_ACCESS_TOKEN}`,
            'Content-Type': 'application/json',
        },
    });
    const duration = Date.now() - startTime;

    batchInsertDuration.add(duration);

    const success = check(res, {
        'batch inserted successfully': (r) => r.status === 200 && (!r.json('insertErrors') || r.json('insertErrors').length === 0),
    });

    if (success) {
        totalRowsInserted.add(BATCH_SIZE);
    }
}

function generateRowData() {
    return {
        timestamp: new Date().toISOString(),
        event_data: {
            user_id: Math.floor(Math.random() * 100000),
            action: 'page_view',
            duration_ms: Math.floor(Math.random() * 5000),
        },
    };
}
```

### 3. Query Performance Testing

```javascript
// k6-test-scripts/bigquery-query-performance.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate } from 'k6/metrics';

const queryDuration = new Trend('query_duration');
const querySuccess = new Rate('query_success');
const bytesProcessed = new Trend('bytes_processed');

export const options = {
    scenarios: {
        analytical_queries: {
            executor: 'constant-vus',
            vus: 10,
            duration: '5m',
        },
    },
};

const QUERIES = [
    // Query 1: Aggregation by tenant
    `SELECT 
        tenant_id,
        COUNT(*) as record_count,
        AVG(metadata.processing_duration_ms) as avg_processing_time
    FROM \`${__ENV.GCP_PROJECT_ID}.${__ENV.BQ_DATASET}.${__ENV.BQ_TABLE}\`
    WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
    GROUP BY tenant_id`,
    
    // Query 2: Error analysis
    `SELECT 
        service_name,
        log_level,
        COUNT(*) as count
    FROM \`${__ENV.GCP_PROJECT_ID}.${__ENV.BQ_DATASET}.${__ENV.BQ_TABLE}\`
    WHERE log_level = 'ERROR'
        AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
    GROUP BY service_name, log_level
    ORDER BY count DESC
    LIMIT 100`,
    
    // Query 3: Performance metrics
    `SELECT 
        DATE(timestamp) as date,
        AVG(metadata.processing_duration_ms) as avg_duration,
        MAX(metadata.processing_duration_ms) as max_duration,
        APPROX_QUANTILES(metadata.processing_duration_ms, 100)[OFFSET(95)] as p95_duration
    FROM \`${__ENV.GCP_PROJECT_ID}.${__ENV.BQ_DATASET}.${__ENV.BQ_TABLE}\`
    WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
    GROUP BY date
    ORDER BY date DESC`,
];

export default function () {
    const query = QUERIES[Math.floor(Math.random() * QUERIES.length)];
    
    const url = `https://bigquery.googleapis.com/bigquery/v2/projects/${__ENV.GCP_PROJECT_ID}/queries`;
    
    const payload = JSON.stringify({
        query: query,
        useLegacySql: false,
        useQueryCache: false, // Disable cache for realistic testing
    });

    const startTime = Date.now();
    const res = http.post(url, payload, {
        headers: {
            'Authorization': `Bearer ${__ENV.GCP_ACCESS_TOKEN}`,
            'Content-Type': 'application/json',
        },
        timeout: '60s',
    });
    const duration = Date.now() - startTime;

    queryDuration.add(duration);

    const success = check(res, {
        'query executed successfully': (r) => r.status === 200,
        'query completed': (r) => r.json('jobComplete') === true,
        'has results': (r) => r.json('totalRows') !== undefined,
    });

    querySuccess.add(success);

    if (success) {
        const responseBody = res.json();
        if (responseBody.totalBytesProcessed) {
            bytesProcessed.add(parseInt(responseBody.totalBytesProcessed));
        }
    }

    sleep(1); // Wait between queries
}
```

## BigQuery Performance Metrics

### Streaming Insert Metrics

| Metric | Description | Target | Monitoring Tool |
|--------|-------------|--------|-----------------|
| **Insert Latency** | Time to insert rows | < 1 second | GCP Monitoring |
| **Insert Success Rate** | Successful inserts | > 99.9% | GCP Monitoring |
| **Insert Errors** | Failed inserts | < 0.1% | BigQuery API response |
| **Quota Usage** | API requests used | < 80% of limit | GCP Quotas |
| **Row Size** | Average row size | Monitor for cost | BigQuery table info |
| **Daily Insert Volume** | Rows inserted per day | Track trends | BigQuery INFORMATION_SCHEMA |

### Query Performance Metrics

| Metric | Description | Target | Tool |
|--------|-------------|--------|------|
| **Query Duration** | Execution time | Varies by query | INFORMATION_SCHEMA.JOBS |
| **Bytes Processed** | Data scanned | Minimize | INFORMATION_SCHEMA.JOBS |
| **Bytes Billed** | Billable data | Monitor costs | INFORMATION_SCHEMA.JOBS |
| **Slot Utilization** | Compute resources used | < 80% | GCP Monitoring |
| **Cache Hit Rate** | Query cache effectiveness | > 50% for repeated queries | INFORMATION_SCHEMA.JOBS |
| **Concurrent Queries** | Parallel query count | < slot limit | GCP Monitoring |

## Monitoring BigQuery with GCP

### Setting Up GCP Monitoring

```python
# monitor-bigquery.py
from google.cloud import monitoring_v3
from google.cloud import bigquery
import time
from datetime import datetime, timedelta

def monitor_streaming_inserts(project_id, dataset_id, table_id):
    """Monitor BigQuery streaming insert performance"""
    client = monitoring_v3.MetricServiceClient()
    project_name = f"projects/{project_id}"
    
    # Time range: last hour
    now = time.time()
    seconds = int(now)
    nanos = int((now - seconds) * 10 ** 9)
    
    interval = monitoring_v3.TimeInterval({
        "end_time": {"seconds": seconds, "nanos": nanos},
        "start_time": {"seconds": (seconds - 3600), "nanos": nanos},
    })
    
    # Query streaming insert metrics
    results = client.list_time_series(
        request={
            "name": project_name,
            "filter": f'metric.type="bigquery.googleapis.com/streaming/row_count" AND '
                     f'resource.labels.dataset_id="{dataset_id}" AND '
                     f'resource.labels.table_id="{table_id}"',
            "interval": interval,
            "view": monitoring_v3.ListTimeSeriesRequest.TimeSeriesView.FULL,
        }
    )
    
    total_rows = 0
    for result in results:
        for point in result.points:
            total_rows += point.value.int64_value
    
    print(f"Total rows inserted in last hour: {total_rows}")
    return total_rows

def analyze_query_performance(project_id, hours=24):
    """Analyze BigQuery query performance"""
    client = bigquery.Client(project=project_id)
    
    # Query job history
    query = f"""
        SELECT
            job_id,
            user_email,
            creation_time,
            start_time,
            end_time,
            TIMESTAMP_DIFF(end_time, start_time, MILLISECOND) as duration_ms,
            total_bytes_processed,
            total_bytes_billed,
            total_slot_ms,
            cache_hit,
            statement_type,
            error_result.reason as error_reason
        FROM
            `region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT`
        WHERE
            creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL {hours} HOUR)
            AND job_type = 'QUERY'
            AND state = 'DONE'
        ORDER BY
            creation_time DESC
        LIMIT 1000
    """
    
    query_job = client.query(query)
    results = query_job.result()
    
    # Analyze results
    total_queries = 0
    total_duration = 0
    total_bytes_processed = 0
    cache_hits = 0
    errors = 0
    
    for row in results:
        total_queries += 1
        total_duration += row.duration_ms or 0
        total_bytes_processed += row.total_bytes_processed or 0
        
        if row.cache_hit:
            cache_hits += 1
        
        if row.error_reason:
            errors += 1
    
    if total_queries > 0:
        avg_duration = total_duration / total_queries
        cache_hit_rate = (cache_hits / total_queries) * 100
        error_rate = (errors / total_queries) * 100
        
        print(f"\nQuery Performance Analysis (last {hours} hours):")
        print(f"  Total Queries: {total_queries}")
        print(f"  Average Duration: {avg_duration:.2f}ms")
        print(f"  Total Bytes Processed: {total_bytes_processed / (1024**3):.2f} GB")
        print(f"  Cache Hit Rate: {cache_hit_rate:.2f}%")
        print(f"  Error Rate: {error_rate:.2f}%")

def monitor_costs(project_id, dataset_id, days=7):
    """Monitor BigQuery storage and query costs"""
    client = bigquery.Client(project=project_id)
    
    # Get dataset size
    dataset_ref = client.dataset(dataset_id)
    dataset = client.get_dataset(dataset_ref)
    
    tables = client.list_tables(dataset)
    total_size_gb = 0
    
    for table in tables:
        table_ref = dataset_ref.table(table.table_id)
        table_obj = client.get_table(table_ref)
        total_size_gb += table_obj.num_bytes / (1024**3)
    
    # Storage cost: $0.02 per GB per month
    storage_cost_monthly = total_size_gb * 0.02
    
    # Query cost from INFORMATION_SCHEMA
    query = f"""
        SELECT
            SUM(total_bytes_billed) / (1024*1024*1024*1024) as total_tb_billed
        FROM
            `region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT`
        WHERE
            creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL {days} DAY)
            AND job_type = 'QUERY'
            AND state = 'DONE'
    """
    
    query_job = client.query(query)
    result = list(query_job.result())[0]
    total_tb_billed = result.total_tb_billed or 0
    
    # Query cost: $5 per TB (on-demand pricing)
    query_cost = total_tb_billed * 5
    
    print(f"\nCost Analysis:")
    print(f"  Dataset Size: {total_size_gb:.2f} GB")
    print(f"  Monthly Storage Cost: ${storage_cost_monthly:.2f}")
    print(f"  Query Cost (last {days} days): ${query_cost:.2f}")
    print(f"  Data Processed (last {days} days): {total_tb_billed:.4f} TB")

if __name__ == "__main__":
    PROJECT_ID = "your-project-id"
    DATASET_ID = "your-dataset"
    TABLE_ID = "your-table"
    
    # Run monitoring
    monitor_streaming_inserts(PROJECT_ID, DATASET_ID, TABLE_ID)
    analyze_query_performance(PROJECT_ID, hours=24)
    monitor_costs(PROJECT_ID, DATASET_ID, days=7)
```

## BigQuery Optimization Strategies

### 1. Table Partitioning

```sql
-- Create partitioned table for better query performance
CREATE TABLE `project.dataset.logs_partitioned`
(
    timestamp TIMESTAMP,
    tenant_id STRING,
    log_level STRING,
    service_name STRING,
    message STRING,
    metadata STRUCT<
        aws_region STRING,
        processing_duration_ms INT64,
        record_size_bytes INT64
    >
)
PARTITION BY DATE(timestamp)
CLUSTER BY tenant_id, log_level
OPTIONS (
    partition_expiration_days = 90,
    require_partition_filter = true
);
```

### 2. Query Optimization

```sql
-- BEFORE: Full table scan
SELECT *
FROM `project.dataset.logs`
WHERE tenant_id = 'tenant-a'
    AND timestamp >= '2024-01-01';

-- AFTER: Partition pruning + clustering
SELECT *
FROM `project.dataset.logs_partitioned`
WHERE DATE(timestamp) >= '2024-01-01'  -- Partition filter
    AND tenant_id = 'tenant-a'         -- Cluster filter
LIMIT 1000;
```

### 3. Streaming Insert Optimization

```python
# Batch streaming inserts for better performance
from google.cloud import bigquery
import json

def optimized_streaming_insert(client, table_id, rows):
    """
    Optimized streaming insert with batching
    
    Best practices:
    - Batch up to 10,000 rows per request
    - Use insertId for deduplication
    - Monitor for errors
    """
    errors = client.insert_rows_json(
        table_id,
        rows,
        row_ids=[row['insertId'] for row in rows]
    )
    
    if errors:
        print(f"Insert errors: {errors}")
        return False
    
    return True

# Example usage
client = bigquery.Client()
table_id = "project.dataset.table"

batch = []
BATCH_SIZE = 5000

for i in range(10000):
    row = {
        'insertId': f'id-{i}',
        'timestamp': datetime.utcnow().isoformat(),
        'data': f'value-{i}',
    }
    batch.append(row)
    
    if len(batch) >= BATCH_SIZE:
        optimized_streaming_insert(client, table_id, batch)
        batch = []

# Insert remaining
if batch:
    optimized_streaming_insert(client, table_id, batch)
```

## BigQuery Performance Testing Checklist

### Pre-Test Setup
- [ ] Create test dataset and table with appropriate schema
- [ ] Set up table partitioning and clustering
- [ ] Configure GCP monitoring dashboards
- [ ] Set up billing alerts
- [ ] Generate GCP access token for K6 tests
- [ ] Define test data schema

### During Testing
- [ ] Monitor streaming insert latency
- [ ] Watch for insert errors
- [ ] Track quota usage
- [ ] Monitor slot utilization
- [ ] Check storage growth rate
- [ ] Track costs in real-time

### Post-Test Analysis
- [ ] Analyze insert performance (p50, p95, p99)
- [ ] Review query performance
- [ ] Calculate cost per million inserts
- [ ] Identify optimization opportunities
- [ ] Document baseline performance
- [ ] Clean up test data

## BigQuery Cost Optimization

### Streaming Insert Costs

```python
def calculate_streaming_insert_cost(rows_per_second, row_size_kb, hours):
    """
    Calculate BigQuery streaming insert cost
    
    Pricing (as of 2024):
    - Streaming inserts: $0.01 per 200 MB (after 2 TB free per month)
    """
    total_rows = rows_per_second * 3600 * hours
    total_mb = (total_rows * row_size_kb) / 1024
    total_gb = total_mb / 1024
    
    # Free tier: 2 TB per month
    free_tier_gb = 2048
    billable_gb = max(0, total_gb - free_tier_gb)
    
    # Cost: $0.01 per 200 MB = $0.05 per GB
    cost = (billable_gb * 1024 * 0.01) / 200
    
    return {
        'total_rows': total_rows,
        'total_gb': total_gb,
        'billable_gb': billable_gb,
        'cost': cost,
        'cost_per_million_rows': (cost / total_rows) * 1_000_000 if total_rows > 0 else 0,
    }

# Example: 1000 rows/sec, 2KB per row, for 24 hours
result = calculate_streaming_insert_cost(1000, 2, 24)
print(f"Cost per million rows: ${result['cost_per_million_rows']:.2f}")
print(f"Total cost for 24 hours: ${result['cost']:.2f}")
```

## Best Practices Summary

1. **Use Partitioning**: Partition tables by date for better performance
2. **Cluster Tables**: Cluster by frequently filtered columns
3. **Batch Inserts**: Group multiple rows in single API call
4. **Monitor Quotas**: Track API request limits
5. **Optimize Queries**: Use partition filters and limit scanned data
6. **Enable Caching**: Leverage query result caching
7. **Set Expiration**: Configure partition expiration for cost control
8. **Use Streaming Buffer Wisely**: Understand streaming buffer behavior
9. **Monitor Costs**: Set up billing alerts and budgets
10. **Test at Scale**: Validate performance with production-like volumes
