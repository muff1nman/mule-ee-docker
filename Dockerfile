###############################################################################
## Dockerizing Mule EE
## Version:  1.0
## Based on:  OpenJDK from Docker registry
## FROM openjdk
###############################################################################

FROM openjdk
LABEL maintainer="tanetg@gmail.com"
USER 0
 
###############################################################################
## Setting up the arguments
ARG     muleVersion=3.9.0
ARG     muleDistribution=mule-ee-distribution-standalone-$muleVersion.tar.gz
ARG     muleHome=/app/mule-enterprise-standalone-$muleVersion
 
###############################################################################
## MuleEE installation:
 
## Install Mule EE - these are the paths inside the Docker.
WORKDIR  /app/
COPY    mule-ee-distribution-standalone-3.9.0.tar.gz /app/
RUN     tar -xvzf /app/mule-ee-distribution-standalone-3.9.0.tar.gz
RUN     ls
RUN     ln -s $muleHome/ mule
RUN     ls -l mule
RUN     rm -f $muleDistribution
 
## Copy the mule start/stop script
RUN       chmod -R 777 /app/mule/logs
RUN       chmod -R 777 /app/mule/bin
RUN       chmod -R 777 /app/mule/conf
RUN       mkdir /app/mule/.mule
RUN       chmod -R 777 /app/mule/.mule

ADD     ./jq /app/jq
RUN     chmod +x /app/jq
COPY    test.zip /app/mule/apps/
ADD     ./startMule.sh /app/mule/bin/
RUN     chmod 755 /app/mule/bin/startMule.sh
ADD     ./wrapper.conf /app/mule/conf/
RUN     chmod 777 /app/mule/conf/wrapper.conf

## Define mount points. 
## VOLUME ["/app/mule/logs", "/app/mule/conf", "/app/mule/apps", "/app/mule/domains"]

## Mule app port
EXPOSE 443
EXPOSE 8081
EXPOSE 8082
EXPOSE 8088

USER 1000


## Mule Cluster ports
EXPOSE 5701
EXPOSE 54327
 
## Environment and execution:
ENV             MULE_BASE /app/mule
WORKDIR         /app/mule/bin
ENTRYPOINT      ["/app/mule/bin/startMule.sh"]
