export CV_SW_TOOLCHAIN	:= /opt/corev
export CV_SW_PREFIX		:= riscv32-corev-elf-

CORE_X_REPO := $(shell pwd)/cores/cv32e40x
CORE_S_REPO := $(shell pwd)/cores/cv32e40s
VERIF_X_DIR := core-v-verif/cv32e40x/sim/uvmt
VERIF_S_DIR := core-v-verif/cv32e40s/sim/uvmt

.PHONY: test-x test-s

test-x:
	$(MAKE) -C ${VERIF_X_DIR} \
		SIMULATOR=verilator $(TEST)\
		CV_CORE=cv32e40x \
		CV_CORE_REPO=$(CORE_X_REPO)

test-s:
	$(MAKE) -C ${VERIF_S_DIR} \
		SIMULATOR=verilator $(TEST)\
		CV_CORE=cv32e40s \
		CV_CORE_REPO=$(CORE_S_REPO)
