#!/bin/bash
cd ..
jekyll build
cp deploy/.htaccess _site
cd deploy
source ~/blog_deploy.sh
TARGETFOLDER='/'
SOURCEFOLDER='../_site'

lftp -f "
open $HOST
user $USER $PASS
lcd $SOURCEFOLDER
mirror --reverse --delete --verbose $SOURCEFOLDER $TARGETFOLDER
bye
"
