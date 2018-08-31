#!/bin/bash
#Scripts Name:itxg(beta)
version=0.2.1
#Owner:shengbao
#Support URL:shengbao.org
#Update URL:shengbao.org
#Changelog:
#20171017:代码重构,支持将网站上传到腾讯云COS、阿里云OSS、七牛云存储.(v0.1.0)
#20171018:修复cos.conf判断错误.(v0.1.1)
#20171023:增加阿里云多站点备份.(v0.1.2)
#20171025:增加腾讯云多站点备份.(v0.1.3)
#20171029:修复阿里云下crontab不能正常上传bug(v0.1.4)
#20171030:修复阿里云/腾讯云修改key后，备份报错问题。移动pip判断到相应位置（v0.1.5）
#20171202:修复腾讯云与阿里云周期删除失败BUG(v0.1.6)
#20171204:修复mysqldump某些小bug.(v0.1.7)
#20180112:增加更新源地址、修改小bug(v0.1.8)
#20180524:更新腾讯cos上传。(v0.1.9)
#20180603:日常修复。(v0.2.0)
#20180831:日常修复,/usr/bin/env mysqldump。(v0.2.1)
stty erase '^H'
backuptime=`date +%Y%m%d`
rmbackuptime=`date -d "-"$rmdate" days" +%Y%m%d`
#更新选项
        case $1 in
                update)
                        echo 正在下载更新,请稍后....
                        rm -rf itxg.sh >> /dev/null 2>&1
                        wget --spider -q -o /dev/null  --tries=1 -T 5 shengbao.org
                        if [ "$?" -eq 0 ];then 
                            wget https://shengbao.org/tools/itxg.sh
                        else
                            wget http://update.itxueguan.com/itxg.sh
                        fi
                        mv itxgt.sh $0
                        echo "更新完毕.请重新运行"$0""
                        exit 0
                ;;
        esac
#更新选项结束
#判断是否存在更新版本
v=`curl https://shengbao.org/tools/itxg.sh|awk NR==3|awk -F= '{print $2 }'`
clear
if [ `expr $version \> $v` -eq 0 ] && [ `expr $version \= $v` -eq 0 ];then
        echo 有更新,请退出后输入命令:sh "$0" update ,10秒后继续....
        sleep 10
else
        echo 无更新,2秒后继续...
        sleep 2
fi
#判断更新结束
if [ ! -f itxg.conf ];then
cat >itxg.conf <<EOF
####----公共----####
#当前配置文件版本
conf_version=$version
#enable=tengxun为开启备份到腾讯,qiniu为备份到七牛,aliyun为备份到阿里云
enable=
#备份周期0天为不删除备份文件
rmdate=0
#开启数据库备份yes,no
db_enable=no
#需要备份的网站目录，绝对路径末尾不需要加/
backup_file=
####----多站点----####
#是否支持多站点,默认为关闭
multistation=no
#数字从0开始，因此2个站点该数字写1
multisitenumber=1
#上传到一个bucket下的不同目录,例如:shengbao itxueguan
multlist=(shengbao itxueguan)
#多站点备份路径,2个站点路径中间以空格分割。绝对路径末尾不需要加/
backup_filelist=(/data1 /data2)

####----数据库----####
#数据库用户名
DB_USER=
#数据库密码
DB_PASS=
#数据库连接地址
DB_HOST=localhost
#数据库名称
DB_NAME=
#多站点数据库名称列表
multdblist=(shdb itxgdb)
####----腾讯----####
#你的bucket名称
txbucketname=
#腾讯secret_key
txsecret_key=
#腾讯txappid
txappid=
#腾讯访问api区域，北京一区华北(ap-beijing-1),北京(ap-beijing),华东(ap-shanghai),华南(ap-guangzhou),西南(ap-chengdu),新加坡(ap-singapore),香港(ap-hongkong),多伦多(na-toronto),法兰克福(eu-frankfurt)
txregion=
####----阿里云----####
#你的bucket名称
albucketname=
#阿里云access_id
alaccess_key_id=
#阿里云secreret_key
alaccess_key_secret=
#阿里云endpoint
alendpoint=
####----七牛----####
#你的证书ID
qnak=
#你的证书key
qnsk=
#你的bucket名称
qiniubucket=
####----结束----####
EOF
        echo "5秒后退出,请编辑`pwd`/itxg.conf"
        sleep 5
        exit 0
fi
. ./itxg.conf
rmbackuptime=`date -d "-"$rmdate" days" +%Y%m%d`
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
if [ "$multistation" == no ];then
dfs=`df |awk 'NR==2''{print $4}'`
dus=`du -s /"$backup_file"|awk '{print $1}'`
if [ "$dfs" -lt "$dus" ];then
    echo "磁盘空间不能满足备份要求....2秒后退出"
    sleep 2
else
    echo "磁盘空间检查完毕..."
    sleep 2
fi
fi
#判断本地空间是否满足需求完毕
#开始压缩需要备份的网站,并将压缩后文件保存在/itxg目录下
qiniu_backup_file=/itxg/"$backuptime".tar.gz
if [ $db_enable = yes ];then
    if [ "$multistation" == no ];then
#        /usr/local/mariadb/bin/mysqldump --opt -u$DB_USER -p$DB_PASS -h$DB_HOST $DB_NAME  > $backup_file/$backuptime.sql
        /usr/bin/env mysqldump --opt -u$DB_USER -p$DB_PASS -h$DB_HOST $DB_NAME  > $backup_file/$backuptime.sql
        echo "Warning: Using a password on the command line interface can be insecure.为正常"
    fi
    if [ "$multistation" == yes ] && [ ! -z "$multisitenumber" ];then
        for((msnb=0;msnb<="$multisitenumber";msnb++));do
#        /usr/local/mariadb/bin/mysqldump --opt -u$DB_USER -p$DB_PASS -h$DB_HOST ${multdblist["$msnb"]}  > ${backup_filelist["$msnb"]}/$backuptime.sql
        /usr/bin/env mysqldump --opt -u$DB_USER -p$DB_PASS -h$DB_HOST ${multdblist["$msnb"]}  > ${backup_filelist["$msnb"]}/$backuptime.sql

        done
    fi
else
    echo "数据库备份关闭"
fi
if [ "$multistation" == no ];then
    if [ ! -d /itxg ];then
        mkdir /itxg
    fi
    if [ -f /itxg/*.tar.gz ];then
        rm -rf /itxg/*.tar.gz
        echo "删除上次本地备份,开始压缩文件... ..."
        tar -czvf /itxg/"$backuptime".tar.gz "$backup_file" >>/dev/null 2>&1
        rm -rf $backup_file/$backuptime.sql
        echo "压缩文件完成... ..."
    else
        echo "开始压缩文件... ..."
        tar -czvf /itxg/"$backuptime".tar.gz "$backup_file" >>/dev/null 2>&1
        rm -rf $backup_file/$backuptime.sql.gz
        echo "压缩文件完成... ..."
    fi
fi
#结束压缩小备份的网站，并将压缩后的文件保存在/itxg目录下
#多站点压缩开始
if [ "$multistation" == yes ] && [ ! -z "$multisitenumber" ];then
    for((msnb=0;msnb<="$multisitenumber";msnb++));do
    if [ ! -d "/itxg/"${multlist["$msnb"]}"" ];then
        mkdir -p /itxg/"${multlist["$msnb"]}"
    fi
if [ -f "/itxg/"${multlist["$msnb"]}""/*.tar.gz ];then
         echo "开始压缩文件... ... "
        rm -rf "/itxg/"${multlist["$msnb"]}""/*.tar.gz
        tar -czvf "/itxg/"${multlist["$msnb"]}""/"$backuptime".tar.gz "${backup_filelist["$msnb"]}" >>/dev/null 2>&1
        rm -rf "${backup_filelist["$msnb"]}"/$backuptime.sql

else
        echo "开始压缩文件... ..."
        tar -czvf "/itxg/"${multlist["$msnb"]}""/"$backuptime".tar.gz "${backup_filelist["$msnb"]}" >>/dev/null 2>&1
        rm -rf "${backup_filelist["$msnb"]}"/$backuptime.sql.gz
fi
#数据库备份开始
#数据库备份结束
done
fi
#多站点压缩结束
#腾讯云开始
if [ "$enable" == tengxun ];then
    if [ -z "$txbucketname" ] && [ -z "$txaccess_id" ] && [ -z "$txappid" ] && [ -z "$txsecret_key" ] && [ -z "$txregion" ];then 
    echo "腾讯云配置检查失败"
    exit 1    
fi
#检查coscmd环境
    if [ -f /bin/coscmd ];then
        echo "coscmd检测完毕"
    else
        echo "coscmd检测失败，开始安装."
#检查pip环境

if [ -f /bin/pip ];then
        echo "pip检测完毕"
else
        echo "pip检测失败，开始安装."
        yum install -y python-pip
        pip install --upgrade pip
fi
#检查pip环境结束
        git clone https://github.com/tencentyun/coscmd.git
        cd coscmd && python setup.py install 
    fi
#检查coscmd环境结束
#检查./.cos.conf环境开始
    if [ -f ~/.cos.conf ];then
        echo "cos.conf检测完毕"
		rm -rf ~/.cos.conf
        coscmd config -a "$txappid" -s "$txsecret_key" -b "$txbucketname" -r "$txregion"		
    else
        echo "cos.conf检测失败,开始安装."
        coscmd config -a "$txappid" -s "$txsecret_key"  -b "$txbucketname" -r "$txregion"
    fi
#检查./.cos.conf环境结求
#上传开始
    if [ "$multistation" == no ];then
        coscmd upload -r /itxg/"$backuptime".tar.gz "$backuptime".tar.gz >/dev/null 2>&1
#        if [ "$?" -eq 0 ];then
#            echo "腾讯云上传完成"
#        elif [ "$?" -eq 255 ];then
#            echo "腾讯云上传完成"
#        else 
#            echo "腾讯云上传失败"
#        fi
    fi
    if [ "$multistation" == yes ] && [ ! -z "$multisitenumber" ];then
        for((msnb=0;msnb<="$multisitenumber";msnb++));do
            coscmd upload -r "/itxg/"${multlist["$msnb"]}""/"$backuptime".tar.gz  "${multlist["$msnb"]}"/"$backuptime".tar.gz >/dev/null
#            if [ "$?" -eq 0 ];then
#                echo "腾讯云"${multlist["$msnb"]}"/"$backuptime".tar.gz上传完成"
#             elif [ "$?" -eq 255 ];then
#                echo "腾讯云"${multlist["$msnb"]}"/"$backuptime".tar.gz上传完成"
#            else
#                echo "腾讯云"${multlist["$msnb"]}"/"$backuptime".tar.gz上传失败"
#             fi
        done
   fi
#上传结束
#腾讯云删除开始
    if [ ! -z "$rmdate" ];then 
        if [ "$multistation" == no ];then
             coscmd delete -f "$rmbackuptime".tar.gz >/dev/null
            if [ "$?" -eq 0 ];then
                echo "腾讯云"$txbucketname"/"$rmbackuptime".tar.gz删除结束"
            elif [ "$?" -eq 255 ];then
                echo "腾讯云"$txbucketname"/"$rmbackuptime".tar.gz删除结束"
            else
                echo "腾讯云"$txbucketname"/"$rmbackuptime".tar.gz删除失败"
            fi
        fi
        if [ "$multistation" == yes ];then
            for((msnb=0;msnb<="$multisitenumber";msnb++));do
                coscmd delete -f "${multlist["$msnb"]}"/"$rmbackuptime".tar.gz >/dev/null
                if [ "$?" -eq 0 ];then
                    echo "腾讯云"${multlist["$msnb"]}"/"$rmbackuptime".tar.gz删除结束"
                elif [ "$?" -eq 255 ];then
                    echo "腾讯云"${multlist["$msnb"]}"/"$rmbackuptime".tar.gz删除结束"
                else
                    echo "腾讯云"${multlist["$msnb"]}"/"$rmbackuptime".tar.gz删除失败"
                fi
            done
        fi
    else
        echo "备份周期为永久，请注意COS存储使用情况..."
    fi
#腾讯云删除结束
fi

#阿里云开始
if [ "$enable" == aliyun  ];then
    if [ -z "$albucketname" ] && [ -z "$alaccess_key_id" ] && [ -z "$alaccess_key_secret" ] && [ -z "$alendpoint" ];then
        echo "阿里云配置失败"
        exit 1
    fi 
    if [ ! -f ./ossutil64 ];then
        wget http://docs-aliyun.cn-hangzhou.oss.aliyun-inc.com/assets/attach/50452/cn_zh/1506525299111/ossutil64?spm=5176.doc50452.2.3.7XHxTz
        mv ossutil64?spm=5176.doc50452.2.3.7XHxTz ossutil64
		chmod 777 ossutil64
    fi
#阿里云配置检查
    if [ -f .ossutilconfig ];then 
        echo "ossutil配置检测完毕"
		rm -rf `pwd`/.ossutilconfig
		`pwd`/./ossutil64 config -e "$alendpoint" -i "$alaccess_key_id" -k "$alaccess_key_secret" -L EN 
    else 
        echo "ossutil配置检测失败,开始配置"
       `pwd`/./ossutil64 config -e "$alendpoint" -i "$alaccess_key_id" -k "$alaccess_key_secret" -L EN 
    fi
#阿里云配置检查结束
#阿里云上传开始
    if [ "$multistation" == no ];then
    `pwd`/./ossutil64 cp -f /itxg/"$backuptime".tar.gz  oss://"$albucketname"
        if [ "$?" -eq 0 ];then
            echo "阿里云"$backuptime".tar.gz上传完成"
        elif [ "$?" -eq 255 ];then
            echo "阿里云"$backuptime".tar.gz上传完成"
        else
            echo "阿里云"$backuptime".tar.gz上传失败"
        fi
    fi
    if [ "$multistation" == yes ] && [ ! -z "$multisitenumber" ];then
        for((msnb=0;msnb<="$multisitenumber";msnb++));do
	    `pwd`/./ossutil64 cp -f "/itxg/"${multlist["$msnb"]}""/"$backuptime".tar.gz  oss://"$albucketname"/"${multlist["$msnb"]}"/ >/dev/null
	    if [ "$?" -eq 0 ];then
                echo "阿里云"$albucketname"/"${multlist["$msnb"]}"/"$backuptime".tar.gz上传完成"
            elif [ "$?" -eq 255 ];then
                echo "阿里云"$albucketname"/"${multlist["$msnb"]}"/"$backuptime".tar.gz上传完成"
            else
                echo "阿里云"$albucketname"/"${multlist["$msnb"]}"/"$backuptime".tar.gz上传失败"
            fi
        done
    fi
#阿里云上传结束
#阿里云删除开始
if [ ! -z "$rmdate" ];then
    if [ "$multistation" == no ];then
        `pwd`/./ossutil64 rm oss://"$albucketname"/"$rmbackuptime".tar.gz >/dev/null
        if [ "$?" -eq 0 ];then
            echo "阿里云"$albucketname"/"$rmbackuptime".tar.gz删除结束"
        elif [ "$?" -eq 255 ];then
            echo "阿里云"$albucketname"/"$rmbackuptime".tar.gz删除结束"
        else
            echo "阿里云"$albucketname"/"$rmbackuptime".tar.gz删除失败"
        fi
    fi
    if [ "$multistation" == yes ] && [ ! -z "$multisitenumber" ];then
        for((msnb=0;msnb<="$multisitenumber";msnb++));do
           `pwd`/./ossutil64 rm oss://"$albucketname"/"${multlist["$msnb"]}"/"$rmbackuptime".tar.gz >/dev/null
            if [ "$?" -eq 0 ];then
                echo "阿里云"$albucketname"/"${multlist["$msnb"]}"/"$rmbackuptime".tar.gz删除结束"
            elif [ "$?" -eq 255 ];then
                echo "阿里云"$albucketname"/"${multlist["$msnb"]}"/"$rmbackuptime".tar.gz删除结束"
            else
                echo "阿里云"$albucketname"/"${multlist["$msnb"]}"/"$rmbackuptime".tar.gz删除失败"
            fi
        done
    fi
else
    echo "备份周期为永久，请注意OSS存储使用情况..."
    fi
fi
#阿里云删除结束

#七牛云开始
#判断是否是七牛云上传
if [ "$enable" == qiniu ];then
    if [ -z "$qnak" ] && [ -z "$qnsk" ] && [ -z "$qiniubucket" ];then
        echo "七牛云配置检查失败"
        exit 1
    fi
    if [ ! -f ./qshell-linux-x64 ];then
    wget https://dn-devtools.qbox.me/2.1.5/qshell-linux-x64 >/dev/null 2>&1
    chmod 755 qshell-linux-x64
        echo "七牛云安装完成"
    fi
./qshell-linux-x64 account "$qnak" "$qnsk"
    echo "开始上传..."
./qshell-linux-x64 rput "$qiniubucket" "$backuptime".tar.gz /itxg/"$backuptime".tar.gz 
    if [ "$?" -eq 0 ];then
        echo "七牛云上传完成"
    else
        echo "七牛云上传失败"
    fi
#七牛云删除开始
    if [ ! -z "$rmdate" ];then
        ./qshell-linux-x64 delete "$qiniubacket" "$rmbackuptime".tar.gz > /dev/null
         if [ "$?" -eq 0 ];then
                echo "七牛云删除结束"
        else
                echo "七牛云删除失败"
         fi
     else
        echo "备份周期为永久，请注意七牛存储使用情况..."
     fi
fi
