#!/bin/bash

# Backup Settings
PREFIX="wpbackup"

# Settings for wordpress
WP_HOME=""
MYSQL_DBNAME=""
MYSQL_USER=""
MYSQL_PASS=""

# Settings for Amazon S3
BUCKET=""
FOLDER=""
REDUCED_REDUNDANCY="no"
BACKUP_LIMIT=15

# Create temporary directory
tempdir=$(mktemp -d)

# Dump MySQL databse
mysqldump "$MYSQL_DBNAME" --add-drop-database -l -u"$MYSQL_USER" -p"$MYSQL_PASS"|gzip > $tempdir/database.sql.gz

# Backup wordpress settings & files
cwd="$PWD"
cd "$WP_HOME"
tar czf $tempdir/wordpress.tar.gz wp-admin wp-content wp-includes wp-config.php

# tar all files
cd $tempdir
packagefile="$PREFIX-$(date +%Y-%m-%d_%H.%M.%S.%Z).tar"
tar cf "$packagefile" database.sql.gz wordpress.tar.gz database.sql.gz

# backup file to Amazon S3
if ! s3cmd info s3://$BUCKET|grep "s3://"; then
    s3cmd mb s3://$BUCKET
fi
ARGS=""
if [ "$REDUCED_REDUNDANCY" == "yes" ]; then
    ARGS="$ARGS --rr"
fi
s3cmd put $tempdir/$packagefile s3://$BUCKET/$FOLDER/$packagefile $ARGS

# Delete old backup
tempfile=$(mktemp)
s3cmd ls s3://$BUCKET/$FOLDER/* > $tempfile
cat $tempfile
total=$(cat $tempfile|wc -l)
if [ $(cat $tempfile|wc -l) -gt $BACKUP_LIMIT ]; then
    let overnum=$total-$BACKUP_LIMIT
    cat $tempfile|head -$overnum|while read line
    do
	s3cmd del $(echo $line|sed "s/.*s3:/s3:/g")
    done
fi
rm $tempfile

cd "$cwd"
rm -rf "$tempdir"
