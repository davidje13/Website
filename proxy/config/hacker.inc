root /var/www/http;
gzip_static on;
lingering_close off;

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
