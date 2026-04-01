# Local Setup Guide — AKS Orchestration API
# No repo access needed — follow these steps exactly

---

## Prerequisites

| Tool        | Required Version | Download |
|-------------|-----------------|---------|
| Java (JDK)  | 21              | https://adoptium.net |
| Gradle      | 8.11            | https://gradle.org/releases (only if gradlew fails) |

---

## Step 1 — Fix JAVA_HOME (Windows PowerShell)

```powershell
# First, find your exact JDK folder name:
dir "C:\Program Files\Eclipse Adoptium\"

# Set JAVA_HOME using the EXACT folder name shown above, e.g:
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.10.7-hotspot"
$env:Path = "$env:JAVA_HOME\bin;" + $env:Path

# Verify:
java -version
```

---

## Step 2 — Fill in gradle.properties

Open `gradle.properties` in the project root and replace:

```properties
artifactory_user=YOUR_ACTUAL_USERNAME
artifactory_password=YOUR_ACTUAL_PASSWORD
artifactory_contextUrl=https://yourcompany.jfrog.io/artifactory
```

> If you don't have Artifactory credentials, ask Naveen / Mounika / Vishal.
> Alternatively, you can build offline if the Gradle cache already exists on your machine.

---

## Step 3 — Run the Application

```powershell
# Windows PowerShell
.\gradlew.bat bootRunWithTracing

# Mac / Linux
./gradlew bootRunWithTracing
```

On first run:
- A **browser window will open** — log in with your Azure account
- This is needed to access Azure Key Vault secrets (Kafka credentials etc.)
- After login, the app starts on **http://localhost:8080**

---

## Step 4 — Test W3C Trace Propagation

Send a request WITH a `traceparent` header and verify it appears in the logs
and gets forwarded to OTCS:

```powershell
curl -X POST http://localhost:8080/api/orchestrate/execute `
  -H "Content-Type: application/json" `
  -H "traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01" `
  -d '{"id": "12345", "metadata": "true"}'
```

**What to look for in logs:**

```
[W3C-TRACE] Captured traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
[W3C-TRACE] Injected traceparent into outbound call: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
```

If you see both lines — the W3C fix is working. ✅

---

## Step 5 — Health Check

```powershell
curl http://localhost:8080/actuator/health
```

Expected: `{"status":"UP"}`

---

## Common Errors

| Error | Fix |
|---|---|
| `JAVA_HOME is set to an invalid directory` | Step 1 above — find exact folder name with `dir` |
| `gradlew.bat not recognised` | Use `.\gradlew.bat` with the `.\` prefix in PowerShell |
| `Could not resolve artifactory dependency` | Fill in gradle.properties (Step 2) |
| `Could not resolve placeholder 'KAFKA_HOSTNAME'` | Use `bootRunWithTracing` not `bootRun` |
| `DefaultAzureCredential failed` | Complete Azure browser login when prompted |
| Browser doesn't open | Make sure `-Djava.awt.headless=false` is set (already in bootRunWithTracing) |
| Port 8080 in use | Run `netstat -ano \| findstr :8080` then `taskkill /PID <pid> /F` |

---

## W3C Trace Fix — What Was Changed

```
NEW:  src/main/java/com/orchestrator/config/W3CTracePropagationFilter.java
      → Captures traceparent from Kafka / HTTP entry point

NEW:  src/main/java/com/orchestrator/config/W3CTraceHeaderInjector.java
      → Injects traceparent into every outbound OTCS HTTP call

MOD:  routes/KafkaConsumerRoute.java          → capture at Kafka entry
MOD:  routes/OtcsAuthenticationRoute.java     → inject before auth call
MOD:  routes/WorkspaceOrchestrationRoute.java → inject before workspace call
MOD:  routes/CreateBusinessWorkspaceRoute.java
MOD:  routes/DocumentUploadRoute.java
MOD:  routes/DownloadDocumentRoute.java
MOD:  routes/EndLargeFileUploadRoute.java
MOD:  routes/GetBusinessWorkspaceIdRoute.java
MOD:  routes/SearchRoute.java
MOD:  routes/UpdateBusinessWorkspaceRoute.java
MOD:  routes/UpdateCategoriesRoute.java
MOD:  routes/UploadDocumentToNodeRoute.java
MOD:  service/CategoryMappingCacheService.java
```
