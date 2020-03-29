#!/usr/bin/bash

HOME3BS=$HOME/SAOPolars/
TABDIR=Tables/
ARCHIVE=$HOME3BS/$TABDIR/ARCHIVE/
SQL=$HOME3BS/$TABDIR/SQL/

# FITSDIR=/var/www/html/3BS/fits/
FITSDIR=../


for f in $@ ; do

  echo $f \
  && phot2polars -fitsprefix=$FITSDIR -output $f.sql $f \
  || exit 1


  if [ -f $ARCHIVE/$f ] ; then
    echo "The file $f already exists in the data-archive: $ARCHIVE/$f"
    exit 1
  fi

  if [ -f $SQL/$f ] ; then
    echo "The file $f already exists in the sql-archive: $SQL/$f"
    exit 1
  fi


  if psql -q -f $f.sql saopolars 2>&1 | tee $f.log | egrep '^psql.+(ERROR|ОШИБКА)' ; then
    echo "Transaction aborted. Log-file: $f.log" ;
    exit 1 ;
  fi

#  psql -q -f $f.sql saopolars 2>&1 | tee $f.log | grep '^psql.+ERROR' | grep -v ERROR \
#  || { echo "Transaction aborted. SQL-file: $f.sql" ; exit 1 ; }

  rm -f $f.log

  mv -n $f $ARCHIVE
  if [ -f $f ] ; then
    echo "The file was already archived: $f"
    exit 1
  fi

  mv -n $f.sql $SQL
  if [ -f $f.sql ] ; then
    echo "The SQL-file was already processed: $f"
    exit 1
  fi

done
