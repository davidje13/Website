#!/bin/sh
set -e;

BASEDIR="$(dirname "$0")";

gcc -std=c99 -O3 \
	-Wall -Wextra -pedantic \
	"$BASEDIR/monitor.c" -o "$BASEDIR/monitor";
