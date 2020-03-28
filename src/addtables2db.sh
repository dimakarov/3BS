#!/usr/bin/bash

HOME3BS=/home/dim/SAOPolars/
TABDIR=Tables/
ARCHIVE=$HOME3BS/$TABDIR/ARCHIVE/
SQL=$HOME3BS/$TABDIR/SQL/

FITSDIR=/var/www/html/3BS/fits/


for f in $@ ; do

  echo $f \
  && phot2polars -fitsprefix=$FITSDIR -output $f.sql $f \
  || exit 1

  mv -n $f $ARCHIVE
  if [ -f $f ] ; then
    echo "The file was already archived: $f"
    exit 1
  fi

  psql -q -f $f.sql saopolars
# 2>&1 | grep '^psql.+ERROR' | grep -v ERROR \
#  || { echo "Transaction aborted. SQL-file: $f.sql" ; exit 1 ; }

  mv -n $f.sql $SQL
  if [ -f $f.sql ] ; then
    echo "The SQL-file was already processed: $f"
    exit 1
  fi

done
