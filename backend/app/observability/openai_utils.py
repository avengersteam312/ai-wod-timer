"""
Shared OpenAI token recording utilities.

Handles two different usage object shapes:
- Raw OpenAI SDK: response.usage.prompt_tokens / completion_tokens
- OpenAI Agents SDK RunResult: result.usage.input_tokens / output_tokens
"""

from app.observability.metrics import ai_tokens_used_total, ai_estimated_cost_usd_total

# USD per 1M tokens — (input, output). Update when OpenAI changes rates.
# fmt: off
MODEL_PRICING: dict[str, tuple[float, float]] = {
    "gpt-4o":            (2.50, 10.00),
    "gpt-4o-mini":       (0.15,  0.60),
    "gpt-4.1":           (2.00,  8.00),
    "gpt-4.1-mini":      (0.40,  1.60),
    "gpt-4-vision-preview": (10.00, 30.00),
}
# fmt: on


def _record(model: str, input_tokens: int, output_tokens: int) -> None:
    ai_tokens_used_total.add(input_tokens, {"model": model, "direction": "input"})
    ai_tokens_used_total.add(output_tokens, {"model": model, "direction": "output"})
    input_price, output_price = MODEL_PRICING.get(model, (0.0, 0.0))
    cost_usd = (input_tokens * input_price + output_tokens * output_price) / 1_000_000
    ai_estimated_cost_usd_total.add(cost_usd, {"model": model})


def record_openai_usage(response, model: str) -> tuple[int, int]:
    """
    Record token usage from a raw openai.ChatCompletion response.

    Usage shape: response.usage.prompt_tokens / completion_tokens
    Returns (input_tokens, output_tokens).
    """
    usage = getattr(response, "usage", None)
    if usage is None:
        return 0, 0
    input_tokens = int(getattr(usage, "prompt_tokens", 0) or 0)
    output_tokens = int(getattr(usage, "completion_tokens", 0) or 0)
    _record(model, input_tokens, output_tokens)
    return input_tokens, output_tokens


def record_agents_usage(result, model: str) -> tuple[int, int]:
    """
    Record token usage from an OpenAI Agents SDK RunResult.

    Usage shape: result.usage.input_tokens / output_tokens
    Returns (input_tokens, output_tokens).
    """
    usage = getattr(result, "usage", None)
    if usage is None:
        return 0, 0
    input_tokens = int(getattr(usage, "input_tokens", 0) or 0)
    output_tokens = int(getattr(usage, "output_tokens", 0) or 0)
    _record(model, input_tokens, output_tokens)
    return input_tokens, output_tokens
