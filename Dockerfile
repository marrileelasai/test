FROM gradle:8-jdk21-alpine AS build
WORKDIR /src
COPY . .
ENV GRADLE_USER_HOME=/gradleHome
RUN --mount=type=secret,id=gradle,target=$GRADLE_USER_HOME/gradle.properties \
    gradle --no-daemon clean build

FROM azcontainerregistryprod.azurecr.io/ubi8/openjdk-21-runtime:1.21
USER 185
WORKDIR /app
COPY --from=build /src/build/static/ot_orchestrator.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]