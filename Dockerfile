
#FROM - Image to start building on.
FROM ubuntu

#MAINTAINER - Identifies the maintainer of the dockerfile.
MAINTAINER ramanjaneyulu.m@socialswag.com

#RUN - Runs a command in the container
RUN cd /opt/socialswag-lambda-automation && git pull
