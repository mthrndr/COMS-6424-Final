CV32E40X_HOME ?= ../../cores/cv32e40x
CV32E40S_HOME ?= ../../cores/cv32e40s
RTL_DIR       ?= ../../rtl

VERILATOR ?= verilator

OBJ_DIR = obj_dir

VERILATOR_FLAGS = \
    --binary \
    --trace \
    --timing \
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

RB_TOP      	= reset_buffer_tb
RB_SRCS     	= $(RTL_DIR)/reset_buffer.sv reset_buffer_tb.sv
RB_BIN      	= $(OBJ_DIR)/V$(RB_TOP)

GEN_X_MANIFEST  = $(OBJ_DIR)/cv32e40x_manifest.flist
GEN_S_MANIFEST  = $(OBJ_DIR)/cv32e40s_manifest.flist
PATCHED_S_DIR   = $(OBJ_DIR)/cv32e40s_patched
CORE_MANIFESTS  = -f $(GEN_X_MANIFEST) -f $(GEN_S_MANIFEST)

FIFO_TOP    	= tb_fifo
FIFO_SRCS   	= $(RTL_DIR)/fifo.sv fifo_tb.sv
FIFO_BIN    	= $(OBJ_DIR)/V$(FIFO_TOP)

COMP_TOP    	= comparison_unit_tb
COMP_SRCS	= $(RTL_DIR)/comparison_unit.sv $(RTL_DIR)/fifo.sv comparison_unit_tb.sv
COMP_BIN	= $(OBJ_DIR)/V$(COMP_TOP)

MMU_TOP		= ext_mmu_tb
MMU_SRCS	= $(RTL_DIR)/ext_mmu.sv $(RTL_DIR)/fifo.sv ext_mmu_tb.sv
MMU_BIN		= $(OBJ_DIR)/V$(MMU_TOP)

.PHONY: all test-reset-buffer test-fifo test-comparison-unit clean check-paths

all: test-reset-buffer test-fifo test-comparison-unit test-ext-mmu

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

$(PATCHED_S_DIR)/.stamp: makefile | $(OBJ_DIR)
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

$(GEN_X_MANIFEST): $(CV32E40X_HOME)/cv32e40x_manifest.flist makefile | $(OBJ_DIR)
	sed 's|$${DESIGN_RTL_DIR}|$(CV32E40X_HOME)/rtl|g' $< > $@

$(GEN_S_MANIFEST): $(CV32E40S_HOME)/cv32e40s_manifest.flist $(PATCHED_S_DIR)/.stamp makefile | $(OBJ_DIR)
	sed 's|$${DESIGN_RTL_DIR}|$(PATCHED_S_DIR)/rtl|g' $< > $@

$(RB_BIN): check-paths $(GEN_X_MANIFEST) $(GEN_S_MANIFEST)
	$(VERILATOR) $(VERILATOR_FLAGS) --top $(RB_TOP) \
		$(CORE_MANIFESTS) $(RB_SRCS)

test-reset-buffer: $(RB_BIN)
	-./$(RB_BIN)

$(FIFO_BIN): $(FIFO_SRCS) | $(OBJ_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) --top $(FIFO_TOP) \
		$(FIFO_SRCS)

test-fifo: $(FIFO_BIN)
	-./$(FIFO_BIN)

$(COMP_BIN): $(COMP_SRCS) | $(OBJ_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) --top $(COMP_TOP) \
		$(COMP_SRCS)

test-comparison-unit: $(COMP_BIN)
	-./$(COMP_BIN)

$(MMU_BIN): $(MMU_SRCS) | $(OBJ_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) --top $(MMU_TOP) \
		$(MMU_SRCS)

test-ext-mmu: $(MMU_BIN)
	-./$(MMU_BIN)

clean:
	rm -rf $(OBJ_DIR) reset_buffer_tb.vcd
