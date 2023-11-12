#!/bin/sh
docker network create my-net
docker container run –d --net=my-net –p 3306:3306 mysql
docker container run –d --net=my-net –v /docs:/docs --name col1 httpd:2.4.58-bookworm
docker container run –d --net=my-net –v /docs:/docs --name col2 httpd:2.4.58-bookworm