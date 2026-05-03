# Experiments

## Baseline: vLLM ROCm Nightly on 1x MI300X

Date: 2026-05-03

Image: `vllm/vllm-openai-rocm:nightly`

Observed vLLM version: `0.20.1rc1.dev159+ge6ff3e9c8`

Model: `mistralai/Mistral-Medium-3.5-128B`

Settings:

- `MAX_MODEL_LEN=32768`
- `TENSOR_PARALLEL_SIZE=1`
- `MAX_NUM_BATCHED_TOKENS=8192`
- `MAX_NUM_SEQS=4`
- Official checkpoint metadata loaded as `dtype=torch.bfloat16`, `quantization=fp8`
- ROCm FP8 kernel selected by vLLM

Single-request local benchmark:

```text
warmup elapsed=2.24s completion_tokens=64 tok/s=28.51 finish=length
run1 elapsed=8.89s completion_tokens=256 total_tokens=312 tok/s=28.80 finish=length
run2 elapsed=8.92s completion_tokens=256 total_tokens=312 tok/s=28.69 finish=length
run3 elapsed=8.95s completion_tokens=256 total_tokens=312 tok/s=28.62 finish=length
avg_completion_tok_s=28.70
```

## MAX AMD Nightly Probe

Date: 2026-05-03

Image: `modular/max-amd:nightly`

Docker Hub concrete nightly observed: `26.4.0.dev2026050306`

Official docs checked:

- MAX container: https://docs.modular.com/max/container/
- MAX supported models: https://docs.modular.com/max/models/
- `max serve`: https://docs.modular.com/max/cli/serve/

Result: not viable for this model on MI300X in the tested nightly.

Findings:

- MAX AMD rejects the official checkpoint's inferred `float8_e4m3fn` encoding with: `quantization_encoding of 'float8_e4m3fn' not supported by MAX engine`.
- Forcing `main.quantization_encoding=bfloat16` gets past config validation and MAX recognizes `Mistral3ForConditionalGeneration`.
- The model repo ships `chat_template.jinja`, but MAX Mistral3 currently expects `chat_template.json`; using `--chat-template` exposes a MAX tokenizer bug where the loaded template object is later treated as a path.
- After an ephemeral tokenizer patch to honor `--chat-template`, MAX builds and compiles for about a minute, then fails graph compilation in AMD structured attention kernels.

Key compiler error:

```text
constraint failed: MMA shape requires CDNA4 or newer
```

The provisioned Hot Aisle MI300X reports `gfx942`, which is CDNA3. That means the tested MAX nightly currently wants a newer AMD architecture for this Mistral3 attention shape, so it cannot provide a performance comparison on MI300X yet.
