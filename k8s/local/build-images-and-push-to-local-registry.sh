#!/bin/sh
docker build -t localhost:5000/nginx ../../nginx/.
docker push localhost:5000/nginx
docker build -t localhost:5000/hello ../../hello/.
docker push localhost:5000/hello