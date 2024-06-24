# Java JBoss Tomcat Sample

이 프로젝트는 JBoss와 Tomcat 애플리케이션을 Docker 컨테이너로 패키징하고, 이를 AWS ECR에 배포하는 과정을 설명합니다.

## 샘플 코드 및 파일 작성

### 1. JBoss 애플리케이션 (sample-jboss-app.war)

간단한 Hello World JBoss 애플리케이션을입니다. 소스코드는 `jboss-app/` 디렉토리에 위치합니다.

### 2. Tomcat 애플리케이션 (sample-tomcat-app.war)

간단한 Hello World Tomcat 애플리케이션을입니다. 소스코드는 `tomcat-app/` 디렉토리에 위치합니다.

### 3. Dockerfile

프로젝트 루트 디렉토리에 `Dockerfile`을 생성합니다.

```
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
```

### 4. Supervisor 설정 파일

프로젝트 루트 디렉토리에 `supervisord.conf` 파일을 생성합니다.

```
[supervisord]
nodaemon=true

[program:jboss]
command=/opt/jboss/wildfly/bin/standalone.sh -b 0.0.0.0 -Djboss.http.port=8080
autostart=true
autorestart=true
stdout_logfile=/var/log/jboss.log
stderr_logfile=/var/log/jboss_err.log

[program:tomcat]
command=/opt/tomcat/bin/catalina.sh run
autostart=true
autorestart=true
stdout_logfile=/var/log/tomcat.log
stderr_logfile=/var/log/tomcat_err.log
```

### 5. 에디터/터미널 설정

#### 터미널 열기

프로젝트 루트 디렉토리를 엽니다.

```
cd java-tomcat-sample/
```

#### 터미널에서 Docker 빌드 및 실행

##### Docker 이미지 빌드

```
docker build -t jboss-tomcat-app .
```

##### Docker 컨테이너 실행

```
docker run -it --rm -p 8080:8080 -p 8081:8081 jboss-tomcat-app
```

### 6. 애플리케이션 확인

Java Application이 로드 되는데 시간이 조금 걸리므로, 1-2분 정도 기다려봅니다. 

#### JBoss 애플리케이션에 요청

JBoss 애플리케이션은 기본적으로 8080 포트를 사용합니다. 다음 명령어를 사용하여 JBoss 애플리케이션에 요청을 보냅니다:

```bash
curl http://localhost:8080/sample-jboss-app/hello
# Hello, JBoss World!
```

이 요청은 "Hello, JBoss World!"라는 응답을 반환해야 합니다.

#### Tomcat 애플리케이션에 요청

Tomcat 애플리케이션은 8081 포트를 사용합니다. 다음 명령어를 사용하여 Tomcat 애플리케이션에 요청을 보냅니다:

```bash
curl http://localhost:8081/sample-tomcat-app/hello
# Hello, Tomcat World!
```

이 요청은 "Hello, Tomcat World!"라는 응답을 반환해야 합니다.

### 7. AWS ECR에 Docker 이미지 업로드

#### 환경 변수 설정

먼저 필요한 환경 변수를 설정합니다. 아래 명령어를 실행하여 AWS 리전과 계정 ID를 환경 변수로 설정합니다.

```
export AWS_REGION=ap-northeast-2
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export REPOSITORY_NAME=jboss-tomcat-repo
```

#### ECR 리포지토리 생성

AWS CLI를 사용하여 ECR 리포지토리를 생성합니다.

```
aws ecr create-repository \
    --repository-name $REPOSITORY_NAME \
    --region $AWS_REGION
```

#### AWS CLI 로그인

AWS CLI를 사용하여 Docker를 ECR에 로그인합니다.

```
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
```

#### Docker 이미지 태깅

Docker 이미지를 ECR 리포지토리에 푸시할 수 있도록 태깅합니다.

```
docker tag jboss-tomcat-app:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/${REPOSITORY_NAME}:latest
```

#### Docker 이미지 푸시

태그된 Docker 이미지를 ECR 리포지토리에 푸시합니다.

```
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/${REPOSITORY_NAME}:latest
```

## 요약

이 워크샵에서는 JBoss와 Tomcat 애플리케이션을 하나의 Docker 컨테이너로 패키징하고, 이를 로컬에서 실행한 후 AWS ECR에 업로드하는 과정을 다루었습니다. 이 과정을 통해 컨테이너라이제이션의 기본 개념을 이해하고, AWS 클라우드 환경에 배포할 준비를 마칠 수 있습니다. VSCode를 사용하여 개발 환경을 설정하고 Docker 명령어를 통해 이미지를 빌드하고 실행할 수 있습니다.