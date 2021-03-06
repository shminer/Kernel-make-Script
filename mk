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
kernel_folder=${main}/f460
# boot暂存目录
boot=${main}/boot
# zip输出目录
out=${main}/zipout
# zip打包的文件目录
kernel_working=${main}/kernel-working
# ramdisk目录
ramdisk_folder=${main}/f460r
# ramdisk临时目录
ramdisk_temp=${boot}/temp/rd-temp
# 临时目录
tmp=${boot}/temp
date_today=`date +%y_%m_%d`
cpu_thread=`grep processor /proc/cpuinfo -c`
# 设置交叉编译工具目录变量
export CROSS_COMPILE=${main}/android-toolchain/bin/arm-eabi-
# 设置变量arm构架
export ARCH=arm
#############################设置内核打包参数################################
base=0x00000000
kernel_addr=0x00008000
ramdisk_addr=0x02000000
target_addr=0x00000100
page_size=4096
cmdline="console=ttyHSL0,115200,n8 androidboot.console=ttyHSL0 user_debug=31 dwc3_msm.cpu_to_affin=1 androidboot.hardware=tiger6 androidboot.selinux=permissive lpm_levels.sleep_disabled=1"
#############################################################################

# 打包ramdisk函数
pack_ramdisk()
{
	if  [ ${faile} = 1 ]; then
		echo "pack ramdisk:内核编译失败"
	else
			if  [ -e ${kernel_folder}/arch/arm/boot/zImage ] && [ -e ${kernel_working}/image/dt.img ] ;then
				cp ${kernel_folder}/arch/arm/boot/zImage ${kernel_working}/image/zImage
				cd ${kernel_working}/image;
				md5sum zImage > ${kernel_working}/image/zImage.md5;
				md5sum dt.img > ${kernel_working}/image/dt.img.md5;
				cd ${main};
				echo "pack ramdisk:内核已经准备好，准备打包ramdisk。"
				# 自动设置文件名
				ver1=$(expr substr $(cat ${ramdisk_folder}/cur_ver) 1 1);
				ver2=$(expr substr $(cat ${ramdisk_folder}/cur_ver) 2 1);
				if [ -e  ${tmp}/upflag ];then
					echo "pack ramdisk:不升级内核编译版本。"
					else
					let "ver2=${ver2}+1";
					if [ $ver2 -ge "10" ] || [ $ver1 -le "0" ];then
						ver2=0
						let "ver1=${ver1}+1";
					fi
				fi
				code=${ver1}"."${ver2}
				if [ ! -e ${ramdisk_folder}/cur_ver ];then
					touch ${ramdisk_folder}/cur_ver;
				fi
				echo "${ver1}${ver2}`date +%Y%m%d`" > ${ramdisk_folder}/cur_ver;
				cd ${ramdisk_folder}
				if [ ! -e  ${tmp}/upflag ];then
					if [ -e /usr/bin/git ];then
							git commit -am "auto commit :update kernel version ${code}";
							else
							echo "pack ramdisk:please install GIT。"
					fi
				fi
				cd ${ramdisk_folder}
				package_version=`git branch --list | grep "* " | sed 's/* //'`
				cd ${main}
				fm=LG-${cfg}-${package_version}-JZ-kernel-ver-${code}-${date_today}-${relase}.zip;
				cp -a ${ramdisk_folder}/* ${ramdisk_temp};
				#cp -a ${ramdisk_folder}/${cfg}-RAMDISK/* ${ramdisk_temp}
				if [ -d ${ramdisk_temp}/.git ]; then
					rm -rf ${ramdisk_temp}/.git;
				fi
				cd ${ramdisk_temp}
				tar -zcvpf ${kernel_working}/rd/ramdisk.gz ./;
				if [ "$(ls ${ramdisk_temp} | wc -l )"  != "0" ] ;then
					rm -r ${ramdisk_temp}/*
					echo "pack ramdisk:清空临时ramdisk目录。"
				fi
				cd ${ramdisk_folder}
				r2=`ls ${kernel_working}/system/lib/modules/ | wc -l`
				if [ "${r2}"  != "0" ] ;then
					echo "pack ramdisk:清空内核模块目录。"
					rm $kernel_working/system/lib/modules/*
				fi
				echo "pack ramdisk:拷贝模块。"
				find ${kernel_folder} -name \*.ko -exec cp -f {} $kernel_working/system/lib/modules/ \;
				countfo=`ls ${kernel_working}/system/lib/modules/ | wc -l`
				android-toolchain/bin/arm-LG-linux-gnueabi-strip --strip-unneeded ${kernel_working}/system/lib/modules/* 2>/dev/null
				android-toolchain/bin/arm-LG-linux-gnueabi-strip --strip-debug ${kernel_working}/system/lib/modules/* 2>/dev/null
				cd $kernel_working
				zip -r temp.zip *
				cd ..
				mv $kernel_working/temp.zip ${out}/${fm}
				if [ ${relase} == "rrd" ];then
					Cmode="only repack ramdisk and zip pack"
				else
					Cmode="make kernel and zip pack"
				fi
				countf=`ls ${kernel_working}/system/lib/modules/ | wc -l`
				echo "================================================"
				echo "================================================"
				echo "编译模式:${Cmode}"
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
			config=${kernel_folder}/arch/arm/configs/JZ_${cfg}_defconfig
				echo "make kernel:准备编译内核。"
				cd ${kernel_folder}
				echo "make kernel:执行make  clean？"
				read cl
				if [ "${cl}" = "Y " ] || [ "${cl}" = "y" ];then
						# ccache -c
						if [ -e ${kernel_working}/image/dt.img ];then
							echo "make kernel:删除DT.img。"
							rm $boot/img/dt.img
						fi
						if [ -e ${boot}/img/zImage ];then
							echo "make kernel:删除zImage。"
							rm ${boot}/img/zImage
						fi
						if [ -e ${kernel_working}/boot.img ];then
							echo "make kernel:删除boot.img。"
							rm ${kernel_working}/boot.img
						fi
						if [ -e ${kernel_folder}/arch/arm/boot/zImage ];then
							echo "make kernel:删除编译文件。"
							rm ${kernel_folder}/arch/arm/boot/zImage
						fi
						echo "make kernel:清除完毕。"
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
						# cp ${config} .config;
						make -j${cpu_thread} JZ_${cfg}_defconfig
				fi
				echo "$config"

				time make -j${cpu_thread}
				cd ..
				chmod +x ${kernel_folder}/scripts/dtbTool
				if [ -e ${kernel_folder}/arch/arm/boot/zImage ];then
				${kernel_folder}/scripts/dtbTool -s 2048 -o ${kernel_working}/image/dt.img ${kernel_folder}/arch/arm/boot/dts/
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
	BOOT_IMAGE_LOCATION=${kernel_working}/boot.img;
	if [ "$PYTHON_CHECK" -eq "1" ]; then
		/usr/bin/python2 ${tool}/open_bump.py ${BOOT_IMAGE_LOCATION} ;
		rm ${kernel_working}/boot.img
		mv ${kernel_working}/boot_bumped.img ${kernel_working}/boot.img
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
		if [ -e ${tmp}/upflag ];then
			 rm ${tmp}/upflag;
		fi
		else
		touch ${tmp}/upflag;
	fi
}
# now let`s start
faile=0
cl
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
