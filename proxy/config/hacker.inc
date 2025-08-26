root /var/www/http;
gzip_static on;
keepalive_timeout 0s;
lingering_close off;

# block attempts to reduce the volume of data returned
max_ranges 0;
if_modified_since off;
etag off;

location ~ .ya?ml$ {
	set $custom_extra "hacker";
	try_files /bomb.yaml =444;
}

location ~ .json$ {
	set $custom_extra "hacker";
	try_files /bomb.json =444;
}

location ~ .xml$ {
	set $custom_extra "hacker";
	try_files /bomb.xml =444;
}

set $custom_extra "hacker"; # note: `set` is not automatically inherited by sub-locations
try_files /bomb.html =444;
