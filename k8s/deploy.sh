#!/bin/sh
kubectl apply -f vegeta.yml 
kubectl apply -f hello.yml
kubectl apply -f hello-service.yml
kubectl apply -f proxy.yml
kubectl apply -f proxy-service.yml