# AWS Lambda Function Performance Testing with K6

## Overview

This guide covers comprehensive performance testing and monitoring for AWS Lambda functions across various use cases: event-driven processing, API backends, data transformation, and cross-service orchestration.

## Lambda Function Performance Testing Strategies

### 1. Direct Lambda Invocation Testing

#### Testing via AWS SDK

```javascript
// k6-test-scripts/lambda-direct-invoke.js
import { AWSConfig } from 'k6/x/aws';
import { Lambda } from 'k6/x/aws/lambda';
import { check } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';

// Custom metrics
const lambdaInvocationDuration = new Trend('lambda_invocation_duration');
const lambdaSuccessRate = new Rate('lambda_success_rate');
const lambdaInvocations = new Counter('lambda_invocations');
const lambdaColdStarts = new Counter('lambda_cold_starts');

export const options = {
    stages: [
        { duration: '1m', target: 10 },   // Warm up
        { duration: '5m', target: 50 },   // Normal load
        { duration: '5m', target: 100 },  // High load
        { duration: '2m', target: 200 },  // Stress test
        { duration: '2m', target: 0 },    // Cool down
    ],
    thresholds: {
        'lambda_invocation_duration': ['p(95)<3000', 'p(99)<5000'],
        'lambda_success_rate': ['rate>0.99'],
        'http_req_failed': ['rate<0.01'],
    },
};

const awsConfig = new AWSConfig({
    region: __ENV.AWS_REGION || 'us-east-1',
});

const lambda = new Lambda(awsConfig);

export default function () {
    const functionName = __ENV.LAMBDA_FUNCTION_NAME;
    const payload = {
        requestId: `req-${__VU}-${__ITER}`,
        timestamp: Date.now(),
        data: generateTestPayload(),
        testRun: __ENV.TEST_RUN_ID,
    };

    const startTime = Date.now();
    
    const result = lambda.invoke({
        FunctionName: functionName,
        InvocationType: 'RequestResponse',
        Payload: JSON.stringify(payload),
    });

    const duration = Date.now() - startTime;
    lambdaInvocationDuration.add(duration);
    lambdaInvocations.add(1);

    const success = check(result, {
        'invocation successful': (r) => r.StatusCode === 200,
        'no function error': (r) => !r.FunctionError,
        'has response payload': (r) => r.Payload !== undefined,
    });

    lambdaSuccessRate.add(success);

    // Detect cold starts (duration > typical warm start)
    if (duration > 1000) {
        lambdaColdStarts.add(1);
    }

    if (result.FunctionError) {
        console.error(`Lambda error: ${result.FunctionError}`);
    }
}

function generateTestPayload() {
    return {
        userId: `user-${Math.floor(Math.random() * 10000)}`,
        action: 'process_data',
        items: Array.from({ length: 10 }, (_, i) => ({
            id: i,
            value: Math.random() * 100,
        })),
    };
}
```

### 2. API Gateway + Lambda Testing

```javascript
// k6-test-scripts/lambda-api-gateway.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate } from 'k6/metrics';

const apiResponseTime = new Trend('api_response_time');
const apiSuccessRate = new Rate('api_success_rate');

export const options = {
    stages: [
        { duration: '2m', target: 50 },
        { duration: '5m', target: 200 },
        { duration: '5m', target: 500 },
        { duration: '2m', target: 100 },
        { duration: '1m', target: 0 },
    ],
    thresholds: {
        'api_response_time': ['p(95)<1000', 'p(99)<2000'],
        'api_success_rate': ['rate>0.995'],
        'http_req_duration': ['p(95)<1500'],
    },
};

export default function () {
    const apiEndpoint = __ENV.API_GATEWAY_URL;
    
    const payload = {
        action: 'process',
        data: {
            id: `${__VU}-${__ITER}`,
            timestamp: Date.now(),
            payload: generateApiPayload(),
        },
    };

    const params = {
        headers: {
            'Content-Type': 'application/json',
            'X-Api-Key': __ENV.API_KEY,
        },
        tags: { name: 'LambdaAPITest' },
    };

    const startTime = Date.now();
    const res = http.post(apiEndpoint, JSON.stringify(payload), params);
    const duration = Date.now() - startTime;

    apiResponseTime.add(duration);

    const success = check(res, {
        'status is 200': (r) => r.status === 200,
        'response has data': (r) => r.json('data') !== undefined,
        'no errors': (r) => !r.json('error'),
        'response time acceptable': (r) => r.timings.duration < 2000,
    });

    apiSuccessRate.add(success);

    if (res.status !== 200) {
        console.error(`API error: ${res.status} - ${res.body}`);
    }

    sleep(0.1); // Small delay between requests
}

function generateApiPayload() {
    return {
        records: Array.from({ length: 5 }, (_, i) => ({
            recordId: `rec-${i}`,
            value: Math.random() * 1000,
            metadata: {
                source: 'k6-test',
                timestamp: Date.now(),
            },
        })),
    };
}
```

### 3. Event-Driven Lambda Testing (SQS/SNS/EventBridge)

```javascript
// k6-test-scripts/lambda-event-driven.js
import { AWSConfig } from 'k6/x/aws';
import { SQS } from 'k6/x/aws/sqs';
import { check } from 'k6';
import { Counter, Trend } from 'k6/metrics';

const messagesSent = new Counter('sqs_messages_sent');
const sendDuration = new Trend('sqs_send_duration');

export const options = {
    scenarios: {
        sqs_publisher: {
            executor: 'constant-arrival-rate',
            rate: 100, // 100 messages per second
            timeUnit: '1s',
            duration: '10m',
            preAllocatedVUs: 50,
            maxVUs: 200,
        },
    },
};

const awsConfig = new AWSConfig({
    region: __ENV.AWS_REGION,
});

const sqs = new SQS(awsConfig);

export default function () {
    const queueUrl = __ENV.SQS_QUEUE_URL;
    
    const message = {
        messageId: `msg-${__VU}-${__ITER}`,
        timestamp: Date.now(),
        eventType: 'test_event',
        payload: {
            action: 'process',
            data: generateEventData(),
        },
    };

    const startTime = Date.now();
    
    const result = sqs.sendMessage({
        QueueUrl: queueUrl,
        MessageBody: JSON.stringify(message),
        MessageAttributes: {
            TestRun: {
                DataType: 'String',
                StringValue: __ENV.TEST_RUN_ID,
            },
        },
    });

    const duration = Date.now() - startTime;
    sendDuration.add(duration);

    const success = check(result, {
        'message sent': (r) => r.MessageId !== undefined,
        'send time acceptable': () => duration < 500,
    });

    if (success) {
        messagesSent.add(1);
    }
}

function generateEventData() {
    return {
        userId: `user-${Math.floor(Math.random() * 1000)}`,
        action: ['create', 'update', 'delete'][Math.floor(Math.random() * 3)],
        timestamp: Date.now(),
        metadata: {
            source: 'k6-performance-test',
            iteration: __ITER,
        },
    };
}
```

## Lambda Performance Metrics to Monitor

### Core Lambda Metrics

| Metric | Description | Target | Alert Threshold |
|--------|-------------|--------|-----------------|
| **Invocations** | Total function calls | Matches expected load | N/A |
| **Duration** | Execution time | < 50% of timeout | > 80% of timeout |
| **Errors** | Failed invocations | < 0.1% | > 1% |
| **Throttles** | Rate-limited invocations | 0 | > 0 |
| **ConcurrentExecutions** | Parallel executions | < 80% of limit | > 90% of limit |
| **UnreservedConcurrentExecutions** | Available capacity | > 100 | < 50 |
| **DeadLetterErrors** | DLQ failures | 0 | > 0 |
| **IteratorAge** | Stream processing lag | < 1000ms | > 5000ms |
| **AsyncEventsReceived** | Async event volume | Matches expected | N/A |
| **AsyncEventAge** | Age of oldest event | < 1000ms | > 5000ms |

### Advanced Metrics via CloudWatch Logs Insights

```sql
-- Find cold starts
fields @timestamp, @duration, @initDuration
| filter @type = "REPORT"
| filter ispresent(@initDuration)
| stats count() as coldStarts, 
        avg(@initDuration) as avgColdStart,
        max(@initDuration) as maxColdStart
by bin(5m)

-- Memory utilization analysis
fields @timestamp, @memorySize, @maxMemoryUsed
| filter @type = "REPORT"
| stats avg(@maxMemoryUsed/@memorySize * 100) as avgMemoryUtilization,
        max(@maxMemoryUsed) as peakMemory
by bin(5m)

-- Error rate analysis
fields @timestamp, @message
| filter @type = "REPORT" or level = "ERROR"
| stats count(*) as total,
        sum(@type = "ERROR") as errors
by bin(5m)
| fields bin(5m) as time, 
         errors / total * 100 as errorRate

-- P50, P90, P95, P99 latencies
fields @duration
| filter @type = "REPORT"
| stats pct(@duration, 50) as p50,
        pct(@duration, 90) as p90,
        pct(@duration, 95) as p95,
        pct(@duration, 99) as p99
by bin(5m)
```

### Custom Application Metrics

```python
# Python Lambda with custom CloudWatch metrics
import json
import time
import boto3
from functools import wraps

cloudwatch = boto3.client('cloudwatch')

def track_performance(func):
    """Decorator to track Lambda function performance"""
    @wraps(func)
    def wrapper(event, context):
        start_time = time.time()
        
        try:
            result = func(event, context)
            
            # Track success
            publish_metric('FunctionSuccess', 1, 'Count')
            
            return result
            
        except Exception as e:
            # Track failure
            publish_metric('FunctionFailure', 1, 'Count')
            raise
            
        finally:
            # Track duration
            duration = (time.time() - start_time) * 1000
            publish_metric('CustomDuration', duration, 'Milliseconds')
            
    return wrapper

def publish_metric(name, value, unit, dimensions=None):
    """Publish custom CloudWatch metric"""
    metric_data = {
        'MetricName': name,
        'Value': value,
        'Unit': unit,
        'Timestamp': time.time(),
    }
    
    if dimensions:
        metric_data['Dimensions'] = dimensions
    
    cloudwatch.put_metric_data(
        Namespace='CustomLambda/Performance',
        MetricData=[metric_data]
    )

@track_performance
def lambda_handler(event, context):
    # Your Lambda function logic
    record_count = len(event.get('Records', []))
    
    # Track custom business metrics
    publish_metric('RecordsProcessed', record_count, 'Count')
    
    processing_start = time.time()
    
    results = process_records(event['Records'])
    
    processing_duration = (time.time() - processing_start) * 1000
    publish_metric('ProcessingDuration', processing_duration, 'Milliseconds')
    
    return {
        'statusCode': 200,
        'body': json.dumps(results)
    }
```

## Lambda Performance Optimization Techniques

### 1. Cold Start Optimization

```python
# Optimization: Move imports and initialization outside handler
import json
import boto3

# Initialize clients outside handler (reused across invocations)
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('my-table')
s3 = boto3.client('s3')

# Cache configuration
CONFIG_CACHE = {}

def get_config():
    """Cached configuration retrieval"""
    if not CONFIG_CACHE:
        # Load config once and cache
        CONFIG_CACHE['settings'] = load_config_from_s3()
    return CONFIG_CACHE['settings']

def lambda_handler(event, context):
    config = get_config()
    # Use cached config
    return process_with_config(event, config)
```

### 2. Memory Optimization

Test different memory configurations to find optimal price/performance:

```bash
# Test Lambda with different memory settings
for memory in 128 256 512 1024 1536 2048 3008; do
    echo "Testing with ${memory}MB memory..."
    
    # Update function memory
    aws lambda update-function-configuration \
        --function-name my-function \
        --memory-size $memory
    
    # Run performance test
    k6 run --env LAMBDA_MEMORY=$memory lambda-direct-invoke.js
    
    # Collect metrics
    aws cloudwatch get-metric-statistics \
        --namespace AWS/Lambda \
        --metric-name Duration \
        --dimensions Name=FunctionName,Value=my-function \
        --statistics Average,Maximum \
        --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
        --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
        --period 60
done
```

### 3. Provisioned Concurrency Testing

```javascript
// k6-test-scripts/lambda-provisioned-concurrency.js
import { Lambda } from 'k6/x/aws/lambda';
import { check } from 'k6';
import { Counter } from 'k6/metrics';

const coldStarts = new Counter('cold_starts');
const warmStarts = new Counter('warm_starts');

export const options = {
    scenarios: {
        // Test burst scenario
        burst: {
            executor: 'ramping-arrival-rate',
            startRate: 10,
            timeUnit: '1s',
            preAllocatedVUs: 50,
            stages: [
                { duration: '30s', target: 10 },
                { duration: '10s', target: 100 }, // Sudden burst
                { duration: '2m', target: 100 },
                { duration: '30s', target: 10 },
            ],
        },
    },
};

export default function () {
    const startTime = Date.now();
    
    const result = lambda.invoke({
        FunctionName: __ENV.LAMBDA_FUNCTION_NAME,
        InvocationType: 'RequestResponse',
        Payload: JSON.stringify({ test: 'data' }),
    });
    
    const duration = Date.now() - startTime;
    
    // Cold starts typically take > 1 second
    if (duration > 1000) {
        coldStarts.add(1);
    } else {
        warmStarts.add(1);
    }
    
    check(result, {
        'provisioned concurrency effective': () => duration < 500,
    });
}
```

## Lambda Cost Optimization Metrics

### Cost per Invocation Calculator

```python
def calculate_lambda_cost(invocations, avg_duration_ms, memory_mb):
    """
    Calculate Lambda cost based on usage
    
    Pricing (as of 2024):
    - Requests: $0.20 per 1M requests
    - Duration: $0.0000166667 per GB-second
    """
    # Request cost
    request_cost = (invocations / 1_000_000) * 0.20
    
    # Duration cost
    gb_seconds = (memory_mb / 1024) * (avg_duration_ms / 1000) * invocations
    duration_cost = gb_seconds * 0.0000166667
    
    total_cost = request_cost + duration_cost
    cost_per_invocation = total_cost / invocations if invocations > 0 else 0
    
    return {
        'total_cost': total_cost,
        'request_cost': request_cost,
        'duration_cost': duration_cost,
        'cost_per_invocation': cost_per_invocation,
        'cost_per_million': cost_per_invocation * 1_000_000,
    }

# Example usage
result = calculate_lambda_cost(
    invocations=10_000_000,  # 10M invocations
    avg_duration_ms=200,      # 200ms average
    memory_mb=512             # 512MB memory
)

print(f"Cost per million invocations: ${result['cost_per_million']:.2f}")
```

## Lambda Performance Testing Checklist

### Pre-Test Setup
- [ ] Configure Lambda function timeout appropriately
- [ ] Set up CloudWatch Logs retention
- [ ] Enable AWS X-Ray tracing
- [ ] Configure reserved/provisioned concurrency if needed
- [ ] Set up DLQ for async invocations
- [ ] Create test IAM roles with appropriate permissions

### During Testing
- [ ] Monitor CloudWatch metrics in real-time
- [ ] Watch for throttling errors
- [ ] Track cold start frequency
- [ ] Monitor memory utilization
- [ ] Check error logs immediately
- [ ] Track concurrent execution count

### Post-Test Analysis
- [ ] Review p50, p95, p99 latencies
- [ ] Analyze cold start impact
- [ ] Calculate cost per invocation
- [ ] Identify optimization opportunities
- [ ] Document bottlenecks
- [ ] Create performance baseline

## Lambda-Specific Alerts

```bash
# Create CloudWatch alarms for Lambda
aws cloudwatch put-metric-alarm \
    --alarm-name lambda-high-errors \
    --alarm-description "Alert when Lambda error rate is high" \
    --metric-name Errors \
    --namespace AWS/Lambda \
    --statistic Sum \
    --period 60 \
    --evaluation-periods 2 \
    --threshold 10 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=FunctionName,Value=my-function

aws cloudwatch put-metric-alarm \
    --alarm-name lambda-throttles \
    --alarm-description "Alert on Lambda throttling" \
    --metric-name Throttles \
    --namespace AWS/Lambda \
    --statistic Sum \
    --period 60 \
    --evaluation-periods 1 \
    --threshold 0 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=FunctionName,Value=my-function

aws cloudwatch put-metric-alarm \
    --alarm-name lambda-high-duration \
    --alarm-description "Alert when Lambda duration is high" \
    --metric-name Duration \
    --namespace AWS/Lambda \
    --statistic Average \
    --period 60 \
    --evaluation-periods 3 \
    --threshold 5000 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=FunctionName,Value=my-function
```

## Best Practices Summary

1. **Test Realistic Workloads**: Use production-like data volumes and patterns
2. **Monitor Cold Starts**: Track and minimize cold start impact
3. **Right-size Memory**: Balance cost vs. performance
4. **Use Provisioned Concurrency**: For latency-sensitive workloads
5. **Enable X-Ray**: Get detailed trace data for optimization
6. **Set Appropriate Timeouts**: Avoid unnecessary long-running functions
7. **Monitor Costs**: Track cost per invocation and optimize
8. **Test Failure Scenarios**: Verify DLQ and retry behavior
9. **Gradual Load Testing**: Ramp up slowly to identify breaking points
10. **Document Baselines**: Establish performance baselines for comparison
