# ── Stage 1: Build the fat JAR ──────────────────────────────────────────────
# We start from an official Maven + Java 21 image.
# This stage compiles the source code and packages it into a fat JAR.
# A "fat JAR" contains the application code AND all its dependencies (Spring Boot, etc.)
# in a single self-contained file.
FROM maven:3.9-eclipse-temurin-21-alpine AS build

WORKDIR /app

# Copy pom.xml first (separate layer) so Maven dependencies are cached.
# If you only change source code (not pom.xml), Docker reuses this cached layer.
COPY pom.xml .
RUN mvn dependency:go-offline -q

# Now copy the source code and build.
COPY src ./src
RUN mvn clean package -DskipTests -q

# ── Stage 2: The runtime image ───────────────────────────────────────────────
# We do NOT use the Maven build image for running. It is large (~500MB).
# Instead we start fresh with just the Java runtime — no Maven, no source code.
# This produces a much smaller final image (~200MB vs ~500MB).
# This technique is called a "multi-stage build".
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# Copy only the fat JAR from the build stage. Nothing else.
COPY --from=build /app/target/*.jar app.jar

# Document which port this service listens on.
# EXPOSE does not actually publish the port — it is documentation for tools and humans.
EXPOSE 8081

# The command that runs when a container starts from this image.
# "java -jar app.jar" starts the Spring Boot application.
ENTRYPOINT ["java", "-jar", "/app/app.jar"]

