#!/bin/bash
jekyll build
cp deploy/.htaccess _site
TARGETFOLDER='/WEB'
SOURCEFOLDER='_site'

lftp -f "
open $HOST
user $USER $PASS
mirror --reverse --delete --parallel=10 --verbose $SOURCEFOLDER $TARGETFOLDER
bye
"
