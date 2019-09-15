#!/bin/bash
set -e
chown -R jekyll:jekyll /src
cd /src
apk update
apk add sshpass openssh
gem install 'jekyll-feed'
jekyll build
TARGETFOLDER='/home/ubuntu/data/site'
SOURCEFOLDER='_site/*'

sshpass -p "$PASS" scp -q -o Batchmode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r $SOURCEFOLDER $USER@$HOST:$TARGETFOLDER
