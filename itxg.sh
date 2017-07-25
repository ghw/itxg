#!/bin/bash
#Scripts Name:itxg
version=0.4.6
#Owner:shengbao
#Support URL:www.itxueguan.com
#Update URL:update.itxueguan.com
#Info:初始化版本中腾讯备份python部分转载自张戈博客，特此申明。
#Changelog:
#20170512:初始化版本0.1
#20170513:更新数据库备份
#20170517:更新更新检测及配置文件分离
#20170519:增加备份到阿里云
#20170523:增加判断是否编辑itxg.conf文件
#20170527:增加腾讯云自定义保存周期，删除周期外文件
#20170527:增加上传到百度云盘(第三方上传客户端)
#20170701:增加网站服务检测,增加判断
#20170722:增加支持阿里云经典网络及专有网络备份，修复已知BUG。
#20170722:增加阿里云自动删除保存周期外文件
#20170723:更新备份文件名称，增加年份。增加mysqldump告警信息提醒。
stty erase '^H'
#. ./itxg.conf
backuptime=`date +%Y%m%d`
rmbackuptime=`date -d "-"$rmdate" days" +%Y%m%d`
#pip=`pip show qcloud_cos_v4`
#更新选项
        case $1 in
                update)
                        echo 正在下载更新,请稍后....
                        rm -rf itxg.sh >> /dev/null 2>&1
                        wget http://update.itxueguan.com/itxg.sh
                        mv itxgt.sh $0
                        echo "更新完毕.请重新运行"$0""
                        exit 0
                ;;
        esac
#更新选项结束
#判断是否存在更新版本
v=`curl http://update.itxueguan.com/itxg.sh|awk NR==3|awk -F= '{print $2 }'` 
clear
if [ `expr $version \> $v` -eq 0 ] && [ `expr $version \= $v` -eq 0 ];then
        echo 有更新,请退出后输入命令:sh "$0" update ,10秒后继续....
        sleep 10
else
        echo 无更新,2秒后继续...
        sleep 2
fi
#判断更新结束
#网站服务检测
echo "网站状态检测:"
pgrep -x mysqld &> /dev/null
if [ "$?" -eq 0 ];then
        echo -e "\tMysql OK"
else
        echo -e "\tMysql NO"
        exit
fi
service php status &> /dev/null
if [ "$?" -eq 0 ];then
        echo -e  "\tPhp OK"
else
        service php-fpm status &> /dev/null
        if [ "$?" -eq 0 ];then
                echo -e "\tPhp OK"
        else
                echo -e "\tPhp NO"
                exit
        fi
fi

service httpd status &> /dev/null
if [ "$?" -eq 0 ];then
        echo -e "\twww OK"
else
        service nginx status &> /dev/null
        if [ "$?" -eq 0 ];then
                echo -e "\twww OK"
        else
                echo -e "\twww NO"
                exit
        fi
fi
#网站服务检测结束
if [ ! -f itxg.conf ];then
cat >itxg.conf <<EOF
####----公共----####
#当前配置文件版本
conf_version=$version
#enable=tengxun为开启备份到腾讯,qiniu为备份到七牛,aliyun为备份到阿里云,baiduyun为备份到百度云
enable=
#备份周期0天为不删除备份文件
rmdate=0
#开启数据库备份yes,no
db_enable=yes
#需要备份的网站目录，绝对路径末尾不需要加/
backup_file=
####----数据库---####
#数据库用户名
DB_USER=
#数据库密码
DB_PASS=
#数据库连接地址
DB_HOST=localhost
#数据库名称
DB_NAME=
####----腾讯----####
#你的域名
domain=itxueguan.com
#你的bucket名称
txbucket=
#你的appid
appid=
#你的证书ID
renzhengid=
#你的证书key
renzhengmiyao=
####----七牛----####
#你的证书ID
access_key=
#你的证书key
secret_key=
#你的bucket名称
qiniubucket=
#####----阿里----####
#阿里云内部链接地址,只需要oss...后
aliurl=oss-cn-shenzhen-internal.aliyuncs.com
#阿里云秘钥ID
aliid=
#阿里云秘钥KEY
alikey=
#阿里云Bucket
alibucket=
####----结束----####
EOF
        echo "5秒后退出,请编辑`pwd`/itxg.conf"
        sleep 5
        exit 0 
fi
. ./itxg.conf
#判断itxg.conf文件是否被编辑
if [ -z $enable ];then
        echo "请先编辑:`pwd`/itxg.conf后执行"$0""
        sleep 3
        exit 
fi
if [ `expr $conf_version \> $version` -eq 0 ] && [ `expr $conf_version \= $version` -eq 0 ];then
        sed -i "s/$conf_version/$version/g" itxg.conf
else
        echo "配置文件版本为:"$conf_version"检查完毕"
fi
#判断itxg.conf文件是否被编辑结束
#判断本地空间是否满足需求
dfs=`df |awk 'NR==2''{print $4}'`
dus=`du -s /"$backup_file"|awk '{print $1}'`
if [ "$dfs" -lt "$dus" ];then
    echo "磁盘空间不能满足备份要求....2秒后退出"
    sleep 2
else
    echo "磁盘空间检查完毕..."
    sleep 2
fi
#判断本地空间是否满足需求完毕
#开始压缩需要备份的网站,并将压缩后文件保存在/itxg目录下
qiniu_backup_file=/itxg/"$backuptime".tar.gz
if [ $db_enable = yes ];then
        mysqldump --opt -u$DB_USER -p$DB_PASS -h$DB_HOST $DB_NAME | gzip > $backup_file/$backuptime.sql.gz 
        echo "Warning: Using a password on the command line interface can be insecure.为正常"
fi
if [ ! -d /itxg ];then
        mkdir /itxg
fi
if [ -f /itxg/*.tar.gz ];then
        rm -rf /itxg/*.tar.gz
        echo "删除上次本地备份,开始压缩文件... ..."
        tar -czvf /itxg/"$backuptime".tar.gz "$backup_file" >>/dev/null 2>&1
        rm -rf $backup_file/$backuptime.sql.gz
        echo "压缩文件完成... ..."
else
        echo "开始压缩文件... ..."
        tar -czvf /itxg/"$backuptime".tar.gz "$backup_file" >>/dev/null 2>&1
        rm -rf $backup_file/$backuptime.sql.gz
        echo "压缩文件完成... ..."
fi
#结束压缩小备份的网站，并将压缩后的文件保存在/itxg目录下
#检查pip环境
if [ -f /bin/pip ];then
        echo "pip检测完毕"
else
        echo "pip检测失败，开始安装."
        yum install -y python-pip
        yum install --upgrade pip
fi
#检查pip环境结束
#阿里云环境开始
if [ $enable = aliyun ];then
        if [ `pip show oss2|wc -l` -gt 0 ];then
                echo "oss2检测完毕"
        else
                echo "oss2检测失败,开始安装"
                pip install oss2
        fi
fi
#阿里云环境结束
#腾讯云环境安装开始
if [ $enable = tengxun ];then
        if [ `pip show qcloud_cos_v4|wc -l` -gt 0 ];then
                echo "qcloud_cos检测完毕"
        else
                echo "qcloud_cos检测失败,开始安装"
                pip install pip qcloud_cos_v4
        fi
fi
#腾讯云环境安装结束
#腾讯云python开始
if [ ! -f cos.upload.py ] && [ $enable = tengxun ];then
cat >cos.upload.py <<EOF
# -*- coding: utf-8 -*-
# Upload File To Qcloud COS

from qcloud_cos import CosClient
from qcloud_cos import UploadFileRequest
import sys
if ( len(sys.argv) > 5 ):
    appid      = int(sys.argv[1])
    secret_id  = sys.argv[2].decode('utf-8')
    secret_key = sys.argv[3].decode('utf-8')
    bucket     = sys.argv[4].decode('utf-8')
    domain     = sys.argv[5].decode('utf-8')
    filePath = sys.argv[6].decode('utf-8')
    fileName = filePath.split("/")[-1]
else:
    print("Example: python %s appid secret_id secret_key Bucket itxuegan.com /data/backup.zip" % sys.argv[0])
    exit()
regin_info = "tj"
cos_client = CosClient(appid, secret_id, secret_key,region=regin_info)
request = UploadFileRequest(bucket, '/%s/%s' % ( domain, fileName ), filePath)
request.set_insert_only(0)
upload_file_ret = cos_client.upload_file(request)
print 'The File %s Upload to Bucket %s : %s ' % ( filePath , bucket , upload_file_ret.get('message') )
EOF
fi
#腾讯云python结束
#腾讯云python 删除开始
if [ ! -f cos.del.py ] && [ $enable = tengxun ];then
cat >cos.del.py <<EOF
# -*- coding: utf-8 -*-
# Upload File To Qcloud COS

from qcloud_cos import CosClient
from qcloud_cos import DelFileRequest
import sys
if ( len(sys.argv) > 5 ):
    appid      = int(sys.argv[1])
    secret_id  = sys.argv[2].decode('utf-8')
    secret_key = sys.argv[3].decode('utf-8')
    bucket     = sys.argv[4].decode('utf-8')
    domain     = sys.argv[5].decode('utf-8')
    filePath = sys.argv[6].decode('utf-8')
    fileName = filePath.split("/")[-1]
else:
    print("Example: python %s appid secret_id secret_key Bucket itxuegan.com /data/backup.zip" % sys.argv[0])
    exit()
regin_info = "tj"
cos_client = CosClient(appid, secret_id, secret_key,region=regin_info)
request = DelFileRequest(bucket,filePath)
del_ret = cos_client.del_file(request)
print 'del file ret:',repr(del_ret)
EOF
fi
#腾讯云python删除结束
#阿里云python开始
if [ ! -f oss.upload.py ] && [ $enable = aliyun ];then
cat >oss.upload.py <<EOF
# -*- coding: utf-8 -*-
from __future__ import print_function
import os, sys
import oss2
#
# 百分比显示回调函数
#
def percentage(consumed_bytes, total_bytes):
    if total_bytes:
        rate = int(100 * (float(consumed_bytes) / float(total_bytes)))
        print('\r{0}% '.format(rate), end=filePath)
        sys.stdout.flush()

# 脚本需要传入5个参数
if ( len(sys.argv) > 5 ):
    AccessKeyId     = sys.argv[1]
    AccessKeySecret = sys.argv[2]
    Endpoint        = sys.argv[3] 
    Bucket          = sys.argv[4]
    filePath = sys.argv[5]
    fileName = filePath.split("/")[-1]
# OSS认证并开始上传
auth = oss2.Auth(AccessKeyId , AccessKeySecret)
bucket = oss2.Bucket(auth,  Endpoint, Bucket)
oss2.resumable_upload(bucket, fileName, filePath)
print('\rUpload %s to OSS Success!' % filePath)
EOF
fi
#阿里云python结束
#阿里云python删除开始
if [ ! -f oss.del.py ] && [ $enable = aliyun ];then
cat >oss.del.py <<EOF
# -*- coding: utf-8 -*-
from __future__ import print_function
import os, sys
import oss2
if ( len(sys.argv) > 5 ):
    AccessKeyId     = sys.argv[1]
    AccessKeySecret = sys.argv[2]
    Endpoint        = sys.argv[3]
    Bucket          = sys.argv[4]
    fileName = sys.argv[5]
auth = oss2.Auth(AccessKeyId , AccessKeySecret)
bucket = oss2.Bucket(auth,  Endpoint, Bucket)
exist = bucket.object_exists(fileName)
if exist:
    print(fileName,'删除开始')
    bucket.delete_object(fileName)
else:
    print('删除备份文件',fileName,'失败，该文件不存在')
EOF
fi
#阿里云python删除结束
#判断是否是阿里云上传
if [ -f oss.upload.py ] && [ $enable = aliyun ];then
    if [ ! -z $aliid ];then 
        echo "阿里云开始上传..."
python oss.upload.py "$aliid" "$alikey" "$aliurl" "$alibucket" /itxg/"$backuptime".tar.gz
        if [ "$?" -eq 0 ];then
                echo "阿里云上传完成"
        else
                echo "阿里云备份失败"
        fi
    else
        echo "aliyun未配置"
    fi
    if [ "$rmdate" ] && [ "$rmdate" -gt 0 ];then
python oss.del.py "$aliid" "$alikey" "$aliurl" "$alibucket" "$rmbackuptime".tar.gz
    else
    echo "备份周期为永久，请注意OSS存储使用情况..."
    fi
fi

#判断是否是腾讯云上传
if [ $enable = tengxun ] && [ ! -z $txbucket ];then
        echo "腾讯云开始上传..."
python cos.upload.py "$appid" "$renzhengid" "$renzhengmiyao" "$txbucket" "$domain" /itxg/"$backuptime".tar.gz
        if [ "$?" -eq 0 ];then
                echo "腾讯云上传完成"
        else
                echo "腾讯云上传失败"
        fi
rm -rf $backup_file/$backuptime.sql.gz
#腾讯云删除开始
    if [ "$rmdate" ] && [ "$rmdate" -gt 0 ];then 
python cos.del.py "$appid" "$renzhengid" "$renzhengmiyao" "$txbucket" "$domain" /"$domain"/"$rmbackuptime".tar.gz
        if [ "$?" -eq 0 ];then
                echo "腾讯云删除结束"
        else
                echo "腾讯云删除失败"
        fi
    else
    echo "备份周期为永久，请注意COS存储使用情况..."
    fi
#腾讯云删除结束
#判断是否是七牛云上传
elif [ $enable = qiniu ] && [ ! -z $access_key ];then
    if [ ! -f ./qshell-v2.0.6.zip ];then
    wget http://devtools.qiniu.com/qshell-v2.0.6.zip
fi
    if [ -f ./qshell-v2.0.6.zip ];then
        unzip qshell-v2.0.6.zip
        rm -rf qshell_darwin_*
        rm -rf qshell_windows_*
        rm -rf qshell_linux_arm
        rm -rf qshell_linux_386
        rm -rf qshell-v2.0.6.zip
        mv qshell_linux_amd64 qshell
    fi
./qshell account "$access_key" "$secret_key"
./qshell account
./qshell rput "$qiniubucket" "$backuptime".tar.gz "$qiniu_backup_file"$backup_file/$backuptime.sql.gz
fi
if [ $enable = baiduyun ];then
    echo "百度云python客户端来自于开源项目:https://github.com/houtianze/bypy,本作者(itxg.sh)不负责数据安全。本协议有10秒考虑时间..您可使用ctrl+c结束本进程... ...如果，您想继续，第一次请执行，请复制下面的链接打开浏览器授权，并将授权码粘贴到命令行后回车"
    sleep 10
    if [ `pip show bypy` ];then
        bypy -v upload /itxg/"$backuptime".tar.gz
        echo "上传百度云完成"
    else
        pip install bypy 
        bypy -v upload /itxg/"$backuptime".tar.gz
        echo "上传百度云完成"
    fi
fi
