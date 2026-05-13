export CV_SW_TOOLCHAIN	:= /opt/corev
export CV_SW_PREFIX	:= riscv32-corev-elf-
export DESIGN_RTL_DIR   := $(CORE_X_PATH)/rtl
export CV_SW_MARCH	:= rv32imc_zicsr

CORE_X_PATH := $(shell pwd)/cores/cv32e40x
CORE_S_PATH := $(shell pwd)/cores/cv32e40s
VERIF_X_DIR := core-v-verif/cv32e40x/sim/core
VERIF_S_DIR := core-v-verif/cv32e40s/sim/core
VERIF_DUAL_DIR := sim

.PHONY: test-x test-s test-reset clean-reset-test test-dual

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

test-dual:
	rm -rf core-v-verif/core-v-cores/cv32e40s
	$(MAKE) -C ${VERIF_DUAL_DIR} \
		SIMULATOR=verilator \
		TEST=$(TEST) \
		CV_CORE=cv32e40s \
		CV_CORE_PATH=$(CORE_S_PATH) \
		DESIGN_RTL_DIR=$(CORE_S_PATH)/rtl \
		CV_SW_MARCH=$(CV_SW_MARCH) \
		CORE_V_VERIF=$(shell pwd)/core-v-verif \
		VERI_COMPILE_FLAGS="-Wno-BLKANDNBLK -Wno-COMBDLY -Wno-DECLFILENAME -Wno-SYNCASYNCNET -Wno-UNOPTFLAT +define+COREV_ASSERT_OFF -I../cores/cv32e40x/rtl/include -y ../cores/cv32e40x/rtl -y ../cores/cv32e40x/bhv -y ../rtl" \
		veri-test

test-ip-functional:
	$(MAKE) -C sim/functional/ \
	CV32E40X_HOME=$(CORE_X_PATH) \
	CV32E40S_HOME=$(CORE_S_PATH)

clean-functional-test:
	$(MAKE) -C sim/functional/ clean

test-ip-security:
	$(MAKE) -C sim/security/ \
	CV32E40X_HOME=$(CORE_X_PATH) \
	CV32E40S_HOME=$(CORE_S_PATH)

clean-security-test:
	$(MAKE) -C sim/security/ clean

# Maybe not needed anymore?? It seems the new x I pulled has the diffs I
# need...
apply-patches:
	cd core-v-verif && git am ../patches/core-v-verif_new.patch

remove-patches:
	git checkout -- core-v-verif

change-core-ver:
	cd cores/cv32e40x && git checkout 0.9.0
	cd cores/cv32e40s && git checkout 0.9.0

RTL_FILES = rtl/
