# Zscaler SSL Certificate Fix for Gradle

## Problem
Zscaler performs SSL inspection, causing 403 errors when Gradle tries to download dependencies from Maven Central.

## Solution: Trust Zscaler's Root Certificate

### Step 1: Export Zscaler Root Certificate

**On Windows:**
1. Open Chrome/Edge browser
2. Go to any HTTPS site (e.g., https://google.com)
3. Click the padlock icon → `Connection is secure` → `Certificate is valid`
4. Go to `Certification Path` tab
5. Select the **root certificate** (top of the chain, usually "Zscaler Root CA")
6. Click `View Certificate` → `Details` tab → `Copy to File`
7. Choose `Base-64 encoded X.509 (.CER)`
8. Save as `zscaler-root.cer`

### Step 2: Import Certificate into Java Keystore

**On Windows (run as Administrator):**
```cmd
cd C:\Program Files\Java\jdk-17\bin

keytool -import -trustcacerts -alias zscaler ^
  -file C:\path\to\zscaler-root.cer ^
  -keystore "%JAVA_HOME%\lib\security\cacerts" ^
  -storepass changeit
```

**Verify it was added:**
```cmd
keytool -list -keystore "%JAVA_HOME%\lib\security\cacerts" -storepass changeit | findstr -i zscaler
```

### Step 3: Configure Gradle (Optional)

Create `C:\Users\YourUsername\.gradle\gradle.properties`:
```properties
# Point to Java's cacerts that now includes Zscaler cert
systemProp.javax.net.ssl.trustStore=C:/Program Files/Java/jdk-17/lib/security/cacerts
systemProp.javax.net.ssl.trustStorePassword=changeit
```

### Step 4: Test Build
```cmd
gradlew.bat clean build --refresh-dependencies
```

## Alternative: Disable SSL Verification (NOT RECOMMENDED for Production)

**Only for testing:**

Create `gradle.properties` in project root:
```properties
systemProp.javax.net.ssl.trustAll=true
systemProp.com.sun.net.ssl.checkRevocation=false
```

## Alternative: Use Pre-Downloaded Dependencies

**On Mac (no Zscaler):**
```bash
./gradlew-java17.sh build --refresh-dependencies
tar -czf gradle-cache.tar.gz ~/.gradle/caches
```

**Transfer to Windows:**
1. Copy `gradle-cache.tar.gz` to Windows
2. Extract to `C:\Users\YourUsername\.gradle\caches`
3. Build offline:
```cmd
gradlew.bat build --offline
```

## Verify Zscaler Certificate

Check if Zscaler is intercepting:
```cmd
curl -v https://repo.maven.apache.org/maven2/
```

Look for "Zscaler" in the certificate chain.
