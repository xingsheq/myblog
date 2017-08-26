chmod 600 id_rsa
mv id_rsa ~/.ssh/id_rsa
rsync -arHz --progress --delete -e 'ssh -p 28529' public/*  root@45.62.102.9:/home/travis/public/