#!/bin/bash
jekyll build
cp deploy/.htaccess _site
TARGETFOLDER='/'
SOURCEFOLDER='_site'

HOST='cu.ftp.zeus.smartgslb.com'
USER='ftp@b18b742f.host.smartgslb.com'

lftp -f "
open $HOST
user $USER $PASS
mirror --reverse --delete --parallel=10 --verbose $SOURCEFOLDER $TARGETFOLDER
bye
"
