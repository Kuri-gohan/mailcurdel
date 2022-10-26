#!/bin/bash

err_domain="^(([0-9a-zA-Z](-*[a-zA-Z0-9])*)\.)+[a-zA-Z]{2,}$"
err_domain_search="^[0-9a-zA-Z](-*[0-9a-zA-Z]*\.*)+$"
err_user="^([0-9a-zA-Z](_*[a-zA-Z0-9])*)$"

chk_verbose=""

db_pw_key_path="/home/lwh0002/mailcurdel/mailcurdel.key"
if [[ ! -f "$db_pw_key_path" ]] ; then
        echo "db_pw_key_path did't exist"
        exit 100
fi
db_pw_key=`cat $db_pw_key_path`
db_pw=`echo U2FsdGVkX18h+m3RCUQFQXbuRM7dQEs5517nFX1OirE= | openssl enc -aes256 -pbkdf2 -a -k $db_pw_key -d`

db_database_name="mailcurdel"
db_table_name="mailcurdellog"

db_date=`date "+%Y-%m-%d %H:%M (%A)"`
db_id="lwh0002"
db_cmd=''
db_isEmpty='?'

log_path="/var/log/mailcurdel.log"
log_err_path="/var/log/mailcurdel_err.log"

function print_err() {
        echo -e "Usage : mailcurdel.sh [-v] [User@Domain]\n"
}


function search() {
        if [[ $# == 1 ]] && [[ '' != `ls -d /mailData/$1* 2> /dev/null`  ]] ; then
                if [ -d /mailData/$1 ] ; then
                        echo -e "  ---- User List ----  "
                        ls -d /mailData/$1/*
                        echo ''
                else
                        echo -e "\n  --------------------  "
                        ls -d /mailData/`echo $1 | cut -d '.' -f 1`*
                        echo -e "  --------------------  \n"
                        echo you mean?
                fi


        elif [[ $# == 2 ]] && [[ '' != `ls -d /mailData/$1/$2* 2> /dev/null`  ]] ; then
                echo -e "\n  --------------------  "
                ls -d /mailData/$1/$2*
                echo -e "  --------------------  \n"

                echo you mean?
        else
                echo -e "\nno search data...\n"
        fi
}

function arg_chk() {
        if [[ $chk_verbose == '' ]] ; then
                print_err
                exit 1
        fi

        if [[ $user == "" ]] && [[ $domain == "" ]] ; then
                print_err
                exit 1
        elif [[ $domain == "" ]] ; then
                print_err
                exit 1
        elif [[ $user == "" ]] ; then
                search $domain
                exit 1
        fi
}


function err_chk() {
        if [[ $domain =~ $err_domain ]] ; then
                if [ ! -d /mailData/$domain/ ] ; then
                        echo -e $domain' domain has not found\n'
                        search $domain
                        exit 3
                fi
        else
                echo -e 'wrong domain name\n'
                search $domain
                exit 3
        fi

        if [[ $user =~ $err_user ]] ; then
                if [ ! -d /mailData/$domain/$user/ ] && [[ $user != "ALL" ]] ; then
                        echo -e '\n ! user has not found ! \n'
                        search $domain $user
                               exit 4
                elif [[ $user == ALL ]] ; then
                        user='*'
                        echo -e "\nSELECTED FOLDER"
                        ls -d /mailData/$domain/$user/cur/
                        echo ''
                fi
        else
                echo -e 'wrong user name\n'
                exit 4

        fi
}

function mysql_db() {
        echo -e "\n$db_date" >> $log_err_path
        mysql -uroot -p$db_pw -D $db_database_name -e "insert into $db_table_name
                                                (date, ID, CMD, isEmpty)
                                                values('$db_date', '$db_id', '$db_cmd', '$db_isEmpty');
                                        select * from $db_table_name;" 2>> $log_err_path

        for (( i=`grep -n "$db_date" $log_err_path | tail -n 1 |cut -d ":" -f 1`+1 ; i<=`cat $log_err_path | wc -l` ; i++ ))
        do
                if [[ ! `cat $log_err_path | head -n $i | tail -n 1` =~ "mysql: [Warning] Using a password on the command line interface can be insecure." ]] ; then
                        cat $log_err_path | head -n $i | tail -n 1

                fi
        done

}

function main() {
        echo -e "\n[[ "`date`" ]]" >> $log_path
        if [[ '' == `ls /mailData/$domain/$user/cur/* 2> /dev/null` ]] ; then
                db_cmd="ls /mailData/$domain/$user/cur/*"
                echo Empty Folder >> $log_path
                db_isEmpty='Y'
        else
                db_isEmpty='N
                '
                if [[ $chk_verbose == 'y' ]] ; then
                        db_cmd="rm -vf /mailData/$domain/$user/cur/*"
                        $db_cmd >> $log_path
                        echo $db_cmd >> $log_path
                else
                        db_cmd="rm -f /mailData/$domain/$user/cur/*"
                        $db_cmd
                        echo $db_cmd >> $log_path
                fi

                echo -e "done !\n"
        fi
}


while getopts v opts; do
        case $opts in
        v) chk_verbose="y"
                ;;
        \?) print_err
                exit 1
                ;;
        esac
done

for (( i=1 ; i<$(($# + 1)) ; i++ ))
do
        if [[ $(eval echo \$${i}) =~ "@" ]] ; then
                email=$(eval echo \$${i})
                user=`echo $email | cut -d "@" -f 1`
                domain=`echo $email | cut -d "@" -f 2`
                break
        fi
done

if [[ $1 =~ "@" ]] ; then
        chk_verbose="n"
fi

if [[ $# > 2 ]] ; then
        print_err
        exit 1
fi

arg_chk $domain $user
err_chk
main
mysql_db
exit 0
