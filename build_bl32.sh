#!/bin/bash

function build_bl32() {
	echo -n "Build bl32...Please wait... "
	local target="$1/bl32.img"
	local target2="$1/bl32.bin"
	# $1: src_folder, $2: bin_folder, $3: soc
	cd $1
	/bin/bash build.sh $3 ${CONFIG_CAS}
	if [ $? != 0 ]; then
		cd ${MAIN_FOLDER}
		echo "Error: Build bl32 failed... abort"
		exit -1
	fi
	cd ${MAIN_FOLDER}
	cp ${target} $2 -f
	if [ "$3" == "sc2" ]; then
		$1/tools/scripts/pack_dtb.py \
			--rsk fip/sc2/keys/dev-keys/$3/chipset/bl32/rsa/s905x4/bl32-rsk-rsa-priv.pem \
			--in ${target2}

		cp ${target2} $2 -f
	fi
	echo "done"
	return
}
