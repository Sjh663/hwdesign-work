# FIR Filter Accelerator

Build a Vitis HLS kernel in this folder following the Waveflow stream_inband
example (https://sdrangan.github.io/waveflow/docs/examples/stream_inband/) and
the command-response pattern. Where the example and the command-response
pattern differ, follow the command-response pattern.

## Operation

The kernel is a streaming finite-impulse-response (FIR) filter. For each output
sample, in order:

```
y[n] = sum_{k=0}^{K-1} h[k] * x[n-k]
```

where `K` is the number of taps, `h[k]` are the filter taps set by the most
recent `CONFIG` command, and `x` is the input sample stream.

Boundary behavior: the delay line starts all zeros at the beginning of every
activation and is cleared by every `CONFIG` command. Terms with `n-k < 0`
therefore use `x = 0` (zero padding); the sum still runs over all `K` taps,
it is not truncated.

State that carries from one command to the next: the delay line, i.e. the
last `K-1` input samples. It persists across `PROCESS` commands within one
activation, so a `PROCESS` command continues exactly where the previous one
left off. A `CONFIG` command in the middle of an activation replaces the taps
for all later `PROCESS` commands and clears the delay line. Nothing carries
from one activation to the next: taps, delay line, and status registers are
all cleared at the start of each activation.

## Requirements

Data formats: every sample, tap, and output value is one 32-bit IEEE-754
floating-point word. One input word carries exactly one sample, so "one
sample per clock" and "one input word per clock" mean the same thing.

Accumulation: each output is accumulated in single precision, in tap order
`k = 0` to `K-1`, starting from `0.0f`. The accumulation order and rounding
must be identical in the Python model, the C simulation, and the
co-simulation, so that all three agree bit for bit. No optimization that
changes rounding of the accumulation is allowed: no reassociation of the sum
and no contraction of a multiply-add into a single fused rounding.

Largest sizes the hardware must handle (these set its buffers):

- Maximum tap count `K_MAX = 64`. The tap buffer holds 64 floats and the
  delay line holds `K_MAX - 1 = 63` samples.
- Maximum samples in one `PROCESS` burst: 4096. The host never sends more
  than 4096 samples in a single `PROCESS` command; a longer stream must be
  split across several `PROCESS` commands. The kernel processes
  sample-by-sample as the stream arrives; it is not required to buffer a
  whole burst.

Throughput and clock targets:

- Throughput target: one input sample per clock, i.e. initiation interval
  II = 1 for the outer sample loop.
- Clock target: the Vitis estimated clock is under 10 ns. A warning about
  the clock-uncertainty margin is not a failure.
- Latency: no fixed target is set; report the measured latency from
  co-simulation (first-output latency and total activation latency).
- The part and the clock come from the reference example; do not change them.

A missed target is reported honestly as FAIL in `results.md`. Do not rework
the kernel to close timing, and do not build a timing model in Python.

## Commands and parameters

There are three commands: `CONFIG`, `PROCESS`, and `END`. You choose the
numeric command codes, the header layouts, and how values pack into words,
and you write them down in the Interface section of `results.md`. Every
command header carries the command type and a host-assigned transaction id
(`tx_id`). Every response header echoes the `tx_id` of its command.

- `CONFIG`: the header carries `K`, the tap count. It is followed by a data
  burst of exactly `K` float32 taps in order `h[0]` to `h[K-1]`. On success
  the kernel sends a response header echoing `tx_id` and no data burst.
  `K` is validated before any tap data is read.
- `PROCESS`: the header carries `nsamp`, the number of input samples in the
  following burst. It is followed by a data burst of exactly `nsamp` float32
  samples. On success the kernel sends a response header echoing `tx_id`,
  followed by a data burst of exactly `nsamp` float32 outputs in order.
  `nsamp` is validated before any sample data is read.
- `END`: a header only, with no data burst. It ends the activation. It
  produces no response header; completion is signaled by `ap_done`.

Rules:

- An activation must begin with `CONFIG`. A `PROCESS` command before any
  `CONFIG` in the activation is an error.
- `END` as the first command of an activation is a valid empty activation:
  it returns cleanly with `ap_done`, no error, and no output.
- `CONFIG` may appear again in the middle of an activation; it replaces the
  taps and clears the delay line, as stated under Operation.

Invalid parameter values, checked before any data is read:

- `CONFIG` with `K = 0` or `K > 64`.
- `PROCESS` with `nsamp = 0` or `nsamp > 4096`.
- `PROCESS` before any `CONFIG` in the activation.
- An unknown command code.

## Errors

Errors go in AXI-Lite status registers (halted, error code, tx_id). On an
error the kernel closes any output burst it started with TLAST and returns
without reading more input. Nothing persists between activations: the status
registers are cleared at the start of each one.

Error codes (fixed by this prompt):

| Code | Name | Condition |
| --- | --- | --- |
| 1 | `E_UNKNOWN_CMD` | Unknown command code |
| 2 | `E_NO_CONFIG` | `PROCESS` before any `CONFIG` in the activation |
| 3 | `E_BAD_TAP_COUNT` | `CONFIG` with `K = 0` or `K > 64` |
| 4 | `E_BAD_LENGTH` | `PROCESS` with `nsamp = 0` or `nsamp > 4096` |
| 5 | `E_BAD_BURST` | A burst whose TLAST comes early or is missing, or whose length does not match its header (`K` taps for `CONFIG`, `nsamp` samples for `PROCESS`) |

Precedence, when several errors apply to one command, highest first:

1. Unknown command code.
2. `PROCESS` before any `CONFIG`.
3. Invalid header parameter (`K` or `nsamp`).
4. Burst error (TLAST early, missing, or length mismatch), detected while
   reading the burst.

What the kernel sends before reporting each error:

- Header errors (codes 1–4): no output burst has started, so the kernel
  sends nothing on the output stream. It sets the status registers
  (`halted`, error code, and the offending command's `tx_id`) and returns.
- Burst errors (code 5): any outputs already computed for samples fully
  processed before the error was detected are sent, and the partial output
  burst is closed with TLAST on the last word written. The kernel then sets
  the status registers and returns without reading further input. If no
  output was written yet, nothing is sent.
- In every case the status registers report the `tx_id` of the command that
  caused the error, and after an error the input stream's contents are
  undefined: recovery is the host's job (read the status, reset the stream
  path, start a fresh activation).

## Verification

How the Python model is checked independently of itself:

- Hand-computed examples (all values exactly representable in binary, so
  these must match exactly):
  - Taps `h = [1, 0.5, -0.25]` (`K = 3`), input `[1, 2, 3, 4]`:
    outputs `[1, 2.5, 3.75, 5.0]`.
    (For example `y[2] = 1*3 + 0.5*2 + (-0.25)*1 = 3.75`.)
  - Same activation, next `PROCESS` command with input `[5]`:
    output `[6.25]`, using the carried history (`1*5 + 0.5*4 + (-0.25)*3`).
  - After a new `CONFIG` with `K = 1`, `h = [2]` (delay line cleared),
    input `[3, -1]`: outputs `[6, -2]`.
  - All-zero input gives all-zero output.
- NumPy reference (float64): for each activation, concatenate its input
  stream with zero initial history, reset the history at each `CONFIG`,
  and compute `np.convolve(x, h)[:len(x)]` per segment. The float32 model
  must agree with this reference to a maximum absolute difference of
  `1e-5`. The hand-computed examples above must match exactly.

The scenarios, in one co-simulation run, in this order (the model, the C
simulation, and the co-simulation must agree bit for bit in every one):

1. Basic: `K = 3`, taps `[1, 0.5, -0.25]`, `PROCESS` input `[1, 2, 3, 4]`,
   expected outputs `[1, 2.5, 3.75, 5.0]`.
2. State across commands: in the same activation, a second `PROCESS` with
   input `[5]`, expected output `[6.25]`.
3. Parameter change mid-activation: new `CONFIG` with `K = 1`, taps `[2]`,
   then `PROCESS` input `[3, -1]`, expected outputs `[6, -2]`. This checks
   that the delay line was cleared by the `CONFIG`.
4. Limit sizes: `K = 64` (maximum tap count) with a 4096-sample `PROCESS`
   burst (maximum burst length), checked against the NumPy reference
   within `1e-5` and bit-for-bit across model, C simulation, and
   co-simulation.
5. Minimum taps: `K = 1` (pure scaling) on a short input.
6. Single-sample burst: `nsamp = 1` with `K > 1`, checking the zero-padding
   at the start of the stream.
7. Empty activation: `END` as the first command, returning cleanly with
   `ap_done`, no error, and no output.
8. One activation per error, each followed by a fresh activation that must
   pass (the basic scenario 1):
   - Unknown command code, expecting code 1.
   - `PROCESS` before any `CONFIG`, expecting code 2.
   - `CONFIG` with `K = 0`, expecting code 3.
   - `CONFIG` with `K = 65`, expecting code 3.
   - `PROCESS` with `nsamp = 0`, expecting code 4.
   - `PROCESS` with `nsamp = 4097`, expecting code 4.
   - `PROCESS` burst with TLAST early (header promises 4 samples, burst
     ends after 2), expecting code 5 and a partial output burst closed
     with TLAST.
   - `PROCESS` burst with TLAST missing (extra words beyond `nsamp`),
     expecting code 5.
   - `CONFIG` burst length mismatch (`K = 3` but only 2 taps before
     TLAST), expecting code 5.

Compare the model, C simulation and co-simulation bit for bit. Run
co-simulation once: one testbench run that walks through every scenario in
order, calling the kernel once per activation with fresh streams, including
each error activation and the fresh activation after it.

## results.md

Write results.md with these sections:

- Interface: the command and response layouts, how values pack into words,
  the status registers and the error codes.
- Design: the loop structure, where state is kept, and how the throughput
  target is reached.
- Targets: each target above with the required value, the measured value,
  PASS/FAIL and the file it came from (co-simulation for timing; synthesis
  for clock, II and resources). Always report the latency and throughput
  from co-simulation and the estimated clock and resources from synthesis,
  writing "no target" where this prompt sets none.
- Verification: the model's check against the hand-computed examples and the
  reference; then one row per scenario saying whether the model, C simulation
  and co-simulation agree, and for each error scenario the status it set and
  whether the fresh activation after it passed. Name the source file of each.
- Assumptions: every place this prompt was silent or ambiguous and what you
  chose, apart from interface details already given under Interface.
- Open Items: questions you could not settle, and anything that failed or
  was not done, or "None".
- Run History: one row per run, with the prompt version, what was built or
  changed, and what passed, so that a later run can continue from here.

Every number and PASS/FAIL in Targets and Verification names the file it came
from (a log, a comparison output or a synthesis report), and that file stays in
this folder to be committed: a reviewer opens them to check results.md.

## Revision history

| Version | Change | Why |
| --- | --- | --- |
| 1 | First version |  |
