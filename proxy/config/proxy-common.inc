proxy_http_version 1.1;
proxy_redirect off;
proxy_connect_timeout 5s;

proxy_set_header Forwarded "for=$proxy_forwarded_for;host=$host:443;proto=https";
proxy_set_header X-Real-IP "";
proxy_set_header X-Forwarded-For $remote_addr;
proxy_set_header X-Forwarded-Host $host:443;
proxy_set_header X-Forwarded-Server $host;
proxy_set_header X-Forwarded-Port 443;
proxy_set_header X-Forwarded-Proto https;
