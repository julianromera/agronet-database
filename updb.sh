#!/bin/bash

if [ "x$1" = "x" ];then
    echo "Basic Database Version-Control-System (use git to roll back)"
    echo "$0 <short message about the database changes>"
    exit 1
else
    message="$1"
fi



DATABASE_DIR=`pwd`
AGRONET_DIR="/www/agronet"
NGINX=`which nginx`
GIT=`which git`


if [ ! -f $DATABASE_DIR/history.txt ];then
  echo "There should exist an history.txt file."
  exit 1;
fi

tmpdb() {
  if [ ! -d $AGRONET_DIR ];then
    echo "$AGRONET_DIR is not a directory"
    exit 1;
  fi
  
  cd $AGRONET_DIR
  if [ ! -d ./tmp ];then
    mkdir tmp
  fi
  # echo "pre-disabling APC module.."
  # drush -y pm-disable apc
  echo "cleaning database cache tables.."
  drush -y cc all
  echo "Disabling some modules (Memcache, Varnish, MongoDB) before packaging.."
  drush -y pm-disable memcache varnish mongodb
  
  drush sql-dump --result-file=$AGRONET_DIR/tmp/agronet-db.sql 1>/dev/null
  tar -czvf $AGRONET_DIR/tmp/agronet-db.sql.tar $AGRONET_DIR/tmp/agronet-db.sql 1>/dev/null
  res=$?

  echo "Re-enabling optional services.."
  drush -y en memcache varnish mongodb mongodb_field_storage mongodb_watchdog

  
  if [ $res -ne 0 ];then
    echo "error creating database dump"
    exit 1;
  fi
  cp $AGRONET_DIR/tmp/agronet-db.sql.tar $DATABASE_DIR
  cp $AGRONET_DIR/tmp/agronet-db.sql $DATABASE_DIR/sql
  res=$?
  
  cd $DATABASE_DIR
  
  if [ $res -eq 0 ];then
    # updating database-update history
    echo "`date` $message" >> $DATABASE_DIR/history.txt 
  else
    echo "unexpected error: permissions (?)"
    exit 1;
  fi
  echo "done."
}

echo "Saving database..."

tmpdb

if [ "x$NGINX" != "x" ];then
  echo "saving changes.."
  git add .
  git commit -am "$message"
fi

if [ "x$NGINX" != "x" ];then
  echo "restarting.."
  service nginx restart
fi



exit 0;


