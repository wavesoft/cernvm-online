#!/bin/bash

#
# Constants
#

GIT_REPO="https://github.com/cernvm/cernvm-online.git"
BASE_DIR="/var/www/cernvm-online"
SCRIPT_PATH=$(cd $(dirname $BASH_SOURCE) && pwd)
LOG_FILE="$SCRIPT_PATH/log.txt"
rm $LOG_FILE 2> /dev/null # clean files

# Load utilities
source $SCRIPT_PATH/utils.sh

#
# Installation state
# Global variables
#

declare -a STEPS=("make_dirs export_source prepare_python_env install_mysql install_cmvo configure_cvmo make_public install_apache")
declare -a STEPS_BACKTRACE=()

#
# Step handlers
# each step consists of two methods:
#   * <Step name>_do
#   * <Step name>_undo
#

################################################################################
function make_dirs_do
{
    managed_exec mkdir -p $BASE_DIR
    return $?
}
function make_dirs_undo
{
    managed_exec rm -Rf $BASE_DIR
    return $?
}
################################################################################
function export_source_do
{
    managed_exec yum install git -y || return $?
    cd $BASE_DIR
    managed_exec git clone $GIT_REPO git
    return $?
}
function export_source_undo
{
    managed_exec rm -Rf $BASE_DIR/git || return $?
    managed_exec yum remove git -y
    return $?
}
################################################################################
function prepare_python_env_do
{
    managed_exec yum install python-pip python-devel gcc -y
    return $?
}
function prepare_python_env_undo
{
    managed_exec yum remove python-pip python-devel gcc -y
    return $?
}
################################################################################
function install_cmvo_do
{
    cd $BASE_DIR/git/src
    managed_exec python setup.py sdist || return $?
    managed_exec pip install --install-option="--prefix=$BASE_DIR" --upgrade dist/CernVM-Online-1.0.tar.gz || return $?
    cd ../../
    managed_exec rm -Rf $BASE_DIR/git || return $?
    managed_exec mkdir $BASE_DIR/logs
    return $?
}
function install_cmvo_undo
{
    if [ -d $BASE_DIR/git ]; then
        managed_exec rm -Rf $BASE_DIR/git || return $?
    fi
    managed_exec rm -Rf $BASE_DIR/lib || return $?
    managed_exec rm -Rf $BASE_DIR/bin || return $?
    managed_exec rm -Rf $BASE_DIR/logs
    return $?
}
################################################################################
function configure_cvmo_do
{
    managed_exec cp $SCRIPT_PATH/config.py $BASE_DIR/lib/python2.6/site-packages/cvmo/config.py
    return $?
}
function configure_cvmo_undo
{
    managed_exec rm $BASE_DIR/lib/python2.6/site-packages/cvmo/config.py
    return 0
}
################################################################################
function make_public_do
{
    managed_exec mkdir $BASE_DIR/public_html || return $?
    export PATH="$PATH:$BASE_DIR/bin"
    export PYTHONPATH="$PYTHONPATH:$BASE_DIR/lib/python2.6/site-packages"
    export PYTHONPATH="$PYTHONPATH:$BASE_DIR/lib64/python2.6/site-packages"
    managed_exec $BASE_DIR/bin/manage.py collectstatic --noinput
    return $?
}
function make_public_undo
{
    managed_exec rm -Rf $BASE_DIR/public_html
    return $?
}
################################################################################
function install_mysql_do
{
    managed_exec yum install mysql-devel -y || return $?
    managed_exec pip install mysql-python
    return $?
}
function install_mysql_undo
{
    managed_exec yum remove mysql-devel -y || return $?
    managed_exec pip uninstall mysql-python
    return $?
}
################################################################################
function install_apache_do
{
    managed_exec yum install httpd mod_wsgi -y || return $?
    managed_exec cp $SCRIPT_PATH/app.wsgi $BASE_DIR/bin/app.wsgi || return $?
    managed_exec cp $SCRIPT_PATH/cernvm-online.conf /etc/httpd/conf.d/b_cernvm-online.conf || return $?
    managed_exec mv /etc/httpd/conf.d/wsgi.conf /etc/httpd/conf.d/a_wsgi.conf || return $?
    managed_exec chown apache:apache $BASE_DIR -R || return $?
    # seLinux fix
    managed_exec setsebool -P httpd_can_network_connect on || return $?
    managed_exec /etc/init.d/httpd restart
    return $?
}
function install_apache_undo
{
    managed_exec yum remove httpd mod_wsgi -y || return $?
    managed_exec setsebool -P httpd_can_network_connect off || return $?
    managed_exec rm -Rf /etc/httpd
    return $?
}
################################################################################

# Main
main

