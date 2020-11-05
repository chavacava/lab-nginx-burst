# Testbench for burst handling with NGINX
This repo contains a minimal testbench for experimenting with burst handling using NGINX.

The test bench consists in a dummy service and a NGINX proxy in front of it:

```
               #===========#          #===========#
localhost:80/  |   NGINX   |   :8080/ |   Dummy   |
-------------> |   proxy   | -------> |  service  |
               #===========#          #===========#
```

The service single endpoint is `/`, that is it will successfully respond to request like:

`curl http://localhost:80/`

/!\ requests on port `8080` will directly point to the service without passing through the proxy.

## Requirements

To run tests you will need:

1. access to internet
1. `docker`
1. `docker-compose`
1. a load testing tool like `vegeta` or `ab`


## Test steps

1. Modify NGINX configuration (`vim ./nginx/nginx.conf` for example)
1. Deploy the services `./deploy.sh`
1. Start load testing. For example:

    ```
    echo "GET http://localhost:80/" | vegeta attack -workers 1 -duration 5s | vegeta report
    ```

1. `goto 1`

# Doc on configuring NGINX

Take a look to this [blog entry](https://www.nginx.com/blog/rate-limiting-nginx/) and [official doc](https://docs.nginx.com/nginx/admin-guide/security-controls/controlling-access-proxied-http/).