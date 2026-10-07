# The official Tomcat 11 image ships neither curl nor wget.
# This image adds curl so that Compose can check the application is really deployed.
FROM tomcat:11.0.26-jdk25-temurin

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*
