#!/bin/sh

cd /volume1

for i in `ls | grep nsaftp`; do
  cd /volume1/$i
  find ./ -name ".DS_Store" -exec rm {} ';'

  if [ "`find ./ -mtime +14`" ]; then
    echo ">>> Directory ($i): Files older than 14 days:"
    echo ""
    find ./ -mtime +14 -a -exec rm -rfv {} \;
    echo ""
  fi
done
