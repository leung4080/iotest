#!/bin/bash
#================================================================ 
# Script Name:  IOtest.sh 
# Desciption:   测试磁盘IO性能;使用dd命令测试; 
# Author:       leung4080@gmail.com              
# Date:         2011-12-18 
# Version:	0.1
#================================================================ 


THIS_PID=$$
export LANG=c
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/sbin:/usr/local/sbin
declare -i BlockCount=0
declare -a ReadFile
declare -a WriteFile
declare -a BlockSize=8k
declare -a LOG_DIR
#进入脚本所在目录
SCRIPT_PATH=$(dirname $0);
cd $SCRIPT_PATH;


#sar -u 1  &
#iostat -xdm 1 &




#================测试参数设置======================

#读取测试使用的文件，设置为需要测试的硬盘设备文件。
ReadFile=/dev/sda

#写入测试文件，设置为需要测试的硬盘分区的文件。确保有足够的空间;
#!如果设置不当会破坏文件系统结构。
WriteFile=/home/iotest.tmp

#设置输出日志目录
LOG_DIR="./log"

#设置测试的块数量(块大小为8K),如果不设置则使用内存的2倍大小；
#BlockCount=60702

###########################################################
function check
{

#检查配置。
	if [ -b $ReadFile ] ; then
		echo -e '读取设备文件为:'$ReadFile;
	else
		echo $ReadFile"不是块文件，请检查脚本，重新设置ReadFile变量";
		exit 1;
	fi

#根据内存大小计算测试的文件大小。
if [ $BlockCount == "0" ] ; then
	MEM=`grep MemTotal /proc/meminfo | /bin/awk '{print $2}'`
    BlockCount=`expr $MEM / 8 \* 2`

fi

TotleSize=`expr $BlockCount / 128 `MB;

#检查是否有足够磁盘空间

	FreeSize=`/bin/df -kP  $(dirname $WriteFile)  | /bin/awk '/dev/{print $4}'`

	if (( "$FreeSize" > "$((BlockCount * 8))" )) ; then
		echo -e "写入测试的文件为："$WriteFile"\n"$(dirname $WriteFile)"可用空间为："`expr $FreeSize / 1024 `"MB";
	else
		echo "[error]$(dirname $WriteFile) 空间不足，请确保至少"$TotleSize"大小的可用磁盘，以供测试。"
		echo "调整脚本中的WriteFile变量，或者清理磁盘空间后重新执行脚本。exit now!"
		exit 1;
	fi

}


function IOTEST(){


    case $1 in
      "0")
        IFILE=$ReadFile
	OFILE=/dev/null
	SIG_STR="读取"
	LOG_FILE="Read"
	;;
      "1")
	IFILE=/dev/zero
	OFILE=$WriteFile
	SIG_STR="写入"
	LOG_FILE="Write"
	;;
      "2")
	IFILE=$ReadFile
	OFILE=$WriteFile
	SIG_STR="读写"
	LOG_FILE="RW"
	;;
      *)
        echo "错误传参;"
	exit 1
	;;
    esac


echo "========开始*$SIG_STR*测试========"
echo "==================================================================="
echo "##执行dd if=$IFILE of=$OFILE bs=$BlockSize count=$BlockCount 命令##"
echo "==================================================================="；
        

    if [ -f /usr/bin/iostat ]; then
       /usr/bin/iostat -xdm  1 > ./tmp/iostat.tmp &
       IOSTAT_PID=$!
       /usr/bin/sar -u 1 |tee ./tmp/sar.tmp  &
       SAR_PID=$!

       SYSSTAT=1;
    else
       SYSSTAT=0; 
       echo "未安装SysStat组件,不记录性能数据"
    fi
    
    NOWTIME=`date +"%Y%m%d_%H%M%S"`

#    echo "===================================================================" 
#    echo "##执行dd if=$IFILE of=$OFILE bs=$BlockSize count=$BlockCount 命令##"
#    echo "==================================================================="；
#使用dd命令进行IO测试
    (time dd if=$IFILE of=$OFILE bs=$BlockSize count=$BlockCount)>& ./tmp/ddlog.tmp

	if [ $SYSSTAT == 1 ]; then
    kill -15 $IOSTAT_PID $SAR_PID 2>&1 >/dev/null
    fi

    if [ -f $WriteFile ] ; then
        echo "========删除$WriteFile文件========"
    	rm -f $WriteFile;
    fi

    
    echo "=============================="
    echo "测试结果:"
    cat ./tmp/ddlog.tmp


#日志文件处理;
if [ $SYSSTAT == 1 ] ; then
	FILENAME=$LOG_DIR"/"$LOG_FILE"_IO_"$NOWTIME;
	TMP=${ReadFile##*/} 
	TMP=`expr substr $TMP 1 3`;
	grep "Dev" ./tmp/iostat.tmp |head -1 >>$FILENAME;
	LINE=`grep $TMP ./tmp/iostat.tmp |wc -l`;
	grep $TMP ./tmp/iostat.tmp |head -`expr $LINE - $LINE / 10`|tail -`expr $LINE - $LINE / 10 - $LINE / 10` >> $FILENAME;
	
	FILENAME=$LOG_DIR"/"$LOG_FILE"_CPU_"$NOWTIME;
	grep 'user' ./tmp/sar.tmp  >>$FILENAME;
	LINE=`grep 'all' ./tmp/sar.tmp |wc -l `;
	grep 'all' ./tmp/sar.tmp |head -`expr $LINE - $LINE / 10`|tail -`expr $LINE - $LINE / 10 - $LINE / 10` >> $FILENAME;

fi

	FILENAME=$LOG_DIR"/"$LOG_FILE"_dd_"$NOWTIME;
	cp ./tmp/ddlog.tmp $FILENAME;
	/bin/awk '/copied/{print "[" strftime("%Y-%m-%d %H:%M:%S")"] "$8" "$9}' ./tmp/ddlog.tmp  >>  "./"$LOG_FILE".out"

}

###############################################


if [ -f $SCRIPT_PATH/tmp/.iotest.lck ]; then
        echo "[error]上次运行脚本，未正常退出。如果确认进程(PID:`echo $THIS_PID`)已不存在，手动删除$SCRIPT_PATH/tmp/.iotest.lck文件:rm -f $SCRIPT_PATH/tmp/.iotest.lck ；"
        exit 1;
else
        echo $THIS_PID > $SCRIPT_PATH/tmp/.iotest.lck;
fi

################

check;

echo "========开始测试IO性能========"
echo "=============================="
echo "当前时间:"`date`
echo -e "读取测试文件为: "$ReadFile"\t写入测试文件为："$WriteFile"\t测试文件大小为："$TotleSize
echo "=============================="


#设置目录及权限
if [ -d $LOG_DIR ] ; then
    chmod 644 $LOG_DIR;
else
    mkdir $LOG_DIR;
    chmod 644 $LOG_DIR;
fi


if [ -d tmp ] ; then
    chmod 777 ./tmp
else
    mkdir ./tmp
    chmod 777 ./tmp
fi




IOTEST 0;
sleep 10;

IOTEST 1;
sleep 10;

IOTEST 2;


if [ -f $SCRIPT_PATH/tmp/.iotest.lck ]; then
 rm -f $SCRIPT_PATH/tmp/.iotest.lck;
fi 


exit 0;
