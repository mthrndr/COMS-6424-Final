.PHONY: lint-top

lint-top:
	verilator --lint-only -Wall \
		-Wno-UNUSED -Wno-PINCONNECTEMPTY -Wno-PINMISSING -Wno-GENUNNAMED \
		-Wno-IMPLICIT -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-ASCRANGE -Wno-DECLFILENAME \
		-I../cores/cv32e40s/rtl/include/ \
		-I../cores/cv32e40x/rtl/include/ \
		-y ../cores/cv32e40s/rtl/ \
		-y ../cores/cv32e40x/rtl/ \
		-y ../cores/cv32e40s/bhv/ \
		-y ../cores/cv32e40x/bhv/ \
		-y ../core-v-verif/cv32e40s/tb/core/ \
		../cores/cv32e40s/rtl/include/cv32e40s_pkg.sv \
		../cores/cv32e40x/rtl/include/cv32e40x_pkg.sv \
		../cores/cv32e40s/bhv/cv32e40s_sim_clock_gate.sv \
		../cores/cv32e40s/bhv/cv32e40s_sim_sffs.sv \
		../cores/cv32e40s/bhv/cv32e40s_sim_sffr.sv \
		../cores/cv32e40x/bhv/cv32e40x_sim_clock_gate.sv \
		../core-v-verif/cv32e40s/tb/core/mm_ram.sv \
		top.sv \
		top_tb_wrapper.sv 2>&1 | tee lint_results.log
