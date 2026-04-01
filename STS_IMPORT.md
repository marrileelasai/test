# STS/Eclipse Import Instructions

## Issue
STS 4.30.0 cannot import the project when `org.gradle.java.home` is set in `gradle.properties`.

## Solution

### Option 1: Use System Java (Recommended for STS)
1. Ensure Java 17 is your default Java:
   ```bash
   java -version  # Should show Java 17
   ```

2. If not, set JAVA_HOME in your shell profile:
   ```bash
   export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
   export PATH=$JAVA_HOME/bin:$PATH
   ```

3. Import project in STS: `File → Import → Existing Gradle Project`

### Option 2: Configure STS Java Runtime
1. In STS, go to `Preferences → Java → Installed JREs`
2. Click `Add → Standard VM`
3. Browse to: `/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`
4. Set as default
5. Import project

### Option 3: Use Wrapper Script (For Command Line)
```bash
./gradlew-java17.sh build
./gradlew-java17.sh bootRun
```

## Verify Build
```bash
# With JAVA_HOME set
./gradlew clean build

# Or use wrapper
./gradlew-java17.sh clean build
```
