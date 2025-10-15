FROM 10.29.230.150:31381/library/m.daocloud.io/docker.io/fabric8/java-jboss-openjdk8-jdk

COPY target/*.war /deployments/


ENV JAVA_APP_JAR spring-boot-sample-0.0.1-SNAPSHOT.war 
ADD target/$JAVA_APP_JAR /deployments

EXPOSE 8080
ENV JAVA_MAX_MEM_RATIO=50
ENV CONTAINER_MAX_MEMORY=314572800