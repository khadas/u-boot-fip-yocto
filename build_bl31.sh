#!/bin/bash


# these soc use old bl31 code, others use new one
declare -a BL31_OLD_VER_SOC_LIST=("gxb" "gxtvbb" "gxl" "txl")
declare -a BL31_VER2_7_SOC_LIST=("t3x" "a4" "s1a" "s7" "s7d")
declare BL31_V2_7_SRC_FOLDER="bl31/bl31_2.7/src"
declare BL31_V1_3_SRC_FOLDER="bl31/bl31_1.3/src"
declare BL31_V1_0_SRC_FOLDER="bl31/bl31_1.0/src"
declare BL31_V2_7_BIN_FOLDER="bl31/bl31_2.7/bin"
declare BL31_V1_3_BIN_FOLDER="bl31/bl31_1.3/bin"
declare BL31_V1_0_BIN_FOLDER="bl31/bl31_1.0/bin"

function build_bl31() {
	echo -n "Build bl31...Please wait... "
	# $1: src_folder, $2: bin_folder, $3: soc
	local target="$1/bl31.bin"
	local target2="$1/bl31.img"
	cd $1
	export CROSS_COMPILE=${AARCH64_TOOL_CHAIN}
	CONFIG_SPD="opteed"
	#CONFIG_SPD="none"
	local soc=$3
	local bl2z_plat
	if [ "$soc" == "gxtvbb" ] || [ "$soc" == "gxb" ]; then
		soc="gxbb"
		bl2z_plat="txl"
	elif [ "$soc" == "txl" ]; then
		soc="gxl"
		bl2z_plat="txl"
	elif [ "$soc" == "gxl" ]; then
		soc="gxl"
		bl2z_plat="gxl"
	fi
	#make PLAT=${soc} SPD=${CONFIG_SPD} realclean &> /dev/null
	#make PLAT=${soc} SPD=${CONFIG_SPD} V=1 all &> /dev/null
	/bin/bash mk $soc $bl2z_plat
	if [ $? != 0 ]; then
		cd ${MAIN_FOLDER}
		echo "Error: Build bl31 failed... abort"
		exit -1
	fi
	cd ${MAIN_FOLDER}
	cp ${target} $2 -f
	cp ${target2} $2 -f
	echo "done"
	return
}

function build_bl31_v1_3() {
	echo -n "Build bl31 v1.3...Please wait... "
	# $1: src_folder, $2: bin_folder, $3: soc
	local target="$1/bl31.bin"
	local target2="$1/bl31.img"
	cd $1
	export CROSS_COMPILE=${AARCH64_TOOL_CHAIN}
	#sh mk $3 &> /dev/null
	local soc=$3
	if [ "$soc" == "txhd" ]; then
		soc="axg"
	fi
	if [ "$soc" == "t5d" ]; then
		soc="t5"
	fi
	/bin/bash mk $soc
	if [ $? != 0 ]; then
		cd ${MAIN_FOLDER}
		echo "Error: Build bl31 failed... abort"
		exit -1
	fi
	cd ${MAIN_FOLDER}
	cp ${target} $2 -f
	cp ${target2} $2 -f
	echo "done"
	return
}

function build_bl31_v2_7() {
	echo -n "Build bl31 v2.7...Please wait... "
	# $1: src_folder, $2: bin_folder, $3: soc
	local target="$1/bl31.bin"
	local target2="$1/bl31.img"
	cd $1
	export CROSS_COMPILE=${AARCH64_TOOL_CHAIN}
	#sh mk $3 &> /dev/null
	local soc=$3
	/bin/bash mk $soc
	if [ $? != 0 ]; then
		cd ${MAIN_FOLDER}
		echo "Error: Build bl31 failed... abort"
		exit -1
	fi
	cd ${MAIN_FOLDER}
	cp ${target} $2 -f
	cp ${target2} $2 -f
	echo "done"
	return
}

# check use which bl31 build script
function check_bl31_ver() {
	# $1: soc
	# return 1: use bl31 v1.3
	# return 0: use bl31 v1.0
	# return 2: use bl31 v2.7
	local -i ver=1
	for soc_list in ${!BL31_OLD_VER_SOC_LIST[@]}; do
	if [ "$1" == "${BL31_OLD_VER_SOC_LIST[${soc_list}]}" ]; then
		ver=0
	fi
	done
	for soc_list in ${!BL31_VER2_7_SOC_LIST[@]}; do
	if [ "$1" == "${BL31_VER2_7_SOC_LIST[${soc_list}]}" ]; then
		ver=2
	fi
	done
	echo "check_bl31_ver soc=$1"
	echo "check_bl31_ver ver=$ver"
	return ${ver}
}

# some soc need use bl31_v1.3
function switch_bl31() {
	# $1: soc
	local bl31_index=0;
	for loop in ${!BLX_NAME[@]}; do
		if [ ${BLX_NAME[$loop]} == ${BLX_NAME_GLB[2]} ]; then
			bl31_index=$loop
		fi
	done
	local version
	check_bl31_ver $1
	version=$?

	if [ ${version} == 2 ]; then
		echo "check bl31 ver: use v2.7"
		BLX_SRC_FOLDER[$bl31_index]=${BL31_V2_7_SRC_FOLDER}
		BLX_BIN_FOLDER[$bl31_index]=${BL31_V2_7_BIN_FOLDER}
	elif [ ${version} == 1 ]; then
		echo "check bl31 ver: use v1.3"
		BLX_SRC_FOLDER[$bl31_index]=${BL31_V1_3_SRC_FOLDER}
		BLX_BIN_FOLDER[$bl31_index]=${BL31_V1_3_BIN_FOLDER}
	else
		echo "check bl31 ver: use v1.0"
		BLX_SRC_FOLDER[$bl31_index]=${BL31_V1_0_SRC_FOLDER}
		BLX_BIN_FOLDER[$bl31_index]=${BL31_V1_0_BIN_FOLDER}
	fi
}
