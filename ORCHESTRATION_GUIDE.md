# Token Orchestration Guide

## Overview

The `TokenOrchestrationRoute` implements a 3-step orchestration flow:

1. **Receive Request** - Accept incoming request via REST endpoint
2. **Get Token** - Call authentication endpoint with form-urlencoded credentials
3. **Call Target** - Use token to call second endpoint and return response

## Flow Diagram

```
Client Request
     ↓
POST /api/orchestrate/execute
     ↓
[Step 1] POST to Auth Endpoint
         Content-Type: application/x-www-form-urlencoded
         Body: username=X&password=Y&domain=Z
     ↓
     Response: {"ticket": "token-value"}
     ↓
[Step 2] POST to Target Endpoint
         Authorization: Bearer token-value
         Content-Type: application/json
         Body: <original request>
     ↓
     Response: <target endpoint response>
     ↓
Return to Client
```

## Configuration

### Environment Variables

Set these environment variables or update `application.yml`:

```bash
# Authentication endpoint
export AUTH_HOSTNAME=auth.example.com:443
export AUTH_USERNAME=myuser
export AUTH_PASSWORD=mypassword
export AUTH_DOMAIN=mydomain  # Optional

# Target endpoint
export TARGET_ENDPOINT=https://api.example.com/v1/process
```

### application.yml

```yaml
orchestrator:
  auth:
    hostname: ${AUTH_HOSTNAME:localhost:8081}
    username: ${AUTH_USERNAME:admin}
    password: ${AUTH_PASSWORD:password}
    domain: ${AUTH_DOMAIN:}  # Optional
  target:
    endpoint: ${TARGET_ENDPOINT:http://localhost:8082/api/data}
```

## Usage

### Trigger Orchestration

```bash
curl -X POST http://localhost:8080/api/orchestrate/execute \
  -H "Content-Type: application/json" \
  -d '{
    "data": "your request payload"
  }'
```

### With Trace Context

```bash
curl -X POST http://localhost:8080/api/orchestrate/execute \
  -H "Content-Type: application/json" \
  -H "traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01" \
  -d '{
    "data": "your request payload"
  }'
```

## Authentication Flow Details

### Step 1: Get Token

**Request to Auth Endpoint:**
```http
POST http://{AUTH_HOSTNAME}/auth/token
Content-Type: application/x-www-form-urlencoded

username=myuser&password=mypassword&domain=mydomain
```

**Response:**
```json
{
  "ticket": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

The route automatically:
- URL-encodes the credentials
- Parses the JSON response
- Extracts the `ticket` field
- Stores it for the next step

### Step 2: Call Target Endpoint

**Request to Target:**
```http
POST {TARGET_ENDPOINT}
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "data": "your request payload"
}
```

The route automatically:
- Adds `Authorization: Bearer {token}` header
- Forwards the original request body
- Returns the target's response to the client

## Error Handling

The route includes comprehensive error handling:

### Authentication Failure

```json
{
  "status": "error",
  "message": "Failed to extract token from auth response",
  "timestamp": "2026-01-13T13:49:00Z"
}
```

### Target Endpoint Failure

```json
{
  "status": "error",
  "message": "HTTP operation failed invoking http://...",
  "timestamp": "2026-01-13T13:49:00Z"
}
```

## Logging

The route logs each step with trace context:

```
2026-01-13 08:49:00 [Camel (OTOrchestrator) thread #1] INFO  c.o.r.TokenOrchestrationRoute - trace_id=0af7651916cd43dd span_id=b7ad6b7169203331 - Starting orchestration - Exchange ID: ID-12345
2026-01-13 08:49:01 [Camel (OTOrchestrator) thread #1] INFO  c.o.r.TokenOrchestrationRoute - trace_id=0af7651916cd43dd span_id=b7ad6b7169203331 - Step 1: Requesting authentication token
2026-01-13 08:49:01 [Camel (OTOrchestrator) thread #1] INFO  c.o.r.TokenOrchestrationRoute - trace_id=0af7651916cd43dd span_id=b7ad6b7169203331 - Successfully obtained auth token: eyJhbGciOi...
2026-01-13 08:49:02 [Camel (OTOrchestrator) thread #1] INFO  c.o.r.TokenOrchestrationRoute - trace_id=0af7651916cd43dd span_id=b7ad6b7169203331 - Step 2: Calling target endpoint with token
2026-01-13 08:49:02 [Camel (OTOrchestrator) thread #1] INFO  c.o.r.TokenOrchestrationRoute - trace_id=0af7651916cd43dd span_id=b7ad6b7169203331 - Successfully received response from target endpoint
2026-01-13 08:49:02 [Camel (OTOrchestrator) thread #1] INFO  c.o.r.TokenOrchestrationRoute - trace_id=0af7651916cd43dd span_id=b7ad6b7169203331 - Orchestration completed successfully
```

## Customization

### Modify Token Header Format

If the target endpoint expects a different header format:

```java
// Change from:
exchange.getIn().setHeader("Authorization", "Bearer " + token);

// To custom format:
exchange.getIn().setHeader("X-Auth-Token", token);
```

### Add Custom Headers

```java
.process(exchange -> {
    String token = exchange.getProperty("authToken", String.class);
    exchange.getIn().setHeader("Authorization", "Bearer " + token);
    exchange.getIn().setHeader("X-Request-ID", exchange.getExchangeId());
    exchange.getIn().setHeader("X-Client-Version", "1.0.0");
})
```

### Transform Request/Response

Add transformation between steps:

```java
from("direct:orchestrate")
    .log("Starting orchestration")
    .setProperty("originalRequest", body())
    
    // Transform request before getting token
    .process(exchange -> {
        // Custom transformation logic
    })
    
    .to("direct:getAuthToken")
    .to("direct:callTargetEndpoint")
    
    // Transform response before returning
    .process(exchange -> {
        String response = exchange.getIn().getBody(String.class);
        // Transform response
        exchange.getIn().setBody(transformedResponse);
    });
```

## Testing

Run the unit tests:

```bash
./gradlew test --tests TokenOrchestrationRouteTest
```

## Monitoring

### Health Check

```bash
curl http://localhost:8080/actuator/health
```

### Metrics

```bash
# View all metrics
curl http://localhost:8080/actuator/metrics

# View specific route metrics
curl http://localhost:8080/actuator/metrics/camel.route.exchanges.total
```

## Troubleshooting

### Issue: "Failed to extract token from auth response"

**Cause:** Auth endpoint returned unexpected JSON structure

**Solution:** Check the response format. If it's not `{"ticket":"..."}`, update the parsing logic:

```java
// Change from:
String token = jsonResponse.get("ticket").asText();

// To match your response:
String token = jsonResponse.get("access_token").asText();
```

### Issue: "401 Unauthorized" from target endpoint

**Cause:** Token format or header name incorrect

**Solution:** Verify the target endpoint expects `Authorization: Bearer {token}`. If different, update the header:

```java
exchange.getIn().setHeader("X-API-Key", token);
```

### Issue: Domain parameter causing issues

**Cause:** Domain field is optional but being sent as empty string

**Solution:** The route already handles this - domain is only added if non-empty:

```java
if (domain != null && !domain.isEmpty()) {
    formBody.append("&domain=").append(URLEncoder.encode(domain, StandardCharsets.UTF_8));
}
```

## Security Considerations

⚠️ **Important Security Notes:**

1. **Credentials in Configuration**: Store credentials in environment variables or secure vaults (e.g., HashiCorp Vault, AWS Secrets Manager)

2. **HTTPS**: Use HTTPS for both auth and target endpoints in production:
   ```yaml
   orchestrator:
     auth:
       hostname: auth.example.com:443  # HTTPS
     target:
       endpoint: https://api.example.com/v1/process
   ```

3. **Token Storage**: Tokens are stored in exchange properties (in-memory only, not persisted)

4. **Logging**: Be careful not to log full tokens in production. The route logs only first 10 characters.
