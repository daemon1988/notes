#!/bin/bash

# insert into /etc/crontab
# 0 */2 * * * root /opt/mysqldump/mysqlBack.sh

CRTDIR=/opt/mysqldump
MASTERBACK=/opt/mysqldump/licenseweb-master
MYSQLBACK=/opt/mysqldump/licenseweb-mysql
CASSANDRABACK=/opt/mysqldump/licenseweb-cassandra
MASTERFILE=master-$(date +%Y-%m-%d).sql
MYSQLFILE=mysql-$(date +%Y-%m-%d).sql
CASSANDRABACK=/opt/mysqldump/licenseweb-cassandra
CASSANDRAFILE=backup


if [ ! -d "${CRTDIR}/licenseweb-mysql" ]; then
  mkdir -p ${CRTDIR}/licenseweb-mysql
fi

if [ ! -d "${CRTDIR}/licenseweb-master" ]; then
  mkdir -p ${CRTDIR}/licenseweb-master
fi

if [ ! -d "${CRTDIR}/licenseweb-cassandra" ]; then
  mkdir -p ${CRTDIR}/licenseweb-cassandra
fi

if [ -e /opt/mysqldump/log_function.sh ]
then
source /opt/mysqldump/log_function.sh
else
echo -e "\033[41;37m /opt/mysqldump/log_function.sh is not exist. \033[0m"
exit 1
fi

backup(){
log_correct "begin to mysql backup"
mysqldump -uroot -plenovocloud licenseweb-master > ${MASTERBACK}/${MASTERFILE}
mysqldump -uroot -plenovocloud licenseweb > ${MYSQLBACK}/${MYSQLFILE}
}


delete(){

if [ ! -f "${MASTERBACK}/${MASTERFILE}" ]; then
  echo backup licenseweb-master failed
else
  OLDFILE=$(find /opt/mysqldump/licenseweb-master/  -type f -name '*.sql'  -mtime +0)
  rm -rf ${OLDFILE}
  echo backup licenseweb-master success
fi


if [ ! -f "${MYSQLBACK}/${MYSQLFILE}" ]; then
  echo backup licenseweb-mysql failed
else
  OLDFILE=$(find /opt/mysqldump/licenseweb-mysql/  -type f -name '*.sql'  -mtime +0)
  rm -rf ${OLDFILE}
  echo backup licenseweb-mysql success
fi

}

mastersize(){

cd /opt/mysqldump/licenseweb-master
do=$(du -sh ${MASTERFILE})
if [ -s ./${MASTERFILE} ] ;then
   log_correct 'master backup successfully, '$do
else
   log_error 'master backup failed'
fi

}

mysqlsize(){

cd /opt/mysqldump/licenseweb-mysql
do=$(du -sh ${MYSQLFILE})
if [ -s ./${MYSQLFILE} ] ;then
   log_correct 'mysql backup successfully, '$do
else
   log_error 'mysql backup failed'
fi

}

##delete old snapshot and backup new snapshot
cassan_backup(){
log_correct "begin to cassandra backup"

rm -rf ${CASSANDRABACK}/*

sh /opt/apache-cassandra-3.10/bin/nodetool snapshot -t ${CASSANDRAFILE} licenseweb
}

##find snapshot files and copy to /opt/mysqldump/licenseweb-cassandra
find_and_copy(){
OLDFILE=$(find /opt/apache-cassandra-3.10/data/data -type d -name 't_license-*' -mtime 0)
cp ${OLDFILE}/snapshots/${CASSANDRAFILE}/* ${CASSANDRABACK}
}

delete_snapshot(){
sh /opt/apache-cassandra-3.10/bin/nodetool clearsnapshot -t ${CASSANDRAFILE}
}


backup
delete
mastersize
mysqlsize
cassan_backup
find_and_copy
delete_snapshot



