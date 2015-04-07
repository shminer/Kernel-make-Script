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
# 主目录
main=~/lg/f460
#工具目录
tool=${main}/build
# 内核目录
ker=${main}/f460
# boot暂存目录
boot=${main}/boot
# zip输出目录
out=${main}/zipout
# zip打包的文件目录
kw=${main}/kernel-working
# ramdisk目录
rd=${main}/f460r
# ramdisk临时目录
rdt=${boot}/temp/rd-temp
# 临时目录
tmp=${boot}/temp
da=`date +%y_%m_%d`
thr=`grep processor /proc/cpuinfo -c`
# 设置交叉编译工具目录变量
export CROSS_COMPILE=android-toolchain/bin/arm-eabi-
# 设置变量arm构架
export ARCH=arm
#############################设置内核打包参数################################
base=0x00000000
ka=0x00008000
offset=0x02000000
ta=0x00000100
pg=4096
cmdline="console=ttyHSL0,115200,n8 androidboot.console=ttyHSL0 user_debug=31 msm_rtb.filter=0x3b7 dwc3_msm.cpu_to_affin=1 androidboot.hardware=tiger6 androidboot.selinux=permissive"
#############################################################################

# 打包ramdisk函数
pack_ramdisk()
{
	if [ ${faile} = "1" ];then
		echo "pack ramdisk:内核编译失败"
	else
			if  [ -e ${ker}/arch/arm/boot/zImage ] && [ -e ${boot}/img/dt.img ] ;then
				echo "pack ramdisk:内核已经准备好，准备打包ramdisk。"
				# 自动设置文件名
				#if [ -e ./version ];then
					#echo "pack ramdisk:找到‘version‘"
				#else
					#echo "pack ramdisk:找不到’version‘"
					#touch version
				#fi
				#sub=$(grep 'SUBLEVEL =.*' ${ker}/Makefile| sed '1,4s/ //g'| sed '1,4s/SUBLEVEL=//g');
				#rdsub=$(grep 'ver-.*LINUX' ${rd}/ROOT-RAMDISK/res/customconfig/customconfig.xml | sed '1,11s/ //g'| sed '1,11s/.*3.4.//g' |sed '1,11s/"name=.*//g');
				#if [  $sub != $rdsub ];then
				#echo "pack ramdisk:升级app linux版本"
				#sed -i -e "1,11s/$rdsub/$sub/" ${rd}/ROOT-RAMDISK/res/customconfig/customconfig.xml;
				#fi
				#ver1=$(grep 'ver-.*LINUX' ${rd}/ROOT-RAMDISK/res/customconfig/customconfig.xml | sed 's/ //g'| sed 's/.*ver-//g' |sed 's/\..*//g');
				#ver2=$(grep 'ver-.*LINUX' ${rd}/ROOT-RAMDISK/res/customconfig/customconfig.xml | sed -e '1,11s/ //g'| sed  -e '1,11s/LIN.*//g'| sed -e '1,11s/.*ve.*\.//g' ) ;
				#ver3=$(grep 'ver-.*LINUX' ${rd}/ROOT-RAMDISK/res/customconfig/customconfig.xml | sed 's/ //g'| sed 's/.*ver-//g' |sed 's/LIN.*//g');
				ver1=1
				ver2=0
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
				#sed -i -e "1,11s/$ver3/$code/" ${rd}/ROOT-RAMDISK/res/customconfig/customconfig.xml;
				#cd ${rd}
				#if [ -e /usr/bin/git ];then
						#git commit -am "自动提交GIT:升级ramdisk版本。";
						#else
						#echo "pack ramdisk:请安装GIT。"
				#fi
				#cd ${main}
				fm=LG-${cfg}-kernel-ver-${code}-$da-${relase}.zip
				cp -a ${rd}/* ${rdt}
				#cp -a ${rd}/${cfg}-RAMDISK/* ${rdt}
				if [ -e  ${boot}/img/ramdisk.gz ];then
					rm ${boot}/img/ramdisk.gz
				fi
				chmod  +x ${boot}/tool/mkbootfs
				${boot}/tool/mkbootfs ${rdt} | gzip > ramdisk.gz 2>/dev/null
				mv ramdisk.gz $boot/img
				if [ "$(ls ${rdt} | wc -l )"  != "0" ] ;then
					rm -r ${rdt}/*
					echo "pack ramdisk:清空临时ramdisk目录。"
				fi
				cp ${ker}/arch/arm/boot/zImage $boot/img/zImage
				chmod +x ${boot}/tool/mkbootimg
				${boot}/tool/mkbootimg --kernel $boot/img/zImage --ramdisk $boot/img/ramdisk.gz --cmdline "${cmdline}"  --base ${base} --kernel_offset ${ka} --ramdisk_offset ${offset} --tags_offset ${ta} --pagesize ${pg} --dt ${boot}/img/dt.img -o ${boot}/boot.img
				echo "pack ramdisk:list dt.img & boot.img"
				ls $boot/img/dt.img
				ls $boot/boot.img
				mv $boot/boot.img $kw/boot.img
				echo "pack ramdisk:BUMP内核！"
				kernel_bump
				r2=`ls ${kw}/system/lib/modules/ | wc -l`
				if [ "${r2}"  != "0" ] ;then
					echo "pack ramdisk:清空内核模块目录。"
					rm $kw/system/lib/modules/*
				fi
				echo "pack ramdisk:拷贝模块。"
				find ${ker} -name \*.ko -exec cp -f {} $kw/system/lib/modules/ \;
				countfo=`ls ${kw}/system/lib/modules/ | wc -l`
				# cp -a ${main}/mhi.ko ${kw}/system/lib/modules/;
				# I build it form LG,so we dont need fs/exfat
				cp -a ${main}/texfat.ko ${kw}/system/lib/modules/;
				# strip not needed debugs from modules.
				android-toolchain/bin/arm-LG-linux-gnueabi-strip --strip-unneeded ${kw}/system/lib/modules/* 2>/dev/null
				android-toolchain/bin/arm-LG-linux-gnueabi-strip --strip-debug ${kw}/system/lib/modules/* 2>/dev/null
				cd $kw
				zip -r temp.zip *
				cd ..
				mv $kw/temp.zip ${out}/${fm}
				lsfm=`ls ${out}/${fm}`
				countf=`ls ${kw}/system/lib/modules/ | wc -l`
				echo "================================================"
				echo "================================================"
				echo "共打包${countf}个模块,内核共${countfo}个模块。"
				echo "编译内核 ->${cfg} 打包成功"
				echo "生成文件:${fm}"
				echo "文件路径:${out}"
				echo "================================================"
				echo "================================================"
				else
				echo "pack ramdisk:打包失败，请查看dt.img zimage是否生成。"
			fi
		fi
}

# function make kernel
make_kernel()
{
			# 我这里使用型号识别defconfig，如果编译其他内核，还需要把整个cfg变量都设置为config文件名。
			config=${ker}/arch/arm/configs/JZ_${cfg}_defconfig
				if [ -e ${ker}/arch/arm/boot/zImage  ]  &&  [ -e ${boot}/img/dt.img ]  &&  [ -e ${boot}/img/zImage ]  &&  [ -e ${boot}/img/zImage ];then

					if [ -e ${boot}/img/dt.img ];then
						echo "make kernel:清除DT.img。"
						rm $boot/img/dt.img
					fi

					if [ -e ${boot}/img/zImage ];then
					echo "make kernel:删除 zImage。"
					rm ${boot}/img/zImage
					fi

					if [ -e ${kw}/boot.img ];then
						echo "make kernel:清空 boot.img。"
						rm ${kw}/boot.img
					fi

					echo "make kernel:清除完毕。"
					else
					echo "make kernel:编译目录是干净的。"
				fi
				echo "make kernel:准备编译内核。"
				cd ${ker}
				echo "make kernel:执行make  clean？"
				read cl
				if [ "${cl}" = "Y " ] || [ "${cl}" = "y" ];then
						ccache -c
						make clean && make mrproper
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
						cp ${config} .config;
						make -j${thr} JZ_${cfg}_defconfig
				fi
				echo "$config"

				time make -j${thr}
				cd ..
				chmod +x ${ker}/scripts/dtbTool
				if [ -e ${ker}/arch/arm/boot/zImage ];then
				${ker}/scripts/dtbTool -s 2048 -o $boot/img/dt.img $ker/arch/arm/boot/dts/
				echo "make kernel:编译完毕。"
				else
				faile=1
				echo "make kernel:编译没有完成"
				fi
}
# function kernel_bump
kernel_bump()
{
	PYTHON_CHECK=$(ls -la /usr/bin/python2 | wc -l);
	BOOT_IMAGE_LOCATION=${kw}/boot.img;
	if [ "$PYTHON_CHECK" -eq "1" ]; then
		/usr/bin/python2 ${tool}/open_bump.py ${BOOT_IMAGE_LOCATION} ;
		rm ${kw}/boot.img
		mv ${kw}/boot_bumped.img ${kw}/boot.img
	else
		echo "you dont have PYTHON2.x script will not work!!!";
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
# clear zimage to avoid pack issues
if [ -e ${ker}/arch/arm/boot/zImage ];then
	rm ${ker}/arch/arm/boot/zImage;
fi
printf "\ec"
echo "Maintask:输入defconfig信息。"
num=f460
echo "Maintask:输入'Y'仅重新打包ramdisk，任意键重新编译内核。"
read ju
if [ "${ju}" = "y" ] || [ "${ju}" = "Y" ];then
		echo "Maintask:仅重新打包ramdisk并且制zip卡刷包。"
		relase=rrd
		mk_flag
		for cfg in ${num} ; do
			echo ${cfg}
			pack_ramdisk
		done
		else
		echo "Maintask:编译内核并且打包ramdisk制作成zip卡刷包。"
		relase=mkpr
		mk_flag
		for cfg in ${num} ; do
			echo ${cfg}
			make_kernel
			pack_ramdisk
		done
fi
