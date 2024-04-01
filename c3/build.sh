#!/bin/bash

# include uboot pre-build macros
#declare CONFIG_FILE=("${buildtree}/.config")
#declare AUTOCFG_FILE=("${buildtree}/include/autoconf.mk")

function init_vari() {
	#source ${CONFIG_FILE} &> /dev/null # ignore warning/error
	#source ${AUTOCFG_FILE} &> /dev/null # ignore warning/error

	AML_BL2_NAME="bl2.bin"
	AML_KEY_BLOB_NAME="aml-user-key.sig"

	if [ "y" == "${CONFIG_AML_SECURE_BOOT_V3}" ]; then
		V3_PROCESS_FLAG="--level v3"
	fi

	if [ "y" == "${CONFIG_AML_CRYPTO_AES}" ]; then
		BOOT_SIG_FLAG="--aeskey enable"
		EFUSE_GEN_FLAG="--aeskey enable"
	fi

	if [ "y" == "${CONFIG_AML_EFUSE_GEN_AES_ONLY}" ]; then
		EFUSE_GEN_FLAG="--aeskey only"
	fi

	if [ "y" == "${CONFIG_AML_BL33_COMPRESS_ENABLE}" ]; then
		BL33_COMPRESS_FLAG="--compress lz4"
	fi

	if [ "y" == "${CONFIG_FIP_IMG_SUPPORT}" ]; then
		BL3X_SUFFIX="img"
	fi

	if [ -n "${CONFIG_DDRFW_TYPE}" ]; then
		DDRFW_TYPE="${CONFIG_DDRFW_TYPE}"
	else
		DDRFW_TYPE="ddr4"
	fi

	if [ -n "${BLX_BIN_SUB_CHIP}" ]; then
		CHIPSET_NAME=`echo ${BLX_BIN_SUB_CHIP} | tr 'A-Z' 'a-z'`
	fi

	# script can use chipset varient to override config varient
	if [ -n "${SCRIPT_ARG_CHIPSET_VARIANT}" ]; then
		CHIPSET_VARIANT="${SCRIPT_ARG_CHIPSET_VARIANT}"
		CHIPSET_VARIANT_SUFFIX=".${CHIPSET_VARIANT}"
	elif [ -n "${CONFIG_CHIPSET_VARIANT}" ]; then
		if [ "${CONFIG_CHIPSET_VARIANT}" == "fastboot" ]; then
			CHIPSET_VARIANT="general"
			CHIPSET_VARIANT_SUFFIX=".fastboot"
		else
			CHIPSET_VARIANT="${CONFIG_CHIPSET_VARIANT}"
			CHIPSET_VARIANT_SUFFIX=".${CHIPSET_VARIANT}"
		fi
	else
		if [ -n "${CONFIG_FORMER_SIGN}" ]; then
			CHIPSET_VARIANT="no_variant"
		else
			CHIPSET_VARIANT="general"
		fi
		CHIPSET_VARIANT_SUFFIX=""
	fi

	if [ -n "${CONFIG_AMLOGIC_KEY_TYPE}" ]; then
		AMLOGIC_KEY_TYPE="${CONFIG_AMLOGIC_KEY_TYPE}"
	fi

	echo "------------------------------------------------------"
	echo "DDRFW_TYPE: ${DDRFW_TYPE} CHIPSET_NAME: ${CHIPSET_NAME} CHIPSET_VARIANT: ${CHIPSET_VARIANT} AMLOGIC_KEY_TYPE: ${AMLOGIC_KEY_TYPE}"
	echo "------------------------------------------------------"
}

function mk_bl2ex() {
	output=$1
	payload=$2
	ddr_type=$3

	if [ ! -f ${output}/bl2.bin.sto ]	|| \
	   [ ! -f ${output}/bl2.bin.usb ]	|| \
	   [ ! -f ${output}/bl2e.bin.sto ]	|| \
	   [ ! -f ${output}/bl2e.bin.usb ]	|| \
	   [ ! -f ${output}/bl2x.bin ]; then
		echo "Error: ${output}/bl2/e/x.bin does not all exist... abort"
		ls -la ${output}
		exit -1
	fi

	echo "================================================================="
	echo "image packing with acpu-imagetool for bl2 bl2e bl2x"

	dd if=/dev/zero of=${payload}/bl2.bin.sto bs=150432 count=1
	dd if=${output}/bl2.bin.sto of=${payload}/bl2.bin.sto conv=notrunc

	dd if=/dev/zero of=${payload}/bl2.bin.usb bs=150432 count=1
	dd if=${output}/bl2.bin.usb of=${payload}/bl2.bin.usb conv=notrunc

	dd if=/dev/zero of=${payload}/bl2e.bin.sto bs=65536 count=1
	dd if=${output}/bl2e.bin.sto of=${payload}/bl2e.bin.sto conv=notrunc

	dd if=/dev/zero of=${payload}/bl2e.bin.usb bs=65536 count=1
	dd if=${output}/bl2e.bin.usb of=${payload}/bl2e.bin.usb conv=notrunc

	dd if=/dev/zero of=${payload}/bl2x.bin bs=65536 count=1
	dd if=${output}/bl2x.bin of=${payload}/bl2x.bin conv=notrunc


	echo "===================================================="
	echo "------ process for Synopsys ddr fw ------"
	INPUT_DDRFW=./${FIP_FOLDER}${CUR_SOC}

	if [ "$ddr_type" == "ddr4" ]; then
		dd if=${INPUT_DDRFW}/ddr4_1d.fw of=${payload}/ddrfw_1d.bin skip=96 bs=1 count=36864
		dd if=${INPUT_DDRFW}/ddr4_2d.fw of=${payload}/ddrfw_2d.bin skip=96 bs=1 count=36864
	elif [ "$ddr_type" == "ddr3" ]; then
		dd if=${INPUT_DDRFW}/ddr3_1d.fw of=${payload}/ddrfw_1d.bin skip=96 bs=1 count=36864
		dd if=/dev/zero of=${payload}/ddrfw_2d.bin bs=36864 count=1
	elif [ "$ddr_type" == "lpddr4" ]; then
		dd if=${INPUT_DDRFW}/lpddr4_1d.fw of=${payload}/ddrfw_1d.bin skip=96 bs=1 count=36864
		dd if=${INPUT_DDRFW}/lpddr4_2d.fw of=${payload}/ddrfw_2d.bin skip=96 bs=1 count=36864
	elif [ "$ddr_type" == "lpddr3" ]; then
		dd if=${INPUT_DDRFW}/lpddr3_1d.fw of=${payload}/ddrfw_1d.bin skip=96 bs=1 count=36864
		dd if=/dev/zero of=${payload}/ddrfw_2d.bin bs=36864 count=1
	else
		echo "un-recognized ddr_type: ${ddr_type}"
		echo "---- use default ddr4 ----"
		dd if=${INPUT_DDRFW}/ddr4_1d.fw of=${payload}/ddrfw_1d.bin skip=96 bs=1 count=36864
		dd if=${INPUT_DDRFW}/ddr4_2d.fw of=${payload}/ddrfw_2d.bin skip=96 bs=1 count=36864
	fi

	piei_size=`stat -c %s ${INPUT_DDRFW}/piei.fw`
	if [ $piei_size -gt 12384 ]; then
		dd if=${INPUT_DDRFW}/piei.fw of=${payload}/ddrfw_piei.bin skip=96 bs=1 count=12288
	else
		dd if=/dev/zero of=${payload}/ddrfw_piei.bin bs=12288 count=1
		dd if=${INPUT_DDRFW}/piei.fw of=${payload}/ddrfw_piei.bin skip=96 bs=1 conv=notrunc
	fi

	cat ${payload}/ddrfw_1d.bin ${payload}/ddrfw_2d.bin \
		${payload}/ddrfw_piei.bin > ${payload}/ddrfw_data.bin

	if [ ! -f ${payload}/ddrfw_data.bin ]; then
		echo "ddrfw_data payload does not exist in ${payload} !"
		exit -1
	fi
	ddrfw_data_size=`stat -c %s ${payload}/ddrfw_data.bin`
	if [ $ddrfw_data_size -ne 86016 ]; then
		echo "ddr_fwdata size is not equal to 84K, $ddrfw_data_size"
		exit -1
	fi


	echo "===================================================="
	echo "------ process for device and chip params ------"
	INPUT_PARAMS=${output}

	if [ ! -f ${INPUT_PARAMS}/device_acs.bin ]; then
		echo "dev acs params not exist !"
		exit -1
	fi

	if [ ! -f ${INPUT_PARAMS}/chip_acs.bin ]; then
		echo "chip acs params not exist !"
		exit -1
	fi
	chip_acs_size=`stat -c %s ${INPUT_PARAMS}/chip_acs.bin`
	dev_acs_size=`stat -c %s ${INPUT_PARAMS}/device_acs.bin`

	if [ $chip_acs_size -gt 2048 ]; then
		echo "chip acs size exceed limit 2048, $chip_acs_size"
		exit -1
	else
		dd if=/dev/zero of=${payload}/chip_acs.bin bs=2048 count=1
		dd if=${INPUT_PARAMS}/chip_acs.bin of=${payload}/chip_acs.bin conv=notrunc
	fi

	if [ $dev_acs_size -gt 4096 ]; then
		echo "chip acs size exceed limit 4096, $dev_acs_size"
		exit -1
	else
		dd if=/dev/zero of=${payload}/device_acs.bin bs=4096 count=1
		dd if=${INPUT_PARAMS}/device_acs.bin of=${payload}/device_acs.bin conv=notrunc
	fi

	./${FIP_FOLDER}${CUR_SOC}/binary-tool/acpu-imagetool create-boot-blobs \
			--infile-bl2-payload=${payload}/bl2.bin.sto \
			--infile-bl2e-payload=${payload}/bl2e.bin.sto \
			--infile-bl2x-payload=${payload}/bl2x.bin \
			--infile-dvinit-params=${payload}/device_acs.bin \
			--infile-csinit-params=${payload}/chip_acs.bin \
			--scs-family=s4 \
			--outfile-bb1st=${output}/bb1st.sto.bin \
			--outfile-blob-bl2e=${output}/blob-bl2e.sto.bin \
			--outfile-blob-bl2x=${output}/blob-bl2x.bin

	./${FIP_FOLDER}${CUR_SOC}/binary-tool/acpu-imagetool create-boot-blobs \
			--infile-bl2-payload=${payload}/bl2.bin.usb \
			--infile-bl2e-payload=${payload}/bl2e.bin.usb \
			--infile-bl2x-payload=${payload}/bl2x.bin \
			--infile-dvinit-params=${payload}/device_acs.bin \
			--infile-csinit-params=${payload}/chip_acs.bin \
			--scs-family=s4 \
			--outfile-bb1st=${output}/bb1st.usb.bin \
			--outfile-blob-bl2e=${output}/blob-bl2e.usb.bin \
			--outfile-blob-bl2x=${output}/blob-bl2x.bin


	if [ ! -f ${output}/bb1st.sto.bin ] || \
	   [ ! -f ${output}/bb1st.usb.bin ] || \
	   [ ! -f ${output}/blob-bl2e.sto.bin ] || \
	   [ ! -f ${output}/blob-bl2e.usb.bin ] || \
	   [ ! -f ${output}/blob-bl2x.bin ]; then
		echo "Error: ${output}/ bootblobs do not all exist... abort"
		ls -la ${output}/
		exit -1
	fi
	echo "done to generate bb1st.bin folder"
}

function mk_devfip() {
	output=$1
	payload=$2

	# fix size for BL30 128KB --> 64KB
	if [ -f ${output}/bl30.bin ]; then
		blx_size=`stat -c %s ${output}/bl30.bin`
		if [ $blx_size -gt ${BL30_BIN_SIZE} ]; then
			echo "Error: bl30 size exceed limit ${BL30_BIN_SIZE}"
			exit -1
		fi
	else
		echo "Warning: null bl30"
		dd if=/dev/random of=${output}/bl30.bin bs=4096 count=1
		#dd if=bl30/bin/sc2/bl30.bin of=${output}/bl30.bin
	fi
	dd if=/dev/zero of=${payload}/bl30.bin bs=${BL30_BIN_SIZE} count=1
	dd if=${output}/bl30.bin of=${payload}/bl30.bin conv=notrunc

	# fix size for BL40 96KB
	if [ -f ${output}/bl40.bin ]; then
		blx_size=`stat -c %s ${output}/bl40.bin`
		if [ $blx_size -gt 98304 ]; then
			echo "Error: bl40 size exceed limit 98304"
			exit -1
		fi
	else
		echo "Warning: null bl40"
		#dd if=/dev/random of=${output}/bl40.bin bs=4096 count=1
		dd if=/dev/zero of=${output}/bl40.bin bs=4096 count=1
	fi
	dd if=/dev/zero of=${payload}/bl40.bin bs=98304 count=1
	dd if=${output}/bl40.bin of=${payload}/bl40.bin conv=notrunc


	# fix size for BL31 256KB
	if [ ! -f ${output}/bl31.bin ]; then
		echo "Error: ${output}/bl31.bin does not exist... abort"
		exit -1
	fi
	blx_size=`stat -c %s ${output}/bl31.bin`
	echo "BL31 size: ${blx_size}"
	if [ $blx_size -gt 262144 ]; then
		echo "Error: bl31 size exceed limit 262144"
		exit -1
	fi
	dd if=/dev/zero of=${payload}/bl31.bin bs=262144 count=1
	dd if=${output}/bl31.bin of=${payload}/bl31.bin conv=notrunc


	# fix size for BL32 512KB
	if [ -f ${output}/bl32.bin ]; then
		blx_size=`stat -c %s ${output}/bl32.bin`
		if [ $blx_size -gt 524288 ]; then
			echo "Error: bl32 size exceed limit 524288"
			exit -1
		fi
	else
		echo "Warning: null bl32"
		dd if=/dev/random of=${output}/bl32.bin bs=4096 count=1
		#dd if=bl32/bin/sc2/bl32.bin of=${output}/bl32.bin
	fi
	dd if=/dev/zero of=${payload}/bl32.bin bs=524288 count=1
	dd if=${output}/bl32.bin of=${payload}/bl32.bin conv=notrunc

	if [ "y" == "${CONFIG_AML_BL33_COMPRESS_ENABLE}" ]; then
		mv -f ${output}/bl33.bin  ${output}/bl33.bin.org
		encrypt_step --bl3sig  --input ${output}/bl33.bin.org --output ${output}/bl33.bin.org.lz4 --compress lz4 --level v3 --type bl33
		#get LZ4 format bl33 image from bl33.bin.enc with offset 0x720
		dd if=${output}/bl33.bin.org.lz4 of=${output}/bl33.bin bs=1 skip=1824 >& /dev/null
	fi
	# fix size for BL33 1024KB + 512 KB
	if [ ! -f ${output}/bl33.bin ]; then
		echo "Error: ${output}/bl33.bin does not exist... abort"
		exit -1
	fi
	blx_size=`stat -c %s ${output}/bl33.bin`
	if [ $blx_size -gt 1572864 ]; then
		echo "Error: bl33 size exceed limit 0x180000"
		exit -1
	fi
	dd if=/dev/zero of=${payload}/bl33.bin bs=1572864 count=1
	dd if=${output}/bl33.bin of=${payload}/bl33.bin conv=notrunc


	./${FIP_FOLDER}${CUR_SOC}/binary-tool/acpu-imagetool create-device-fip \
			--infile-bl30-payload=${payload}/bl30.bin \
			--infile-bl40-payload=${payload}/bl40.bin \
			--infile-bl31-payload=${payload}/bl31.bin \
			--infile-bl32-payload=${payload}/bl32.bin \
			--infile-bl33-payload=${payload}/bl33.bin \
			--outfile-device-fip=${output}/device-fip.bin

	if [ ! -f ${output}/device-fip.bin ]; then
		echo "Error: ${output}/device-fip.bin does not exist... abort"
		exit -1
	fi
	echo "done to generate device-fip.bin"
}

function build_header()
{
	local bl2_2=$1
	local rtos_1=$2
	local rtos_2=$3

	local size=0
	# 4KB for header (reserve for sign)
	local offset=4096
	local rem=0

	# build head for bl2-2.bin
	size=`stat -c %s ${bl2_2}`
	# insert uuid
	echo -n -e "\x6b\xe6\x1e\x1f\xac\xc0\x45\x12\x97\x3b\x32\x5f\x2e\x17\xa7\x2d" > ${BUILD_PATH}/_tmp_hdr.bin
	# insert size
	printf "%02x%02x%02x%02x" $[(size) & 0xff] $[((size) >> 8) & 0xff] \
		$[((size) >> 16) & 0xff] $[((size) >> 24) & 0xff] | xxd -r -ps >> ${BUILD_PATH}/_tmp_hdr.bin
	# insert offset
	printf "%02x%02x%02x%02x" $[(offset) & 0xff] $[((offset) >> 8) & 0xff] \
	$[((offset) >> 16) & 0xff] $[((offset) >> 24) & 0xff] | xxd -r -ps >> ${BUILD_PATH}/_tmp_hdr.bin
	# insert 8 bytes padding
	printf "\0\0\0\0\0\0\0\0" >> ${BUILD_PATH}/_tmp_hdr.bin
	# insert sha256
	openssl dgst -sha256 -binary ${bl2_2} >> ${BUILD_PATH}/_tmp_hdr.bin

	# build header for RTOS_1
	offset=`expr ${offset} + ${size} + 4095`
	rem=`expr ${offset} % 4096`
	offset=`expr ${offset} - ${rem}`
	size=`stat -c %s ${rtos_1}`
	echo -n -e "\x31\x9f\xb3\x9e\x1f\x9f\x48\x98\x96\x38\xca\xfa\x7e\xa4\x2c\xe9" >> ${BUILD_PATH}/_tmp_hdr.bin
	printf "%02x%02x%02x%02x" $[(size) & 0xff] $[((size) >> 8) & 0xff] \
	$[((size) >> 16) & 0xff] $[((size) >> 24) & 0xff] | xxd -r -ps >> ${BUILD_PATH}/_tmp_hdr.bin
	printf "%02x%02x%02x%02x" $[(offset) & 0xff] $[((offset) >> 8) & 0xff] \
	$[((offset) >> 16) & 0xff] $[((offset) >> 24) & 0xff] | xxd -r -ps >> ${BUILD_PATH}/_tmp_hdr.bin
	printf "\0\0\0\0\0\0\0\0" >> ${BUILD_PATH}/_tmp_hdr.bin
	openssl dgst -sha256 -binary ${rtos_1} >> ${BUILD_PATH}/_tmp_hdr.bin

	# build header for RTOS_2
	offset=`expr ${offset} + ${size} + 4095`
	rem=`expr ${offset} % 4096`
	offset=`expr ${offset} - ${rem}`
	size=`stat -c %s ${rtos_2}`
	echo -n -e "\x33\x71\xb3\x2b\x17\xca\x43\xe2\xb4\xdb\x11\xe1\x3e\xc0\xa5\xf3" >> ${BUILD_PATH}/_tmp_hdr.bin
	printf "%02x%02x%02x%02x" $[(size) & 0xff] $[((size) >> 8) & 0xff] \
	$[((size) >> 16) & 0xff] $[((size) >> 24) & 0xff] | xxd -r -ps >> ${BUILD_PATH}/_tmp_hdr.bin
	printf "%02x%02x%02x%02x" $[(offset) & 0xff] $[((offset) >> 8) & 0xff] \
	$[((offset) >> 16) & 0xff] $[((offset) >> 24) & 0xff] | xxd -r -ps >> ${BUILD_PATH}/_tmp_hdr.bin
	printf "\0\0\0\0\0\0\0\0" >> ${BUILD_PATH}/_tmp_hdr.bin
	openssl dgst -sha256 -binary ${rtos_2} >> ${BUILD_PATH}/_tmp_hdr.bin
}

function package_binary()
{
	local fw_size=
	local rem_val=
	local bin1=$1
	local bin2=$2
	local out_bin=$3

	# align bin1 size up to 4KB and padding bin2 at the end of bin1
	fw_size=`stat -c %s ${bin1}`
	fw_size=`expr ${fw_size} + 4095`
	rem_val=`expr ${fw_size} % 4096`
	fw_size=`expr ${fw_size} - ${rem_val}`
	dd if=/dev/zero of=${BUILD_PATH}/_tmp.bin bs=1 count=${fw_size} &> /dev/null
	dd if=${bin1} of=${BUILD_PATH}/_tmp.bin bs=1 count=${fw_size} conv=notrunc &> /dev/null

	cat ${bin2} >> ${BUILD_PATH}/_tmp.bin
	mv ${BUILD_PATH}/_tmp.bin ${BUILD_PATH}/${out_bin}
	echo ==== package ${bin1} ${bin2} to ${out_bin} ====
	#cp ${BUILD_PATH}/${out_bin} ${BUILD_FOLDER}
}

function mk_ddr_fip()
{
	if [ "fastboot" == "${CONFIG_CHIPSET_VARIANT}" ] && [ "ipc" != "${CONFIG_CHIPSET_VARIANT_IPC}" ]; then
		FAST_BOOT_RESOURCE="fastboot"
		test -f ${FAST_BOOT_RESOURCE}/bl22.bin && cp ${FAST_BOOT_RESOURCE}/bl22.bin ${BUILD_PATH}/bl22.bin
		test -f ${FAST_BOOT_RESOURCE}/rtos_1.bin && cp ${FAST_BOOT_RESOURCE}/rtos_1.bin ${BUILD_PATH}/rtos_1.bin
		test -f ${FAST_BOOT_RESOURCE}/rtos_2.bin && cp ${FAST_BOOT_RESOURCE}/rtos_2.bin ${BUILD_PATH}/rtos_2.bin

		if [ ! -e ${BUILD_PATH}/rtos_1.bin ]; then
			echo ==== rtos_1.bin not exist, use a empty one ====
			dd if=/dev/zero of=${BUILD_PATH}/rtos_1.bin bs=1 count=8192
		fi

		if [ ! -e ${BUILD_PATH}/rtos_2.bin ]; then
			echo ==== rtos_2.bin not exist, use a empty one ====
			dd if=/dev/zero of=${BUILD_PATH}/rtos_2.bin bs=1 count=16384
		fi

		build_header ${BUILD_PATH}/bl22.bin ${BUILD_PATH}/rtos_1.bin ${BUILD_PATH}/rtos_2.bin
		package_binary ${BUILD_PATH}/_tmp_hdr.bin ${BUILD_PATH}/bl22.bin bl22.bin
		package_binary ${BUILD_PATH}/bl22.bin ${BUILD_PATH}/rtos_1.bin bl22.bin
		package_binary ${BUILD_PATH}/bl22.bin ${BUILD_PATH}/rtos_2.bin ddr-fip.bin

		if [ -n "${CONFIG_BUILD_UNSIGN}" ]; then
			echo "==== build unsigned ===="
			dd if=/dev/zero of=${BUILD_PATH}/_tmp.bin bs=1024 count=256 &> /dev/null
		else
			echo "==== build fastboot ===="
			dd if=/dev/zero of=${BUILD_PATH}/_tmp.bin bs=1024 count=1792 &> /dev/null
		fi
	else
		dd if=/dev/zero of=${BUILD_PATH}/_tmp.bin bs=1024 count=256 &> /dev/null
	fi
	dd if=${BUILD_PATH}/ddr-fip.bin of=${BUILD_PATH}/_tmp.bin conv=notrunc &> /dev/null
	mv ${BUILD_PATH}/_tmp.bin ${BUILD_PATH}/ddr-fip.bin
}


function mk_uboot() {
	output_images=$1
	input_payloads=$2
	postfix=$3
	storage_type_suffix=$4
	chipset_variant_suffix=$5

	device_fip="${input_payloads}/device-fip.bin${postfix}"
	bb1st="${input_payloads}/bb1st${storage_type_suffix}${chipset_variant_suffix}.bin${postfix}"
	bl2e="${input_payloads}/blob-bl2e${storage_type_suffix}${chipset_variant_suffix}.bin${postfix}"
	bl2x="${input_payloads}/blob-bl2x${chipset_variant_suffix}.bin${postfix}"

	if [ ! -f ${device_fip} ] || \
	   [ ! -f ${bb1st} ] || \
	   [ ! -f ${bl2e} ] || \
	   [ ! -f ${bl2x} ]; then
		echo fip:${device_fip}
		echo bb1st:${bb1st}
		echo bl2e:${bl2e}
		echo bl2x:${bl2x}
		echo "Error: ${input_payloads}/ bootblob does not all exist... abort"
		ls -la ${input_payloads}/
		exit -1
	fi

	file_info_cfg="${output_images}/aml-payload.cfg"
	file_info_cfg_temp=${temp_cfg}.temp

	bootloader="${output_images}/u-boot.bin${storage_type_suffix}${postfix}"
	sdcard_image="${output_images}/u-boot.bin.sd.bin${postfix}"

	#fake ddr fip 256KB
	ddr_fip="${input_payloads}/ddr-fip.bin"
	if [ ! -f ${ddr_fip} ]; then
		echo "==== use empty ddr-fip ===="
		dd if=/dev/zero of=${ddr_fip} bs=1024 count=256 status=none
	fi

	#cat those together with 4K upper aligned for sdcard
	align_base=4096
	total_size=0
	for file in ${bb1st} ${bl2e} ${bl2x} ${ddr_fip} ${device_fip}; do
		size=`stat -c "%s" ${file}`
		upper=$[(size+align_base-1)/align_base*align_base]
		total_size=$[total_size+upper]
		echo ${file} ${size} ${upper}
	done

	echo ${total_size}
	rm -f ${bootloader}
	dd if=/dev/zero of=${bootloader} bs=${total_size} count=1 status=none

	sector=512
	seek=0
	seek_sector=0
	dateStamp=SC2-`date +%Y%m%d%H%M%S`

	echo @AMLBOOT > ${file_info_cfg_temp}
	dd if=${file_info_cfg_temp} of=${file_info_cfg} bs=1 count=8 conv=notrunc &> /dev/null
	nItemNum=5
	nSizeHDR=$[64+nItemNum*16]
	printf "01 %02x %02x %02x 00 00 00 00" $[(nItemNum)&0xFF] $[(nSizeHDR)&0xFF] $[((nSizeHDR)>>8)&0xFF] \
		| xxd -r -ps > ${file_info_cfg_temp}
	cat ${file_info_cfg_temp} >> ${file_info_cfg}

	echo ${dateStamp} > ${file_info_cfg_temp}
	dd if=${file_info_cfg_temp} of=${file_info_cfg} bs=1 count=16 oflag=append conv=notrunc &> /dev/null

	index=0
	arrPayload=("BBST" "BL2E" "BL2X" "DDRF" "DEVF");
	nPayloadOffset=0
	nPayloadSize=0
	for file in ${bb1st} ${bl2e} ${bl2x} ${ddr_fip} ${device_fip}; do
		size=`stat -c "%s" ${file}`
		size_sector=$[(size+align_base-1)/align_base*align_base]
		nPayloadSize=$[size_sector]
		size_sector=$[size_sector/sector]
		seek_sector=$[seek/sector+seek_sector]
		#nPayloadOffset=$[sector*(seek_sector+1)]
		nPayloadOffset=$[sector*(seek_sector)]
		echo ${file} ${seek_sector} ${size_sector}
		dd if=${file} of=${bootloader} bs=${sector} seek=${seek_sector} conv=notrunc status=none

		echo ${arrPayload[$index]} > ${file_info_cfg_temp}.x
		index=$((index+1))
		dd if=${file_info_cfg_temp}.x of=${file_info_cfg_temp} bs=1 count=4 &> /dev/null
		rm -f ${file_info_cfg_temp}.x
		printf "%02x %02x %02x %02x %02x %02x %02x %02x 00 00 00 00" $[(nPayloadOffset)&0xFF] $[((nPayloadOffset)>>8)&0xFF] $[((nPayloadOffset)>>16)&0xFF] $[((nPayloadOffset)>>24)&0xFF] \
		$[(nPayloadSize)&0xFF] $[((nPayloadSize)>>8)&0xFF] $[((nPayloadSize)>>16)&0xFF] $[((nPayloadSize)>>24)&0xFF] | xxd -r -ps >> ${file_info_cfg_temp}
		dd if=${file_info_cfg_temp} of=${file_info_cfg} oflag=append conv=notrunc &> /dev/null
		rm -f ${file_info_cfg_temp}
		seek=$[(size+align_base-1)/align_base*align_base]
	done

	openssl dgst -sha256 -binary ${file_info_cfg} > ${file_info_cfg}.sha256
	cat ${file_info_cfg} >> ${file_info_cfg}.sha256
	#cat ${file_info_cfg}.sha256 >> ${file_info_cfg}
	rm -f ${file_info_cfg}
	mv -f ${file_info_cfg}.sha256 ${file_info_cfg}

	dd if=${file_info_cfg} of=${bootloader} bs=512 seek=332 conv=notrunc status=none

	if [ ${storage_type_suffix} == ".sto" ]; then
		echo "Image SDCARD"
		total_size=$[total_size+512]
		rm -f ${sdcard_image}
		dd if=/dev/zero of=${sdcard_image} bs=${total_size} count=1 status=none
		dd if=${file_info_cfg}   of=${sdcard_image} conv=notrunc status=none
		dd if=${bootloader} of=${sdcard_image} bs=512 seek=1 conv=notrunc status=none

		mv ${bootloader} ${output_images}/u-boot.bin${postfix}
	fi

	rm -f ${file_info_cfg}
}


function cleanup() {
	cp ${FIP_BUILD_FOLDER}u-boot.bin* ${BUILD_FOLDER}
	# cp bootblobs for PXP
	#cp ${FIP_BUILD_FOLDER}device-fip.bin ${BUILD_FOLDER} -f
	#cp ${FIP_BUILD_FOLDER}bb1st.bin ${BUILD_FOLDER} -f
	#cp ${FIP_BUILD_FOLDER}blob-bl* ${BUILD_FOLDER} -f
	echo "output file are generated in ${BUILD_FOLDER} folder"
	#rm -f ${BUILD_PATH}/test-*
	#rm -rf ${BUILD_PAYLOAD}
	rm -f ${BUILD_PATH}/bl*.enc ${BUILD_PATH}/bl2*.sig
}

function encrypt_step() {
	dbg "encrypt: $@"
	local ret=0
	./${FIP_FOLDER}${CUR_SOC}/aml_encrypt_${CUR_SOC} $@
	ret=$?
	if [ 0 != $ret ]; then
		echo "Err! aml_encrypt_${CUR_SOC} return $ret"
		exit $ret
	fi
}

function encrypt() {
	#u-boot.bin generate

	return
}

function build_fip() {

	# acs_tool process ddr timing and configurable parameters
	#python ${FIP_FOLDER}/acs_tool.pyc ${BUILD_PATH}/${AML_BL2_NAME} ${BUILD_PATH}/bl2_acs.bin ${BUILD_PATH}/acs.bin 0

	# fix bl2/bl2e/bl2x
	if [ -d ${BUILD_PAYLOAD} ]; then
		rm -rf ${BUILD_PAYLOAD}
	fi
	mkdir -p ${BUILD_PAYLOAD}/

	# make boot blobs
	mk_bl2ex ${BUILD_PATH} ${BUILD_PAYLOAD} ${DDRFW_TYPE}

	# make devicefip
	mk_devfip ${BUILD_PATH} ${BUILD_PAYLOAD}


	# build final bootloader
	#mk_uboot ${BUILD_PATH} ${BUILD_PATH}
	mk_uboot ${BUILD_PATH} ${BUILD_PATH} "" .sto ${CHIPSET_VARIANT_SUFFIX}
	mk_uboot ${BUILD_PATH} ${BUILD_PATH} "" .usb ${CHIPSET_VARIANT_SUFFIX}

	return
}

function process_blx() {

	# process loop
	for loop in ${!BLX_NAME[@]}; do
		if [ "${CONFIG_CHIPSET_VARIANT}" == "fastboot" ]; then
			extra_args="--extra_args  ${CONFIG_CHIPSET_VARIANT}"
			extraArgs="--extraArgs  ${CONFIG_CHIPSET_VARIANT}"
		fi
		if [ "NULL" != "${BLX_RAWBIN_NAME[$loop]}" ] && \
			[ -n "${BLX_RAWBIN_NAME[$loop]}" ] && \
			[ -f ${BUILD_PATH}/${BLX_RAWBIN_NAME[$loop]} ]; then
			if [ -n "${CONFIG_FORMER_SIGN}" ]; then
					./${FIP_FOLDER}${CUR_SOC}/bin/sign-blx.sh --blxname ${BLX_NAME[$loop]} --input ${BUILD_PATH}/${BLX_RAWBIN_NAME[$loop]} \
						--output ${BUILD_PATH}/${BLX_BIN_NAME[$loop]} --chipset_name ${CHIPSET_NAME} --chipset_variant ${CHIPSET_VARIANT} \
						--key_type ${AMLOGIC_KEY_TYPE} --soc ${CUR_SOC} --chip_acs ${BUILD_PATH}/chip_acs.bin --ddr_type ${DDRFW_TYPE} ${extra_args}
			else
					if [ -n "${CONFIG_JENKINS_SIGN}" ]; then
						/usr/bin/python3 ./sign.py --type ${BLX_NAME[$loop]} --in ${BUILD_PATH}/${BLX_RAWBIN_NAME[$loop]} \
							--out ${BUILD_PATH}/${BLX_BIN_NAME[$loop]} --chip ${CHIPSET_NAME}  --chipVariant ${CHIPSET_VARIANT} \
							--keyType ${AMLOGIC_KEY_TYPE}  --chipAcsFile ${BUILD_PATH}/chip_acs.bin --ddrType ${DDRFW_TYPE} ${extraArgs}
					else
						/usr/bin/python3 ./${FIP_FOLDER}/jenkins_sign.py --type ${BLX_NAME[$loop]} --in ${BUILD_PATH}/${BLX_RAWBIN_NAME[$loop]} \
							--out ${BUILD_PATH}/${BLX_BIN_NAME[$loop]} --chip ${CHIPSET_NAME} --chipVariant ${CHIPSET_VARIANT} --keyType ${AMLOGIC_KEY_TYPE} \
							--chipAcsFile ${BUILD_PATH}/chip_acs.bin --ddrType ${DDRFW_TYPE} ${extraArgs}
					fi
			fi
		fi
		if [ "NULL" != "${BLX_BIN_SIZE[$loop]}" ] && \
		    [ "NULL" != "${BLX_BIN_NAME[$loop]}" ] && \
			[ -n "${BLX_BIN_NAME[$loop]}" ] && \
			[ -f ${BUILD_PATH}/${BLX_BIN_NAME[$loop]} ]; then
			blx_size=`stat -c %s ${BUILD_PATH}/${BLX_BIN_NAME[$loop]}`
			if [ $blx_size -ne ${BLX_BIN_SIZE[$loop]} ]; then
				echo "Error: ${BUILD_PATH}/${BLX_BIN_NAME[$loop]} size not match"
				exit -1
			fi
		fi
	done

	if [ ! -f ${BUILD_PATH}/device_acs.bin ]; then
		echo "dev acs params not exist !"
		exit -1
	fi

	dev_acs_size=`stat -c %s ${BUILD_PATH}/device_acs.bin`

	if [ $dev_acs_size -gt ${DEV_ACS_BIN_SIZE} ]; then
		echo "chip acs size exceed limit ${DEV_ACS_BIN_SIZE}, $dev_acs_size"
		exit -1
	else
		dd if=/dev/zero of=${BUILD_PATH}/dvinit-params.bin bs=${DEV_ACS_BIN_SIZE} count=1 &> /dev/null
		dd if=${BUILD_PATH}/device_acs.bin of=${BUILD_PATH}/dvinit-params.bin conv=notrunc &> /dev/null
	fi

	./${FIP_FOLDER}${CUR_SOC}/bin/add-dvinit-params.sh ${BUILD_PATH}/bb1st.sto${CHIPSET_VARIANT_SUFFIX}.bin.signed ${BUILD_PATH}/dvinit-params.bin ${BUILD_PATH}/bb1st.sto${CHIPSET_VARIANT_SUFFIX}.bin.signed ${CUR_SOC}
	./${FIP_FOLDER}${CUR_SOC}/bin/add-dvinit-params.sh ${BUILD_PATH}/bb1st.usb${CHIPSET_VARIANT_SUFFIX}.bin.signed ${BUILD_PATH}/dvinit-params.bin ${BUILD_PATH}/bb1st.usb${CHIPSET_VARIANT_SUFFIX}.bin.signed ${CUR_SOC}

	# fix size for BL30 128KB
	if [ -f ${BUILD_PATH}/bl30.bin ]; then
		#blx_size=`du -b ${BUILD_PATH}/bl30.bin | awk '{print int(${BUILD_PATH}/bl30.bin)}'`
		blx_size=`stat -c %s ${BUILD_PATH}/bl30.bin`
		if [ $blx_size -gt ${BL30_BIN_SIZE} ]; then
			echo "Error: bl30 size exceed limit ${BL30_BIN_SIZE}"
			exit -1
		fi
	else
		echo "Warning: local bl30"
		#dd if=/dev/random of=${BUILD_PATH}/bl30.bin bs=4096 count=1
		#dd if=bl30/bin/sc2/bl30.bin of=${BUILD_PATH}/bl30.bin &> /dev/null
	fi
	dd if=/dev/zero of=${BUILD_PATH}/bl30-payload.bin bs=${BL30_BIN_SIZE} count=1 &> /dev/null
	dd if=${BUILD_PATH}/bl30.bin of=${BUILD_PATH}/bl30-payload.bin conv=notrunc &> /dev/null

	if [ "y" == "${CONFIG_AML_BL33_COMPRESS_ENABLE}" ]; then
		mv -f ${BUILD_PATH}/bl33.bin  ${BUILD_PATH}/bl33.bin.org
		encrypt_step --bl3sig  --input ${BUILD_PATH}/bl33.bin.org --output ${BUILD_PATH}/bl33.bin.org.lz4 --compress lz4 --level v3 --type bl33
		#get LZ4 format bl33 image from bl33.bin.enc with offset 0x720
		dd if=${BUILD_PATH}/bl33.bin.org.lz4 of=${BUILD_PATH}/bl33.bin bs=1 skip=1824 >& /dev/null
	fi

	# fix size for BL33 1024KB
	if [ ! -f ${BUILD_PATH}/bl33.bin ]; then
		echo "Error: ${BUILD_PATH}/bl33.bin does not exist... abort"
		exit -1
	fi
	#blx_size=`du -b ${BUILD_PATH}/bl33.bin | awk '{print int(${BUILD_PATH}/bl33.bin)}'`
	blx_size=`stat -c %s ${BUILD_PATH}/bl33.bin`
	if [ $blx_size -gt ${BL33_BIN_SIZE} ]; then
		echo "Error: bl33 size exceed limit ${BL33_BIN_SIZE}"
		exit -1
	fi
	dd if=/dev/zero of=${BUILD_PATH}/bl33-payload.bin bs=${BL33_BIN_SIZE} count=1 &> /dev/null
	dd if=${BUILD_PATH}/bl33.bin of=${BUILD_PATH}/bl33-payload.bin conv=notrunc &> /dev/null

	if [ ! -f ${BUILD_PATH}/blob-bl40.bin.signed ]; then
		echo "Warning: local bl40"
		cp bl40/bin/${CUR_SOC}/${BLX_BIN_SUB_CHIP}/blob-bl40${CHIPSET_VARIANT_SUFFIX}.bin.signed ${BUILD_PATH}
	fi
	if [ ! -f ${BUILD_PATH}/device-fip-header.bin ]; then
		echo "Warning: local device fip header templates"
		cp ${CHIPSET_TEMPLATES_PATH}/${CUR_SOC}/${BLX_BIN_SUB_CHIP}/device-fip-header.bin ${BUILD_PATH}
	fi

	#./${FIP_FOLDER}${CUR_SOC}/bin/gen-bl.sh ${BUILD_PATH} ${BUILD_PATH} ${BUILD_PATH}

	return
}

function build_signed() {

	process_blx $@

	if [ "fastboot" == "${CONFIG_CHIPSET_VARIANT}" ]; then
		# package ddr-fip.bin
		mk_ddr_fip ${BUILD_PATH}
	fi

	if [ "" != "${CHIPSET_VARIANT_MIN_SUFFIX}" ]; then
		./${FIP_FOLDER}${CUR_SOC}/bin/gen-bl.sh ${BUILD_PATH} ${BUILD_PATH} ${BUILD_PATH} ${BUILD_PATH} ${CHIPSET_VARIANT_SUFFIX} ${CHIPSET_VARIANT_MIN_SUFFIX}
	else
		./${FIP_FOLDER}${CUR_SOC}/bin/gen-bl.sh ${BUILD_PATH} ${BUILD_PATH} ${BUILD_PATH} ${BUILD_PATH} ${CHIPSET_VARIANT_SUFFIX}
	fi

	postfix=.signed
	mk_uboot ${BUILD_PATH} ${BUILD_PATH} ${postfix} .sto ${CHIPSET_VARIANT_SUFFIX}
	mk_uboot ${BUILD_PATH} ${BUILD_PATH} ${postfix} .usb ${CHIPSET_VARIANT_SUFFIX}

	# process loop
	list_pack=
	for loop in ${!BLX_NAME[@]}; do
		list_pack="$list_pack ${BUILD_PATH}/${BLX_BIN_NAME[$loop]}"
	done
	list_pack="$list_pack ${BUILD_PATH}/bl30-payload.bin ${BUILD_PATH}/bl33-payload.bin ${BUILD_PATH}/dvinit-params.bin"
	if [ -f ${BUILD_PATH}/ddr-fip.bin ]; then
		list_pack="$list_pack ${BUILD_PATH}/ddr-fip.bin"
	fi
	u_pack=${BUILD_FOLDER}/"$(basename ${BOARD_DIR})"-u-boot.aml.zip
	zip -j $u_pack ${list_pack} >& /dev/null

	if [ "y" == "${CONFIG_AML_SIGNED_UBOOT}" ]; then
		if [ ! -d "${UBOOT_SRC_FOLDER}/${BOARD_DIR}/device-keys" ]; then
			./${FIP_FOLDER}${CUR_SOC}/bin/download-keys.sh ${AMLOGIC_KEY_TYPE} ${CUR_SOC} device ${UBOOT_SRC_FOLDER}/${BOARD_DIR}/device-keys/
		fi

		fw_arb_cfg=${UBOOT_SRC_FOLDER}/${BOARD_DIR}/fw_arb.cfg
		if [ -s "${fw_arb_cfg}" ]; then
			source ${fw_arb_cfg}
			export DEVICE_SCS_SEGID=${DEVICE_SCS_SEGID}
			export DEVICE_VENDOR_SEGID=${DEVICE_VENDOR_SEGID}
			export DEVICE_SCS_VERS=${DEVICE_SCS_VERS}
			export DEVICE_TEE_VERS=${DEVICE_TEE_VERS}
			export DEVICE_REE_VERS=${DEVICE_REE_VERS}
		fi
		export DEVICE_SCS_KEY_TOP=$(pwd)/${UBOOT_SRC_FOLDER}/${BOARD_DIR}/device-keys
		export DEVICE_INPUT_PATH=$(pwd)/${BUILD_PATH}
		export DEVICE_OUTPUT_PATH=$(pwd)/${BUILD_PATH}
		export PROJECT=${CHIPSET_NAME}
		if [ "y" == "${CONFIG_DEVICE_ROOTRSA_INDEX}" ]; then
			export DEVICE_ROOTRSA_INDEX=1
		elif [ -n "${CONFIG_DEVICE_ROOTRSA_INDEX}" ]; then
			export DEVICE_ROOTRSA_INDEX=${CONFIG_DEVICE_ROOTRSA_INDEX}
		fi
		export DEVICE_VARIANT_SUFFIX=${CHIPSET_VARIANT_SUFFIX}
		export DEVICE_VARIANT_MIN_SUFFIX=${CHIPSET_VARIANT_MIN_SUFFIX}

		export DEVICE_STORAGE_SUFFIX=.sto
		make -C ./${FIP_FOLDER}${CUR_SOC} dv-boot-blobs
		export DEVICE_STORAGE_SUFFIX=.usb
		make -C ./${FIP_FOLDER}${CUR_SOC} dv-boot-blobs

		make -C ./${FIP_FOLDER}${CUR_SOC} dv-device-fip
		# build final bootloader
		postfix=.device.signed
		mk_uboot ${BUILD_PATH} ${BUILD_PATH} ${postfix} .sto ${CHIPSET_VARIANT_SUFFIX}
		mk_uboot ${BUILD_PATH} ${BUILD_PATH} ${postfix} .usb ${CHIPSET_VARIANT_SUFFIX}
	fi

	return
}

function copy_other_soc() {
	cp ${BL33_BUILD_FOLDER}${BOARD_DIR}/firmware/acs.bin ${BUILD_PATH}/device_acs.bin -f

	if [ ! -f ${BUILD_PATH}/chip_acs.bin ]; then
		cp ./${FIP_FOLDER}${CUR_SOC}/chip_acs.bin ${BUILD_PATH}/chip_acs.bin -f
	fi

	# device acs params parse for ddr timing
	#./${FIP_FOLDER}parse ${BUILD_PATH}/device_acs.bin
}

function package() {
	# BUILD_PATH without "/"
	x=$((${#BUILD_PATH}-1))

	if [ "\\" == "${BUILD_PATH:$x:1}" ] || [ "/" == "${BUILD_PATH:$x:1}" ]; then
		BUILD_PATH=${BUILD_PATH:0:$x}
	fi

	init_vari $@
	# Enable Clear Image Packing for PXP
	if [ -n "${CONFIG_BUILD_UNSIGN}" ]; then
		build_fip $@
	else
	# Bypass Sign Process for PXP
	build_signed $@
	fi
	#copy_file
	cleanup

	echo "Bootloader build done!"
}
