# OT Orchestrator

Spring Boot + Apache Camel orchestration service with OpenTelemetry observability.

## Tech Stack

- **Java**: 17 (LTS)
- **Spring Boot**: 3.4.1
- **Apache Camel**: 4.9.0
- **OpenTelemetry**: 1.44.1 with W3C trace propagation
- **Build**: Gradle 8.11
- **Deployment**: OpenJDK 17 on RHEL UBI9

## Orchestration Flow

1. **POST** `/api/orchestrate/execute` with `{id, metadata?, supper_response_codes?}`
2. **Get Token**: POST `/v1/auth` with form-urlencoded credentials
3. **Call API**: GET `/v2/nodes/{id}/categories` with Bearer token
4. **Return**: Response from categories API

## Quick Start

### Build
```bash
./gradlew build
```

### Run
```bash
./gradlew bootRun
```

### Test
```bash
curl -X POST http://localhost:8080/api/orchestrate/execute \
  -H "Content-Type: application/json" \
  -d '{"id": "12345", "metadata": "true"}'
```

## Configuration

Set environment variables or edit `application.yml`:

```bash
export AUTH_HOSTNAME=auth.example.com:443
export AUTH_USERNAME=myuser
export AUTH_PASSWORD=mypassword
export AUTH_DOMAIN=mydomain
export TARGET_ENDPOINT=https://api.example.com
```

## OpenTelemetry

✅ W3C trace context propagation  
✅ Logging exporter (console output)  
✅ Auto-instrumentation (no custom spans)  
✅ Spring Boot & Camel routes traced  

## Files

- `OTOrchestratorApplication.java` - Main application
- `OpenTelemetryConfig.java` - OTel setup
- `TokenOrchestrationRoute.java` - Orchestration logic
- `application.yml` - Configuration

## Windows Deployment

Use `gradlew.bat` instead of `./gradlew`:

```powershell
gradlew.bat build
gradlew.bat bootRun
```

## Docker

```bash
docker build -t ot-orchestrator:latest .
docker run -p 8080:8080 ot-orchestrator:latest
```
