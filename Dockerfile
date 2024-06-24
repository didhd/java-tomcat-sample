# Dockerfile for JBoss + Tomcat
FROM maven:3.8.5-openjdk-11 AS build

# Set the working directory
WORKDIR /app

# Copy the JBoss and Tomcat applications
COPY jboss-app /app/jboss-app
COPY tomcat-app /app/tomcat-app

# Build the JBoss application
RUN mvn -f /app/jboss-app/pom.xml clean package

# Build the Tomcat application
RUN mvn -f /app/tomcat-app/pom.xml clean package

# Use JBoss base image
FROM jboss/wildfly:latest

# Install wget, unzip, and EPEL repository for supervisor
USER root
RUN yum install -y wget unzip epel-release && \
    yum install -y supervisor && \
    yum clean all && \
    rm -rf /var/cache/yum

# Tomcat 버전 설정
ENV TOMCAT_VERSION 10.1.25

# Install Tomcat
RUN wget --no-check-certificate -O /tmp/tomcat.tar.gz https://dlcdn.apache.org/tomcat/tomcat-10/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz && \
    tar xf /tmp/tomcat.tar.gz -C /opt && \
    rm /tmp/tomcat.tar.gz && \
    mv /opt/apache-tomcat-${TOMCAT_VERSION} /opt/tomcat

# Change Tomcat HTTP port to 8081
RUN sed -i 's/port="8080"/port="8081"/' /opt/tomcat/conf/server.xml

# Environment variables
ENV CATALINA_HOME /opt/tomcat
ENV PATH $CATALINA_HOME/bin:$PATH

# Copy built applications
COPY --from=build /app/jboss-app/target/sample-jboss-app.war /opt/jboss/wildfly/standalone/deployments/
COPY --from=build /app/tomcat-app/target/sample-tomcat-app.war /opt/tomcat/webapps/

# Add Supervisor configuration
COPY supervisord.conf /etc/supervisord.conf

# Expose ports
EXPOSE 8080 8081

# Clean up unnecessary files
RUN yum remove -y wget unzip && \
    yum autoremove -y && \
    yum clean all && \
    rm -rf /var/cache/yum /opt/tomcat/webapps/ROOT

# Start Supervisor with the configuration file
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
