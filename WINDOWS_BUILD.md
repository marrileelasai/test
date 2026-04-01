# Windows Build Instructions

## 403 Error When Downloading Dependencies

This is typically caused by corporate proxy/firewall restrictions.

### Solution 1: Configure Gradle Proxy (Recommended)

Create `gradle.properties` in your Windows user home directory:
```
C:\Users\YourUsername\.gradle\gradle.properties
```

Add these lines (replace with your proxy details):
```properties
systemProp.http.proxyHost=your-proxy-host
systemProp.http.proxyPort=8080
systemProp.https.proxyHost=your-proxy-host
systemProp.https.proxyPort=8080

# If proxy requires authentication:
systemProp.http.proxyUser=your-username
systemProp.http.proxyPassword=your-password
systemProp.https.proxyUser=your-username
systemProp.https.proxyPassword=your-password

# If you need to bypass proxy for certain hosts:
systemProp.http.nonProxyHosts=localhost|127.0.0.1
```

### Solution 2: Use Corporate Maven Repository

If your company has an internal Maven mirror (like Nexus or Artifactory), add to `build.gradle`:

```groovy
repositories {
    maven {
        url "https://your-company-maven-repo/repository/maven-public"
        credentials {
            username = project.findProperty("repoUser") ?: System.getenv("REPO_USER")
            password = project.findProperty("repoPassword") ?: System.getenv("REPO_PASSWORD")
        }
    }
    mavenCentral()
}
```

### Solution 3: Download Dependencies on Mac, Transfer to Windows

1. On Mac, run:
   ```bash
   ./gradlew-java17.sh build --refresh-dependencies
   ```

2. Copy the entire `~/.gradle/caches` directory to Windows:
   ```
   C:\Users\YourUsername\.gradle\caches
   ```

3. Copy the project to Windows and build offline:
   ```cmd
   gradlew.bat build --offline
   ```

### Solution 4: Use Spring Boot 3.3.x (More Stable)

If the issue persists, we can downgrade to Spring Boot 3.3.6 which is more widely cached.

### Verify Build on Windows

```cmd
gradlew.bat clean build --info
```

The `--info` flag will show exactly which repository is failing.

## Common Issues

**SSL Certificate Issues:**
```properties
# Add to gradle.properties
systemProp.javax.net.ssl.trustStore=C:/path/to/truststore.jks
systemProp.javax.net.ssl.trustStorePassword=changeit
```

**Firewall Blocking Maven Central:**
- Ask IT to whitelist: `repo.maven.apache.org`, `repo1.maven.org`
- Or use your company's Maven mirror
