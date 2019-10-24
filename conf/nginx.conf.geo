
user  root;
worker_processes  1;

error_log  logs/error.log;

events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"'
                      'geo $geo';

    access_log  logs/access.log  main;

    geo $remote_addr $geo {
        ranges;
        default beijing;
        192.168.137.1-192.168.137.100 shanghai;
        192.168.137.101-192.168.137.255 guangzhou;
    }

    upstream pa {
        server 192.168.137.201:8080;
    }

    server {
        listen       80;
        server_name  localhost;

        location / {
            proxy_pass http://pa;
        }
    }
}

