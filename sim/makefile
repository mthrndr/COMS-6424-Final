CV32E40X_HOME ?= ../cores/cv32e40x
CV32E40S_HOME ?= ../cores/cv32e40s
RTL_DIR       ?= ../rtl

VERILATOR ?= verilator
TOP        = reset_buffer_tb

LOCAL_SRCS = \
    $(RTL_DIR)/reset_buffer.sv \
    reset_buffer_tb.sv

OBJ_DIR = obj_dir
BIN     = $(OBJ_DIR)/V$(TOP)

GEN_X_MANIFEST = $(OBJ_DIR)/cv32e40x_manifest.flist
GEN_S_MANIFEST = $(OBJ_DIR)/cv32e40s_manifest.flist

PATCHED_S_DIR = $(OBJ_DIR)/cv32e40s_patched

VERILATOR_FLAGS = \
    --binary \
    --trace \
    --timing \
    --top $(TOP) \
    +define+COREV_ASSERT_OFF \
    -Wno-BLKANDNBLK \
    -Wno-COMBDLY \
    -Wno-REDEFMACRO \
    -Wno-MODDUP \
    -Wno-TIMESCALEMOD \
    -Wno-fatal \
    -Wno-WIDTH \
    -Wno-UNUSED \
    -Wno-PINMISSING \
    -Wno-CASEINCOMPLETE \
    -Wno-LATCH \
    -Wno-UNOPTFLAT \
    -Wno-DECLFILENAME \
    -Wno-MULTIDRIVEN \
    -Wno-IMPLICIT \
    -Wno-ASCRANGE

CORE_MANIFESTS = -f $(GEN_X_MANIFEST) -f $(GEN_S_MANIFEST)

.PHONY: all build run clean check-paths

all: run

check-paths:
	@if [ ! -f $(RTL_DIR)/reset_buffer.sv ]; then \
	    echo "ERROR: cannot find $(RTL_DIR)/reset_buffer.sv"; exit 1; \
	fi
	@if [ ! -f $(CV32E40X_HOME)/cv32e40x_manifest.flist ]; then \
	    echo "ERROR: cannot find $(CV32E40X_HOME)/cv32e40x_manifest.flist"; exit 1; \
	fi
	@if [ ! -f $(CV32E40S_HOME)/cv32e40s_manifest.flist ]; then \
	    echo "ERROR: cannot find $(CV32E40S_HOME)/cv32e40s_manifest.flist"; exit 1; \
	fi
	@echo "RTL_DIR       = $(RTL_DIR)"
	@echo "CV32E40X_HOME = $(CV32E40X_HOME)"
	@echo "CV32E40S_HOME = $(CV32E40S_HOME)"

$(OBJ_DIR):
	mkdir -p $@

$(PATCHED_S_DIR)/.stamp: | $(OBJ_DIR)
	@echo "Patching cv32e40s sources to rename conflicting interfaces..."
	rm -rf $(PATCHED_S_DIR)
	mkdir -p $(PATCHED_S_DIR)
	cp -r $(CV32E40S_HOME)/rtl $(PATCHED_S_DIR)/
	cp -r $(CV32E40S_HOME)/bhv $(PATCHED_S_DIR)/
	test -d $(CV32E40S_HOME)/sva && cp -r $(CV32E40S_HOME)/sva $(PATCHED_S_DIR)/ || true
	find $(PATCHED_S_DIR) -type f \( -name '*.sv' -o -name '*.svh' -o -name '*.vh' \) \
	    -exec sed -i \
	        -e 's/\bif_c_obi\b/if_c_obi_s/g' \
	        -e 's/\bif_xif\b/if_xif_s/g' \
	        -e 's/\brvfi_sim_trace\b/rvfi_sim_trace_s/g' {} \;
	touch $@

$(GEN_X_MANIFEST): $(CV32E40X_HOME)/cv32e40x_manifest.flist | $(OBJ_DIR)
	sed 's|$${DESIGN_RTL_DIR}|$(CV32E40X_HOME)/rtl|g' $< > $@

$(GEN_S_MANIFEST): $(CV32E40S_HOME)/cv32e40s_manifest.flist $(PATCHED_S_DIR)/.stamp | $(OBJ_DIR)
	sed 's|$${DESIGN_RTL_DIR}|$(PATCHED_S_DIR)/rtl|g' $< > $@

build: check-paths $(GEN_X_MANIFEST) $(GEN_S_MANIFEST)
	$(VERILATOR) $(VERILATOR_FLAGS) $(CORE_MANIFESTS) $(LOCAL_SRCS)

run: build
	./$(BIN)

clean:
	rm -rf $(OBJ_DIR) reset_buffer_tb.vcd
