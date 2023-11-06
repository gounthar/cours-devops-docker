# Use a Maven image for building the application
FROM maven:3.9.4-eclipse-temurin-21-alpine AS build
WORKDIR /app

# Clone the Spring Boot application repository
RUN apk add git && git clone https://github.com/spring-guides/gs-spring-boot.git

# Change directory to the application's complete directory
WORKDIR /app/gs-spring-boot/complete

# Build the application using Maven
RUN mvn package

# Use a lightweight Java image for running the application
FROM eclipse-temurin:21.0.1_12-jre-alpine
WORKDIR /app

# Copy the built JAR file from the previous build stage
COPY --from=build /app/gs-spring-boot/complete/target/spring-boot-complete-0.0.1-SNAPSHOT.jar ./

# Command to run the Spring Boot application
CMD ["java", "-jar", "spring-boot-complete-0.0.1-SNAPSHOT.jar"]

