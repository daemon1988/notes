#!/bin/bash
#log function

if [ ! -d "/opt/mysqldump/log" ]; then
   mkdir -p /opt/mysqldump/log
fi

function log_correct () {
DATE=$(date +'%Y-%m-%d %H:%M:%S')
USER=$(whoami)
echo "${DATE} ${USER} execute $0 [INFO] $@" >>/opt/mysqldump/log/log_info.log
}


function log_error (){
DATE=$(date +'%Y-%m-%d %H:%M:%S')
USER=$(whoami)
echo "${DATE} ${USER} execute $0 [ERROR] $@" >>/opt/mysqldump/log/log_error.log
}


function fn_log (){
if [ $? -eq 0 ]
then
log_correct "$@ sucessed!"
echo -e "\033[32m $@ sucessed. \033[0m"
else
log_error "$@ failed!"
echo -e "\033[41;37m $@ failed. \033[0m"
exit
fi
}
