# FIR Filter Accelerator results

Prompt revision 2 documentation review; all measurements are retained from the revision 1 build. Measurements below cite retained evidence. Python provides a functional reference and parses measured RTL events; no Python timing model is used.

## Interface

The host-activated kernel has 32-bit AXI4-Stream input/output, one float32 tap/sample/result per word. Command headers contain three unsigned words: opcode, tx_id, count, with TLAST only on word 3. CONFIG=1, PROCESS=2, END=3. Responses have one tx_id word with TLAST. CONFIG returns only its response header; PROCESS returns a header then a separate DATA burst; END returns nothing. AXI-Lite contains control and halted/error/tx_id status. Error precedence is unknown opcode, PROCESS before CONFIG, invalid K, invalid nsamp, then malformed payload TLAST. Sources: fir.py, fir_body_impl.tpp, gen/fir.cpp.

## Design

The folded FIR stores 64 taps and 63 history words. Activation and CONFIG clear state; PROCESS preserves history. Arithmetic is ascending k with separate float32 multiplication and addition, +0 initial sum, and no FMA/reassociation. The inner tap loop requests pipelining; the outer sample loop is sequential. One pending result allows the valid output prefix to close with TLAST on a later framing error. No whole input burst is buffered. Sources: fir_body_impl.tpp; fir_model.py.

Waveflow DataSchemaStep, StreamUtilsStep and ArrayUtilsStep generate schemas/serializers following the installed stream_inband reference. Its automatic boundary extractor rejected a Raise statement, so the implementation uses a native HLS adapter with generated serializers. The reference part/clock remain xc7z020clg484-1 and 10 ns (evidence/reference_probe.json; run.tcl). Installed Vitis is 2026.1 (logs/vitis.log). To reproduce, use /home/js15828/hwdesign/.venv/bin/python prepare.py followed by build.py. To summarize existing results only, run parse_timing.py then write_results.py.

## Targets

| Metric | Required | Observed | Result | Evidence |
| --- | --- | --- | --- | --- |
| Outer sample II | 1 | - (not pipelined) | FAIL | evidence/fir_csynth.xml; evidence/fir_csynth.rpt |
| Inner tap-loop II | no target | 4 | INFO | evidence/fir_Pipeline_tap_loop_csynth.xml |
| Input DATA spacing, max-size PROCESS | 1 cycle | 1 / 269 / 269 cycles | FAIL | evidence/stream_timing.json; evidence/raw_input_beats.csv |
| Output DATA spacing, max-size PROCESS | 1 cycle | 2 / 269 / 269 cycles | FAIL | evidence/stream_timing.json; evidence/raw_output_beats.csv |
| Steady DATA throughput | 1 sample/cycle | 1 sample / 269 cycles | FAIL | evidence/stream_timing.json; evidence/raw_output_beats.csv |
| Estimated clock | strictly <10 ns | 16.100 ns | FAIL | evidence/fir_csynth.xml |
| First DATA latency, max-size PROCESS | no target | 539 cycles | INFO | evidence/stream_timing.json; evidence/cosim_ports.vcd |
| Activation latency and interval | no target | {"latency_min": "72", "latency_avg": "44240", "latency_max": "1102041", "interval_min": "86", "interval_avg": "46088", "interval_max": "1102055"} | INFO | evidence/fir_cosim.rpt |
| Resources | no limit | {"BRAM_18K": "1", "DSP": "5", "FF": "7548", "LUT": "4110", "URAM": "0"} | INFO | evidence/fir_csynth.xml |

DATA spacing is min / median / max in cycles between accepted TVALID && TREADY numerical DATA words; headers/taps/acknowledgments are excluded. The max-size fixture uses 64 taps and 4096 samples. First DATA latency is the first PROCESS input DATA acceptance to first output DATA acceptance. The RTL simulation clock is 10 ns; cycle measurements do not imply the implementation meets its estimated timing. Whole activation latency uses the co-simulation ap_start-to-ap_done measurement; its interval is not sample II. Sources: evidence/stream_timing.json; evidence/fir_cosim.rpt; run.tcl.

Raw measured RTL report (original column order, cycle units):

~~~text
Report time       : Sun Oct 25 09:16:24 AM EDT 2026.
Solution          : solution1.
Simulation tool   : xsim.

+----------+----------+-----------------------------------------------+-----------------------------------------------+----------------------+
|          |          |             Latency(Clock Cycles)             |              Interval(Clock Cycles)           | Total Execution Time |
+   RTL    +  Status  +-----------------------------------------------+-----------------------------------------------+    (Clock Cycles)    +
|          |          |      min      |      avg      |      max      |      min      |      avg      |      max      |                      |
+----------+----------+-----------------------------------------------+-----------------------------------------------+----------------------+
|      VHDL|        NA|             NA|             NA|             NA|             NA|             NA|             NA|                    NA|
|   Verilog|      Pass|             72|          44240|        1102041|             86|          46088|        1102055|               1106342|
+----------+----------+-----------------------------------------------+-----------------------------------------------+----------------------+
~~~

| Scenario | tx_id | Samples | First DATA latency (cycles) | Input DATA spacing | Output DATA spacing | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| 01_03_basic_state_reconfigure | 2 | 4 | 51 | 1 / 3 / 25 | 2 / 25 / 25 | evidence/stream_timing.json |
| 01_03_basic_state_reconfigure | 3 | 1 | 28 | Not measured | Not measured | evidence/stream_timing.json |
| 01_03_basic_state_reconfigure | 5 | 2 | 35 | 1 / 1 / 1 | 2 / 2 / 2 | evidence/stream_timing.json |
| 04_limit_sizes | 8 | 4096 | 539 | 1 / 269 / 269 | 2 / 269 / 269 | evidence/stream_timing.json |
| 05_minimum_taps | 10 | 5 | 35 | 1 / 10.0 / 17 | 2 / 17.0 / 17 | evidence/stream_timing.json |
| 06_single_sample | 13 | 1 | 28 | Not measured | Not measured | evidence/stream_timing.json |
| 08a_recovery | 19 | 4 | 51 | 1 / 3 / 25 | 2 / 25 / 25 | evidence/stream_timing.json |
| 08b_recovery | 24 | 4 | 51 | 1 / 3 / 25 | 2 / 25 / 25 | evidence/stream_timing.json |
| 08c_recovery | 29 | 4 | 51 | 1 / 3 / 25 | 2 / 25 / 25 | evidence/stream_timing.json |
| 08d_recovery | 34 | 4 | 51 | 1 / 3 / 25 | 2 / 25 / 25 | evidence/stream_timing.json |
| 08e_recovery | 40 | 4 | 51 | 1 / 3 / 25 | 2 / 25 / 25 | evidence/stream_timing.json |
| 08f_recovery | 46 | 4 | 51 | 1 / 3 / 25 | 2 / 25 / 25 | evidence/stream_timing.json |
| 08g_recovery | 52 | 4 | 51 | 1 / 3 / 25 | 2 / 25 / 25 | evidence/stream_timing.json |
| 08h_recovery | 58 | 4 | 51 | 1 / 3 / 25 | 2 / 25 / 25 | evidence/stream_timing.json |
| 08i_recovery | 63 | 4 | 51 | 1 / 3 / 25 | 2 / 25 / 25 | evidence/stream_timing.json |
| 09_all_zero | 66 | 17 | 51 | 1 / 25.0 / 25 | 2 / 25.0 / 25 | evidence/stream_timing.json |
| 10_K3_history_reset | 71 | 3 | 51 | 1 / 2.0 / 3 | 2 / 13.5 / 25 | evidence/stream_timing.json |
| 10_K3_history_reset | 69 | 1 | 28 | Not measured | Not measured | evidence/stream_timing.json |

## Verification

| Stage | Observed | Result | Evidence |
| --- | --- | --- | --- |
| Model | 25 | PASS | evidence/model_checks.json; logs/model.log |
| C simulation | 25/25 | PASS | evidence/csim_comparison.csv; logs/attempt2/vitis.log |
| RTL co-simulation | 25/25 | PASS | evidence/fir_cosim.rpt; evidence/cosim_comparison.csv; logs/vitis.log |
| Synthesis | complete | PASS | evidence/fir_csynth.xml; logs/attempt3/vitis.log |

Independent NumPy float64 convolution uses the quantized float32 inputs/taps and resets at CONFIG. Maximum observed absolute difference is 4.3828601067885664e-08 against the required 1e-5 bound (evidence/model_checks.json). Hand examples check basic outputs, history persistence, reconfiguration, all-zero output, and an additional K>1 history-reset case. One testbench process includes all 25 activations, one top call with fresh streams per activation. Nine error activations are each followed immediately by a successful recovery. These are individual-error tests, not a claim of exhaustive combined-error precedence coverage. Sources: fir_model.py; fir_tb.cpp; vectors/manifest.txt.

| Scenario | Model/reference | C simulation | RTL co-simulation | Expected halted:error:tx_id | Reference error | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| 01_03_basic_state_reconfigure | PASS | PASS | PASS | 0:0:0 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 04_limit_sizes | PASS | PASS | PASS | 0:0:0 | 4.3828601067885664e-08 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 05_minimum_taps | PASS | PASS | PASS | 0:0:0 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 06_single_sample | PASS | PASS | PASS | 0:0:0 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 07_empty_activation | PASS | PASS | PASS | 0:0:0 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 08a_unknown | PASS | PASS | PASS | 1:1:17 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 08a_recovery | PASS | PASS | PASS | 0:0:0 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 08b_no_config | PASS | PASS | PASS | 1:2:22 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 08b_recovery | PASS | PASS | PASS | 0:0:0 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 08c_K_zero | PASS | PASS | PASS | 1:3:27 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 08c_recovery | PASS | PASS | PASS | 0:0:0 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 08d_K_65 | PASS | PASS | PASS | 1:3:32 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 08d_recovery | PASS | PASS | PASS | 0:0:0 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 08e_nsamp_zero | PASS | PASS | PASS | 1:4:38 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 08e_recovery | PASS | PASS | PASS | 0:0:0 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 08f_nsamp_4097 | PASS | PASS | PASS | 1:4:44 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 08f_recovery | PASS | PASS | PASS | 0:0:0 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 08g_early_TLAST | PASS | PASS | PASS | 1:5:49 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 08g_recovery | PASS | PASS | PASS | 0:0:0 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 08h_missing_TLAST | PASS | PASS | PASS | 1:5:55 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 08h_recovery | PASS | PASS | PASS | 0:0:0 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 08i_config_mismatch | PASS | PASS | PASS | 1:5:61 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 08i_recovery | PASS | PASS | PASS | 0:0:0 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 09_all_zero | PASS | PASS | PASS | 0:0:0 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |
| 10_K3_history_reset | PASS | PASS | PASS | 0:0:0 | 0.0 | evidence/model_checks.json; evidence/csim_comparison.csv; evidence/cosim_comparison.csv; evidence/fir_cosim.rpt |

The testbench checks data bits, TLAST, status and remaining C-stream words. C comparison CSVs alone do not prove RTL PASS; the RTL report is also required. The timing parser checks native accepted input/output beats against exact consumed-prefix/gold vectors before measuring DATA windows. Native alignment: True (evidence/stream_timing.json; evidence/raw_input_beats.csv; evidence/raw_output_beats.csv). An adapter may prefetch input beyond core reads; native alignment is kept separate from the C remaining-stream check. MCP validation returned success with a multiple-schema warning: schema_info describes the first discovered class, so it is not evidence of two independently selected class descriptions. Sources: evidence/FirCmdHdr_validation.json; evidence/FirRespHdr_validation.json; logs/codegen.log.

## Assumptions

Required characterization covers finite float32 values and zeros, with NaN, infinity, and subnormal inputs explicitly excluded by prompt.md revision 2 (Requirements; Revision history). The former exceptional-value open item is closed by this scope clarification; no new verification was performed.

Headers use the fixed well-formed three-word serialization. An offending payload word is consumed but rejected before arithmetic; only preceding valid results are returned, with final TLAST. A malformed first PROCESS sample emits no response header. Header errors emit no response for that command, while earlier completed responses remain valid. The host resets/restarts after error. Permanent missing input stalls the blocking stream; no hardware timeout is invented. Random maximum-size inputs use seed 20261024, taps in [-1/64,1/64] and samples in [-1,1], then float32 quantization (fir_model.py; evidence/model_checks.json).

## Open Items

- Sample II=1 / one sample per clock was not achieved. Inner tap II and top activation interval are separate quantities. No timing-closure redesign was attempted.
- Estimated clock itself exceeds 10 ns: FAIL. Clock-uncertainty warnings alone do not determine pass/fail.

## Run History

| Run | Prompt revision | Change / outcome | Evidence |
| --- | --- | --- | --- |
| Preparation | 1 | Model checks passed; automatic Waveflow extraction rejected Raise. Used installed schema/serializer API with explicit adapter. MCP initially rejected top-level __file__; moved path use into generation. | logs/codegen_attempt1.log; logs/codegen.log; evidence/attempt1/FirCmdHdr_validation.json |
| Build 1 | 1 | Stopped before C simulation: incompatible config_compile false argument; removed setting, retained strict compiler flags. | logs/attempt1/vitis.log; logs/attempt1/run.tcl |
| Build 2 | 1 | C simulation passed; synthesis rejected INLINE / EXPRESSION_BALANCE conflict. Removed only conflicting body pragma, retaining separate multiply/add functions. | logs/attempt2/vitis.log; evidence/attempt2/csim_comparison.csv |
| Build 3 | 1 | Resumed synthesis successfully. First RTL launch aborted before run all because VCD filter selected no ports. | logs/attempt3/vitis.log; logs/attempt3/fir.tcl; evidence/fir_csynth.xml |
| Build 4 | 1 | Fixed VCD filter using Vitis-generated port types; resumed co-simulation only. No kernel timing-closure redesign. | cosim_only.tcl; logs/vitis.log; evidence/build_status.json; evidence/vcd_hook.json |
| Evidence | 1 | Parsed the existing RTL VCD and reports, without RTL replay or Python timing prediction. | logs/timing_parser.log; evidence/stream_timing.json; write_results.py |
| Documentation update | 2 | Documentation only: close the NaN/infinity/subnormal open item as outside the required characterization scope; classify the measured inner tap-loop II as no target / INFO. Kernel and all measured values unchanged; no C simulation, co-simulation or synthesis rerun. | prompt.md (Requirements; Revision history); existing measurement evidence cited above |
