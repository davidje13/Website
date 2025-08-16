root /var/www/http;
gzip_static on;
keepalive_timeout 0s;
lingering_close off;
set $custom_extra "hacker"

# block attempts to reduce the volume of data returned
max_ranges 0;
if_modified_since off;
etag off;

location ~ .ya?ml$ {
	try_files /bomb.yaml =444;
}

location ~ .json$ {
	try_files /bomb.json =444;
}

location ~ .xml$ {
	try_files /bomb.xml =444;
}

try_files /bomb.html =444;
