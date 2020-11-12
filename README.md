# Testbench for burst handling with NGINX
This repo contains two versions of a a minimal testbench for experimenting with burst handling using NGINX.

## Local Testbench

The test bench consists in a dummy service and a NGINX proxy in front of it:

```
               #===========#          #===========#
localhost:80/  |   NGINX   |   :8080/ |   Hello   |
-------------> |   proxy   | -------> |  service  |
               #===========#          #===========#
```

The service single endpoint is `/`, that is it will successfully respond to request like:

`curl http://localhost:80/`

/!\ requests on port `8080` will directly point to the service without passing through the proxy.

### Requirements

To run tests you will need:

1. access to internet
1. `docker`
1. `docker-compose`
1. a load testing tool like `vegeta` or `ab`


### Test steps

1. Modify NGINX configuration (`vim ./nginx/nginx.conf` for example)
1. Deploy the services `./deploy.sh`
1. Start load testing. For example:

    ```
    echo "GET http://localhost:80/" | vegeta attack -rate 1/s -workers 1 -duration 5s | vegeta report
    ```

1. `goto 1`

To stop all the test-bench you can do `docker-compose down`

## K8S-based Testbench


```
                   #===========#          #===========#       #===========#          #===========#
proxy-service:80/  |   proxy   |     :80/ |   NGINX   | :80/  |   Hello   |   :8080/ |   Hello   |
-----------------> |  service  | -------> |   proxy   |-----> |   service | -------> |   server  |
                   #===========#          #===========#       #===========#          #===========#
```

### Requirements

To run tests you will need:

1. access to internet
1. `docker`
1. a k8s cluster

### Local and Remote K8S clusters

If you have `kind` installed in your PC you can:
1. create a local k8s cluster with  
```
k8s/local/kind-with-registry.sh
```
1. modify `nginx\nginx.conf` with:
```
  upstream svcfarm {
    server hello-service;
  }
```
1. build images and push them to the local registry: 
```
k8s/local/build-images-and-push-to-local-registry.sh
```
1. deploy the components of the testbench: 
```
k8s/deploy.sh
``` 

To stop all the test-bench you can do 
```
k8s/local/stop-kind-with-registry.sh
```

Launching test:
```
kubectl exec vegeta-pod-name -- /bin/sh -c "echo 'GET http://proxy-service/' | vegeta attack -timeout 100s -rate 2000/s -duration 5s -workers 1 | vegeta report"
```

For remote K8S clusters you can reproduce these steps (no helper scripts are provided)
Please tacke into account that the deployment manifests (`.yml`) make reference to images in the **local** image registry thus they must be adapted to point to a remote registry.

# Doc on configuring NGINX

Take a look to this [blog entry](https://www.nginx.com/blog/rate-limiting-nginx/) and [official doc](https://docs.nginx.com/nginx/admin-guide/security-controls/controlling-access-proxied-http/).

# Some tests

Initial conf:

We set a 3 request/s rate limit
```
  limit_req_zone $binary_remote_addr zone=buff:10m rate=3r/s;
...
      limit_req zone=buff;
```

## Low workload

Attack with 2 request/s:
```
echo "GET http://localhost:80/" | vegeta attack -rate 2/s -workers 1 -duration 60s | vegeta report
```
Observed behavior: 

```
Requests      [total, rate, throughput]  120, 2.02, 2.02
Duration      [total, attack, wait]      59.503913643s, 59.499894314s, 4.019329ms
Latencies     [mean, 50, 95, 99, max]    3.121546ms, 2.973331ms, 4.863628ms, 5.267843ms, 5.417172ms
Bytes In      [total, mean]              1080, 9.00
Bytes Out     [total, mean]              0, 0.00
Success       [ratio]                    100.00%
Status Codes  [code:count]               200:120
```

Notice that:
1. `Request.rate = Request.throughput ~= 2`
1. `total time = attack time ~= 60s`
1. `Success.ratio = 100%`

## Nominal workload

Attack with 3 request/s:
```
echo "GET http://localhost:80/" | vegeta attack -rate 3/s -workers 1 -duration 60s | vegeta report
```
Observed behavior: 

```
Requests      [total, rate, throughput]  180, 3.02, 1.99
Duration      [total, attack, wait]      59.669415667s, 59.666637088s, 2.778579ms
Latencies     [mean, 50, 95, 99, max]    2.309098ms, 2.77329ms, 3.962151ms, 4.497935ms, 5.634312ms
Bytes In      [total, mean]              13088, 72.71
Bytes Out     [total, mean]              0, 0.00
Success       [ratio]                    66.11%
Status Codes  [code:count]               200:119  503:61  
```

Notice that:
1. `Request.rate != Request.throughput`. Why? Because the proxy assures that the rate limit is **never reached**, i.e. throughput < limit
1. `total time = attack time ~= 60s`
1. `Success.ratio < 100%`. Why? Because requests exceeding the rate limit were rejected with a 503 error 

## Burst in workload

Attack with 9 (3x the rate limit) request/s:
```
echo "GET http://localhost:80/" | vegeta attack -rate 9/s -workers 1 -duration 60s | vegeta report
```
Observed behavior: 

```
Requests      [total, rate, throughput]  540, 9.02, 2.42
Duration      [total, attack, wait]      59.890126326s, 59.888685025s, 1.441301ms
Latencies     [mean, 50, 95, 99, max]    1.463143ms, 960.461µs, 3.519723ms, 4.71115ms, 5.352717ms
Bytes In      [total, mean]              79120, 146.52
Bytes Out     [total, mean]              0, 0.00
Success       [ratio]                    26.85%
Status Codes  [code:count]               200:145  503:39
```

Notice that:
1. `Request.rate != Request.throughput`
1. `total time = attack time ~= 60s`
1. `Success.ratio < 100%`. Very low.

# Add `burst` support to the proxy

Modify proxy configuration to enable queueing 100 requests:
```
      limit_req zone=buff burst=100;
```
That queue size 100 is totally arbitrary!

Attack with 9 (3x the rate limit) request/s:
```
echo "GET http://localhost:80/" | vegeta attack -rate 9/s -workers 1 -duration 60s | vegeta report
```
Observed behavior: 

```
Requests      [total, rate, throughput]  540, 9.02, 3.01
Duration      [total, attack, wait]      1m16.337466965s, 59.88888805s, 16.448578915s
Latencies     [mean, 50, 95, 99, max]    5.909288067s, 928.908µs, 16.672118871s, 16.673367358s, 16.673828534s
Bytes In      [total, mean]              63140, 116.93
Bytes Out     [total, mean]              0, 0.00
Success       [ratio]                    42.59%
Status Codes  [code:count]               200:230  503:310
```

Notice that:
1. `Request.rate != Request.throughput`. The throughput is exactly in the rate limit (3 r/s)
1. `total time > attack time`. Why? Because the proxy has queued some requests and these requests where sent to the server respecting the rate limit. If we do the maths and divide the number of successful requests (230) by the total time (76s) we get a rate of 3 r/s. 
1. `Success.ratio < 100%`. Still no 100% success ratio but better than the previous scenario (proxy without burst conf)
1. `Latencies.mean` is not anymore in the order of milliseconds but in that of seconds.  

# Set more capacity to the `burst` queue

Modify proxy configuration to enable queueing 300 requests:
```
      limit_req zone=buff burst=300;
```

Attack with 9 (3x the rate limit) request/s:
```
echo "GET http://localhost:80/" | vegeta attack -timeout 60s -rate 9/s -workers 1 -duration 60s | vegeta report
```
Notice that we added a `-timeout` parameter to the attack. Why? To avoid `vegeta` cancelling long standing requests.

Observed behavior: 

```
Requests      [total, rate, throughput]  540, 9.02, 3.01
Duration      [total, attack, wait]      1m33.008116237s, 59.888803531s, 33.119312706s
Latencies     [mean, 50, 95, 99, max]    12.609513247s, 2.116713415s, 33.341109461s, 33.34220476s, 33.343560192s
Bytes In      [total, mean]              53740, 99.52
Bytes Out     [total, mean]              0, 0.00
Success       [ratio]                    51.85%
Status Codes  [code:count]               200:280  503:260  
```

Notice that:
1. `Request.rate != Request.throughput`. The throughput is exactly in the rate limit (3 r/s)
1. `total time > attack time`. Why? Because the proxy has queued some requests and these requests where sent to the server respecting the rate limit. If we do the maths and divide the number of successful requests (280) by the total time (93s) we get a rate of 3 r/s. 
1. `Success.ratio < 100%`. Still no 100% success ratio but better than the previous scenario (proxy with a burst = 100)

# Set yet more capacity to the `burst` queue

Modify proxy configuration to enable queueing 400 requests:
```
      limit_req zone=buff burst=400;
```

Attack with 9 (3x the rate limit) request/s:
```
echo "GET http://localhost:80/" | vegeta attack -timeout 120s -rate 9/s -workers 1 -duration 60s | vegeta report
```
Notice that we doubled the `-timeout` parameter to the attack. Why? To avoid `vegeta` cancelling long standing requests (see the latencies in the report below)

Observed behavior: GREAT SUCCESS! (Borat)

```
Requests      [total, rate, throughput]  540, 9.02, 3.01
Duration      [total, attack, wait]      2m59.672786339s, 59.888764375s, 1m59.784021964s
Latencies     [mean, 50, 95, 99, max]    59.893884744s, 59.894487912s, 1m53.895318609s, 1m58.694828487s, 1m59.784021964s
Bytes In      [total, mean]              4860, 9.00
Bytes Out     [total, mean]              0, 0.00
Success       [ratio]                    100.00%
Status Codes  [code:count]               200:540
```

Notice that:
1. `Request.rate != Request.throughput`. The throughput is exactly in the rate limit (3 r/s)
1. `total time > attack time`. Why? Because the proxy has queued some requests and these requests where sent to the server respecting the rate limit. If we do the maths and divide the number of successful requests (540) by the total time (180) we get a rate of 3 r/s. 
1. `Success.ratio = 100%`, but
1. `Latencies.mean` is about in the order of minutes.


# A longer overload 

Lets attack with 9 request/s as in previous tests but for a longer period:
```
 echo "GET http://localhost:80/" | vegeta attack -timeout 500s -rate 9/s -workers 1 -duration 120s | vegeta report
 ```

Observed behavior: 

```
Requests      [total, rate, throughput]  1080, 9.01, 3.00
Duration      [total, attack, wait]      4m13.002380025s, 1m59.88874701s, 2m13.113633015s
Latencies     [mean, 50, 95, 99, max]    56.722774064s, 48.781709824s, 2m13.336487837s, 2m13.339201517s, 2m13.340429688s
Bytes In      [total, mean]              69880, 64.70
Bytes Out     [total, mean]              0, 0.00
Success       [ratio]                    70.37%
Status Codes  [code:count]               200:760  503:320
```

Notice that:
1. `total time > attack time`
1. `Success.ratio < 100%` Why? Because even if we have a queue size of 400 that was enough for the scenario of the previous case this test case is longer then at some time of the test (beyond 60s) the queue is full and requests are rejected.

Corollary: the size of the queue depends on both the expected peak of workload **and** the duration of the **peak**
