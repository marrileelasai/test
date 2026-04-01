# SSL Certificate Bypass Configuration

## Overview

SSL certificate validation is environment-aware using Spring Boot conditional bean creation. SSL bypass is enabled for local development via JVM property, while enforcing proper SSL validation in production, QA, and staging environments.

## How It Works

### Architecture

1. **SSLConfig.java** - Creates `allowAllSSLContextParameters` bean conditionally
   - Uses `@ConditionalOnProperty(name = "app.SSL_BYPASS_ENABLED", havingValue = "true", matchIfMissing = false)`
   - Bean only created when `SSL_BYPASS_ENABLED=true`
   - Contains TrustAllTrustManager that bypasses certificate validation

2. **SslPropertyConfig.java** - Detects bean and exposes SSL parameter
   - Checks if `allowAllSSLContextParameters` bean exists
   - Returns `&sslContextParameters=#allowAllSSLContextParameters` if bean exists, empty string otherwise
   - Injected into all routes via Spring dependency injection

3. **All Routes** - Inject SslPropertyConfig and append parameter to URLs
   - Use `sslPropertyConfig.getSslParam()` directly in HTTP calls
   - Example: `.toD("{{app.OTCS_BASE_URL}}/api/v2/nodes?bridgeEndpoint=true" + sslPropertyConfig.getSslParam())`

## Configuration

### JVM Property (Local Development)

Set via `build.gradle` bootRunWithTracing task:

```gradle
jvmArgs = [
    '-Dssl.bypass.enabled=true',  // Enables SSL bypass locally
    // other JVM args...
]
```

### Application Property Mapping

The JVM property maps to Spring property in `application.yml`:

```yaml
app:
  SSL_BYPASS_ENABLED: ${SSL_BYPASS_ENABLED}
```

**Important:** This is mapped from environment variable, not hardcoded.

## Usage by Environment

### Local Development

**Option 1: Use gradle task (recommended):**
```bash
gradle bootRunWithTracing
```
This task already has `-Dssl.bypass.enabled=true` in JVM args.

**Option 2: Set environment variable:**
```powershell
# Windows PowerShell
$env:SSL_BYPASS_ENABLED="true"
gradle bootRun
```

```bash
# Linux/Mac
export SSL_BYPASS_ENABLED=true
gradle bootRun
```

### Production/QA/Stage (AKS Deployment)

**CRITICAL: Ensure SSL_BYPASS_ENABLED is NOT set in deployed environments.**

The `@ConditionalOnProperty` has `matchIfMissing = false`, meaning:
- If `SSL_BYPASS_ENABLED` is not set → Bean NOT created → SSL validation enforced ✅
- If `SSL_BYPASS_ENABLED=false` → Bean NOT created → SSL validation enforced ✅
- If `SSL_BYPASS_ENABLED=true` → Bean created → SSL validation BYPASSED ⚠️

#### Kubernetes Deployment YAML
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ot-orchestrator
spec:
  template:
    spec:
      containers:
      - name: ot-orchestrator
        image: your-registry/ot-orchestrator:latest
        # DO NOT set SSL_BYPASS_ENABLED - omit it entirely for production
        env:
        - name: OTCS_BASE_URL
          value: "https://otcs.prod.company.com"
        # ... other env vars, but NOT SSL_BYPASS_ENABLED
```

#### Helm Values (prod.yaml, qa.yaml, stage.yaml)
```yaml
# DO NOT include SSL_BYPASS_ENABLED in production Helm values
# Omitting it ensures SSL validation is enforced

env:
  OTCS_BASE_URL: "https://otcs.prod.company.com"
  # ... other env vars

# If you must be explicit (optional):
# env:
#   SSL_BYPASS_ENABLED: "false"
```

## Implementation Details

### SSLConfig.java - Conditional Bean Creation

```java
@Configuration
public class SSLConfig {
    
    @Bean(name = "allowAllSSLContextParameters")
    @ConditionalOnProperty(name = "app.SSL_BYPASS_ENABLED", havingValue = "true", matchIfMissing = false)
    public SSLContextParameters allowAllSSLContextParameters() {
        // Creates TrustAllTrustManager that accepts any certificate
        TrustManager[] trustAllCerts = new TrustManager[]{new X509TrustManager() {
            public void checkClientTrusted(X509Certificate[] chain, String authType) {}
            public void checkServerTrusted(X509Certificate[] chain, String authType) {}
            public X509Certificate[] getAcceptedIssuers() { return new X509Certificate[0]; }
        }};
        
        SSLContext sslContext = SSLContext.getInstance("TLS");
        sslContext.init(null, trustAllCerts, new SecureRandom());
        
        SSLContextParameters sslContextParameters = new SSLContextParameters();
        sslContextParameters.setSSLContext(sslContext);
        return sslContextParameters;
    }
}
```

**Key Points:**
- `@ConditionalOnProperty(name = "app.SSL_BYPASS_ENABLED", havingValue = "true", matchIfMissing = false)`
- Bean only created when property explicitly set to "true"
- If property missing or "false" → No bean → SSL validation enforced

### SslPropertyConfig.java - Bean Detection

```java
@Component
public class SslPropertyConfig {
    
    @Autowired
    private ApplicationContext applicationContext;
    
    private String sslParam = "";
    
    @PostConstruct
    public void init() {
        boolean sslBypassBeanExists = applicationContext.containsBean("allowAllSSLContextParameters");
        this.sslParam = sslBypassBeanExists 
            ? "&sslContextParameters=#allowAllSSLContextParameters" 
            : "";
    }
    
    public String getSslParam() {
        return this.sslParam;
    }
}
```

### Route Implementation - Dependency Injection

```java
@Component
@RequiredArgsConstructor
public class OtcsAuthenticationRoute extends RouteBuilder {
    
    private final SslPropertyConfig sslPropertyConfig;
    
    @Override
    public void configure() {
        from("direct:authenticate-otcs")
            .toD("{{app.OTCS_BASE_URL}}/api/v1/auth?bridgeEndpoint=true" 
                + sslPropertyConfig.getSslParam());
    }
}
```

**Result:**
- When `SSL_BYPASS_ENABLED=true`: URL = `https://otcs.com/api/v1/auth?bridgeEndpoint=true&sslContextParameters=#allowAllSSLContextParameters`
- When `SSL_BYPASS_ENABLED` not set: URL = `https://otcs.com/api/v1/auth?bridgeEndpoint=true`

### CategoryMappingCacheService - Dynamic Check

```java
boolean sslBypassBeanExists = applicationContext.containsBean("allowAllSSLContextParameters");
String sslParam = sslBypassBeanExists 
    ? "&sslContextParameters=#allowAllSSLContextParameters" 
    : "";
String camelUrl = webReportUrl + "&bridgeEndpoint=true" + sslParam;
```

## Security Best Practices

1. **Never enable SSL bypass in production** - This exposes your application to man-in-the-middle attacks
2. **Use SSL bypass only for local development** - When working with self-signed certificates or test environments
3. **Verify deployment configurations** - Ensure QA, stage, and prod Helm values DO NOT include `SSL_BYPASS_ENABLED` (omit it entirely)
4. **Monitor SSL errors** - If you see SSL handshake failures in deployed environments, verify certificate validity (don't just enable bypass)
5. **Default behavior is secure** - With `matchIfMissing = false`, forgetting to set the property means SSL validation is enforced

## Affected Components

All OTCS API calls now use injected `SslPropertyConfig`:

### Routes with SSL Bypass Support:
1. **OtcsAuthenticationRoute** - `/api/v1/auth`
2. **DocumentUploadRoute** - `/api/v2/nodes` (upload)
3. **UploadLargeDocumentRoute** - `/api/v2/nodes` (streaming upload)
4. **UploadDocumentToNodeRoute** - `/api/v2/nodes` (upload to existing node)
5. **CreateBusinessWorkspaceRoute** - `/api/v2/businessworkspaces` (create)
6. **UpdateBusinessWorkspaceRoute** - `/api/v2/businessworkspaces` (update)
7. **WorkspaceOrchestrationRoute** - Multiple OTCS calls (3 locations)
8. **UpdateCategoriesRoute** - `/api/v2/nodes/{id}/categories/{catId}`
9. **SearchRoute** - `/api/v2/search`
10. **DownloadDocumentRoute** - `/api/v2/nodes/{id}` + `/api/v1/nodes/{id}/content`
11. **GetBusinessWorkspaceIdRoute** - `/api/v1/webreports/GetParentID`

### Services with SSL Bypass Support:
- **CategoryMappingCacheService** - `/api/v1/webreports/GetCategoryFields` (dynamic bean check)

## Troubleshooting

### Issue: SSL Handshake Failure in Deployed Environment

**Symptom:**
```
javax.net.ssl.SSLHandshakeException: PKIX path building failed
```

**Solution:**
1. Verify `SSL_BYPASS_ENABLED` is NOT set or set to `false`
2. Check if OTCS server certificate is valid and not expired
3. Ensure JVM trusts the certificate authority (CA)
4. For self-signed certificates, import the certificate into the JVM truststore (do NOT enable SSL bypass)

### Issue: Certificate Verification Failed Locally

**Symptom:**
```
sun.security.validator.ValidatorException: PKIX path building failed
```

**Solution:**
Use the `bootRunWithTracing` gradle task which has SSL bypass enabled:
```bash
gradle bootRunWithTracing
```

Or set environment variable:
```powershell
$env:SSL_BYPASS_ENABLED="true"
gradle bootRun
```

### Issue: SSL Bypass Not Working After Code Changes

**Symptom:**
SSL errors persist even with `SSL_BYPASS_ENABLED=true` set.

**Solution:**
1. Check logs for SSLConfig bean creation:
   ```
   ⚠️ SSLConfig CLASS LOADED - SSL Bypass Bean will be created
   ```
2. Check logs for SslPropertyConfig initialization:
   ```
   ⚠️ Bean exists: true
   ⚠️ SSL BYPASS ENABLED - sslParam will disable certificate validation
   ```
3. Clean build and restart:
   ```powershell
   gradle clean
   gradle bootRunWithTracing
   ```

## Migration Notes

**Previous Approach (Exchange Properties with Interceptor):**
- Used `interceptFrom()` to set `sslParam` exchange property
- Problem: `interceptFrom()` only applies to external sources (netty-http, kafka), not `direct:` routes
- Routes used `${exchangeProperty.sslParam}` in URLs

**Current Approach (Dependency Injection):**
- `@ConditionalOnProperty` creates bean only when needed
- `SslPropertyConfig` detects bean and exposes `getSslParam()` method
- Routes inject `SslPropertyConfig` via constructor and call `sslPropertyConfig.getSslParam()`
- Works for ALL routes regardless of invocation method

**Key Improvement:**
- Simpler, more reliable - no Camel interceptor complexity
- Standard Spring dependency injection pattern
- Compile-time safety (no runtime property resolution)
- Easier to debug and test
