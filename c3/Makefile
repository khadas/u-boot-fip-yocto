
#
# Rules
#

DEVICE_SCS_KEY_TOP ?= $(CURDIR)/keys/dev-keys/sc2/device/
DEVICE_ROOTRSA_INDEX ?= 0
PROJECT ?= c308l
SOC_DEVICE ?= c3
DEVICE_SCS_SEGID ?= 0x0
DEVICE_VENDOR_SEGID ?= 0x0
DEVICE_SCS_VERS ?= 0x0
DEVICE_TEE_VERS ?= 0x0
DEVICE_REE_VERS ?= 0x0

ARGS += "DEVICE_SCS_KEY_TOP=$(DEVICE_SCS_KEY_TOP)"
ARGS += "DEVICE_ROOTRSA_INDEX=$(DEVICE_ROOTRSA_INDEX)"
ARGS += "PROJECT=$(PROJECT)"
ARGS += "SOC_DEVICE=$(SOC_DEVICE)"
ARGS += "DEVICE_INPUT_PATH=${DEVICE_INPUT_PATH}"
ARGS += "DEVICE_OUTPUT_PATH=${DEVICE_OUTPUT_PATH}"
ARGS += "DEVICE_VARIANT_SUFFIX=${DEVICE_VARIANT_SUFFIX}"
ARGS += "DEVICE_STORAGE_SUFFIX=${DEVICE_STORAGE_SUFFIX}"
ARGS += "DEVICE_SCS_SEGID=${DEVICE_SCS_SEGID}"
ARGS += "DEVICE_VENDOR_SEGID=${DEVICE_VENDOR_SEGID}"
ARGS += "DEVICE_SCS_VERS=${DEVICE_SCS_VERS}"
ARGS += "DEVICE_TEE_VERS=${DEVICE_TEE_VERS}"
ARGS += "DEVICE_REE_VERS=${DEVICE_REE_VERS}"

all: build

dv-template:
	make -C create-template/run $(ARGS)

dv-sign:
	make -C generate-binaries/run $(ARGS)

dv-boot-blobs:
	make -C generate-binaries/run $(ARGS) build-boot-blobs

dv-device-fip:
	make -C generate-binaries/run $(ARGS) build-device-fip

build:
	make -C create-template/run $(ARGS)
	make -C generate-binaries/run $(ARGS)

clean:
	make clean -C create-template/run
	make clean -C generate-binaries/run
