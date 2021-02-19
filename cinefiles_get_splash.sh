#!/usr/bin/env bash

CURL='/usr/bin/curl'
SPLASH_URL="https://raw.githubusercontent.com/BAM-PFA/cinefiles-splash/master/cinefiles_splash.html.erb"
CURLARGS="-o"
OUTPATH="portal/app/views/shared/_splash.html.erb"

$CURL $SPLASH_URL $CURLARGS $OUTPATH
