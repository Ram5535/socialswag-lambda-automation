
#FROM - Image to start building on.
FROM ubuntu:20.04

#MAINTAINER - Identifies the maintainer of the dockerfile.
MAINTAINER ramanjaneyulu.m@socialswag.com

#RUN - Runs a command in the container
RUN cd /opt/socialswag-lambda-automation && git pull
