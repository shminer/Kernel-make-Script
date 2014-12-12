#!/bin/bash

# ${HOME}/
# ${HOME}/lg
# 
# 这是一个编译内核并且打包内核的脚本工具，同时可以制作zip卡刷包。
# 你需要有以下目录。
# 如果ramdisk是已经打包好的，就需要在mkbootimg里面制定ramdisk文件的具体路径。
# cfg和num变量是作为一个型号存在这个脚本的，真正的defconfig是通过cfg来实现的，num是装载所有型号或者config的容器。
# 如果更换源码，需要重新编辑cfg功能，包括’pack_ramdisk‘和‘make_kernel’函数中的cfg变量。
# arm构架设置和交叉编译工具可以使用相对路径。
# 部分ramdisk的代码只能适用于当前G2的ramdisk，因为其存在特殊app。
# 内核打包参数需要根据机器和官方参数设置。
# 如果从我的git上fork，设置好目录后可以直接编译内核。
###################################################################################################################
#主目录
main=${HOME}/lg/build
# 内核目录
ker=${HOME}/lg/LG-G2-Kernel
# boot暂存目录
boot=${HOME}/lg/boot
# zip输出目录
out=${HOME}/lg/zipoutput
# zip打包的文件目录
kw=${HOME}/lg/kernel-working
# ramdisk目录
rd=${HOME}/lg/LG-G2-D802-Ramdisk
# ramdisk临时目录
rdt=${boot}/temp/rd-temp
# 临时目录
tmp=${boot}/temp
da=`date +%y_%m_%d`
thr=`grep processor /proc/cpuinfo -c`
# 设置交叉编译工具目录变量
export CROSS_COMPILE=${HOME}/lg/LG-G2-Kernel/android-toolchain/bin/arm-eabi-
# 设置变量arm构架
export arch=arm
#############################设置内核打包参数################################
base=0x00000000
offset=0x05000000
ta=0x04800000
pg=2048
cmdline="console=ttyHSL0,115200,n8 androidboot.hardware=g2 user_debug=31 msm_rtb.filter=0x0 mdss_mdp.panel=1:dsi:0:qcom,mdss_dsi_g2_lgd_cmd"
#############################################################################

# 打包ramdisk函数
pack_ramdisk()
{
			if [ -e $ker/arch/arm/boot/zImage ];then
				echo "pack ramdisk:内核已经准备好，准备打包ramdisk。"
				# 自动设置文件名
				if [ -e ./version ];then
					echo "pack ramdisk:找到‘version‘"
				else
					echo "pack ramdisk:找不到’version‘"
					touch version
				fi
				sub=$(grep 'SUBLEVEL =.*' ${ker}/Makefile| sed '1,4s/ //g'| sed '1,4s/SUBLEVEL=//g');
				rdsub=$(grep 'ver-.*LINUX' ${rd}/ROOT-RAMDISK/res/customconfig/customconfig.xml | sed '1,11s/ //g'| sed '1,11s/.*3.4.//g' |sed '1,11s/"name=.*//g');
				if [  $sub != $rdsub ];then
				echo "pack ramdisk:升级app linux版本"
				sed -i -e "1,11s/$rdsub/$sub/" ${rd}/ROOT-RAMDISK/res/customconfig/customconfig.xml;
				fi
				ver1=$(grep 'ver-.*LINUX' ${rd}/ROOT-RAMDISK/res/customconfig/customconfig.xml | sed 's/ //g'| sed 's/.*ver-//g' |sed 's/\..*//g');
				ver2=$(grep 'ver-.*LINUX' ${rd}/ROOT-RAMDISK/res/customconfig/customconfig.xml | sed -e '1,11s/ //g'| sed  -e '1,11s/LIN.*//g'| sed -e '1,11s/.*ve.*\.//g' ) ;
				ver3=$(grep 'ver-.*LINUX' ${rd}/ROOT-RAMDISK/res/customconfig/customconfig.xml | sed 's/ //g'| sed 's/.*ver-//g' |sed 's/LIN.*//g');
				if [ -e  ${tmp}/mkflag ];then
					echo "pack ramdisk:不升级内核编译版本。"
					else
					let "ver2=${ver2}+1";
					if [ $ver2 -ge "10" ] || [ $ver1 -le "0" ];then
						ver2=0
						let "ver1=${ver1}+1";
					fi
				fi
				code=${ver1}"."${ver2}
				echo ${ver1}"."${ver2} > version
				sed -i -e "1,11s/$ver3/$code/" ${rd}/ROOT-RAMDISK/res/customconfig/customconfig.xml;
				cd ${rd}
				if [ -e /usr/bin/git ];then
						git commit -am "自动提交GIT:升级ramdisk版本。";
						else
						echo "pack ramdisk:请安装GIT。"
				fi
				cd ${main}
				fm=LG-${cfg}-kernel-ver-${code}-$da-${relase}.zip
				cp -a ${rd}/ROOT-RAMDISK/* ${rdt}
				cp -a ${rd}/${cfg}-RAMDISK/* ${rdt}
				if [ -e  ${boot}/img/ramdisk.gz ];then
					rm ${boot}/img/ramdisk.gz
				fi
				${boot}/tool/mkbootfs ${rdt} | gzip > ramdisk.gz 2>/dev/null
				mv ramdisk.gz $boot/img
				if [ "$(ls ${rdt} | wc -l )"  != "0" ] ;then
					rm -r ${rdt}/*
					echo "pack ramdisk:清空临时ramdisk目录。"
				fi
				cp $ker/arch/arm/boot/zImage $boot/img/zImage
				$boot/tool/mkbootimg --kernel $boot/img/zImage --ramdisk $boot/img/ramdisk.gz --cmdline "${cmdline}" --base ${base} --offset ${offset} --tags-addr ${ta} --pagesize ${pg} --dt $boot/img/dt.img -o $boot/boot.img
				echo "pack ramdisk:list dt.img & boot.img"
				ls $boot/img/dt.img
				ls $boot/boot.img
				mv $boot/boot.img $kw/boot.img
				echo "pack ramdisk:BUMP内核！"
				mk_flag
				r2=`ls $kw/system/lib/modules/ | wc -l`
				if [ "${r2}"  != "0" ] ;then
					echo "pack ramdisk:清空内核模块目录。"
					rm $kw/system/lib/modules/*
				fi
				find $ker/ -name *.ko -exec cp -f {} $kw/system/lib/modules/ \;
				cp ../texfat.ko $kw/system/lib/modules/;
				# strip not needed debugs from modules.
				android-toolchain/bin/arm-LG-linux-gnueabi-strip --strip-unneeded ${kw}/system/lib/modules/* 2>/dev/null
				android-toolchain/bin/arm-LG-linux-gnueabi-strip --strip-debug ${kw}/system/lib/modules/* 2>/dev/null
				cd $kw
				zip -r temp.zip *
				cd ..
				mv $kw/temp.zip ${out}/${fm}
				ls ${out}/${fm}
				echo "pack ramdisk:编译 boot.img ->${cfg} 成功。"
				else
				echo "pack ramdisk:编译失败，没有找到zImage。"
			fi
		echo "today$da"
}

# function make kernel
make_kernel()
{
		ccache -c
			# 我这里使用型号识别defconfig，如果编译其他内核，还需要把整个cfg变量都设置为config文件名。
			config=$ker/arch/arm/configs/dorimanx_${cfg}_defconfig
				if [ -e $ker/arch/arm/boot/zImage  ] || [ -e $boot/img/dt.img ] ||  [ -e $boot/img/zImage ] || [ -e $boot/img/zImage ];then

					if [ -e $boot/img/dt.img ];then
						echo "make kernel:清除DT.img。"
						rm $boot/img/dt.img
					fi

					if [ -e $boot/img/zImage ];then
					echo "make kernel:删除 zImage。"
					rm $boot/img/zImage
					fi

					if [ -e $kw/boot.img ];then
						echo "make kernel:清空 boot.img。"
						rm $kw/boot.img
					fi

					echo "make kernel:清除完毕。"
					else
					echo "make kernel:编译目录是干净的。"
				fi
				echo "make kernel:准备编译内核。"
				cd $ker
				echo "$config"
				for i in `find . -type f \( -iname \*.rej \
                                -o -iname \*.orig \
                                -o -iname \*.bkp \
                                -o -iname \*.ko \
                                -o -iname \*.c.BACKUP.[0-9]*.c \
                                -o -iname \*.c.BASE.[0-9]*.c \
                                -o -iname \*.c.LOCAL.[0-9]*.c \
                                -o -iname \*.c.REMOTE.[0-9]*.c \
                                -o -iname \*.org \)`; do
								rm -vf $i;
				done;
				make  clean && make mrproper
				cp $config .config;
				# time make -j$thr $config
				time make -j${thr}
				cd ..
				$ker/scripts/dtbTool -s 2048 -o $boot/img/dt.img $ker/arch/arm/boot/
				echo "make kernel:编译完毕。"
}

kernel_bump()
{
	py_check=$(ls -la /usr/bin/python2 | wc -l);
	if [ "${py_check}" -eq "1" ]; then
		/usr/bin/python2 ${main}/open_bump.py ${kw}/boot.img;
		rm ${kw}/boot.img
		mv ${kw}/boot_bumped.img ${kw}/boot.img
fi;
}

# 内核版本升级标识
mk_flag()
{
	echo "Maintask:输入‘y’升级编译版本。"
	read ju1
	if [ "${ju1}" = "y" ] || [ "${ju1}" = "Y" ];then
		if [ -e ${tmp}/mkflag ];then
			 rm ${tmp}/mkflag;
		fi
		else
		touch ${tmp}/mkflag;
	fi
}
# now let`s start
echo "Maintask:输入defconfig信息。"
read num
echo "Maintask:输入'Y'仅重新打包ramdisk，任意键重新编译内核。"
read ju
if [ "${ju}" = "y" ] || [ "${ju}" = "Y" ];then
		echo "Maintask:仅重新打包ramdisk并且制zip卡刷包。"
		relase=rrd
		mk_flag
		for cfg in ${num} ; do
			echo $cfg
			pack_ramdisk
		done
		else
		echo "Maintask:编译内核并且打包ramdisk制作成zip卡刷包。"
		relase=mkpr
		mk_flag
		for cfg in ${num} ; do
			echo $cfg
			make_kernel
			pack_ramdisk
		done
fi
