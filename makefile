export CV_SW_TOOLCHAIN	:= /opt/corev
export CV_SW_PREFIX	:= riscv32-corev-elf-
export DESIGN_RTL_DIR   := $(CORE_X_PATH)/rtl
export CV_SW_MARCH	:= rv32imc_zicsr

CORE_X_PATH := $(shell pwd)/cores/cv32e40x
CORE_S_PATH := $(shell pwd)/cores/cv32e40s
VERIF_X_DIR := core-v-verif/cv32e40x/sim/core
VERIF_S_DIR := core-v-verif/cv32e40s/sim/core

.PHONY: test-x test-s

test-x:
	rm -rf core-v-verif/core-v-cores/cv32e40x
	$(MAKE) -C ${VERIF_X_DIR} \
		SIMULATOR=verilator \
		TEST=$(TEST) \
		CV_CORE=cv32e40x \
		CV_CORE_PATH=$(CORE_X_PATH) \
		DESIGN_RTL_DIR=$(CORE_X_PATH)/rtl \
		CV_SW_MARCH=$(CV_SW_MARCH) \
		VERI_COMPILE_FLAGS="-Wno-BLKANDNBLK -Wno-COMBDLY +define+COREV_ASSERT_OFF" \
		veri-test

test-s:
	rm -rf core-v-verif/core-v-cores/cv32e40s
	$(MAKE) -C ${VERIF_S_DIR} \
		SIMULATOR=verilator \
		TEST=$(TEST) \
		CV_CORE=cv32e40s \
		CV_CORE_PATH=$(CORE_S_PATH) \
		DESIGN_RTL_DIR=$(CORE_S_PATH)/rtl \
		CV_SW_MARCH=$(CV_SW_MARCH) \
		VERI_COMPILE_FLAGS="-Wno-BLKANDNBLK -Wno-COMBDLY +define+COREV_ASSERT_OFF" \
		veri-test

apply-patches:
	cd core-v-cores/cv32e40x && git apply ../../patches/cv32e40x_core.patch

remove-patches:
	cd core-v-cores/cv32e40x && git checkout -- rtl/cv32e40x_core.sv
