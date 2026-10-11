#!/usr/bin/env python3
"""Check model identity, context, exact token counts and a bounded tool round trip."""
import argparse
import json

from benchmark import (ROOT, LOCAL, api_key, check_usage, context_policy, endpoint_metadata,
                       endpoint_profile, guard, input_tokens, request, write_json)


def check_endpoint(candidate):
    key = api_key(candidate)
    metadata = endpoint_metadata(candidate, key)
    capacity = metadata["props"]["default_generation_settings"]["n_ctx"]
    payload = {"model": candidate["model"], "messages": [
        {"role": "user", "content": "Call echo with value ready."}],
        "tools": [{"type": "function", "function": {"name": "echo", "description": "Echo a value.",
            "parameters": {"type": "object", "properties": {"value": {"type": "string"}},
                           "required": ["value"], "additionalProperties": False}}}],
        "tool_choice": {"type": "function", "function": {"name": "echo"}},
        "reasoning_effort": "none", "chat_template_kwargs": {"enable_thinking": False},
        "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0.05, "repeat_penalty": 1.0,
        "seed": 101, "max_tokens": 128, "stream": False}
    exchanges = []

    def generate():
        count = input_tokens(candidate, key, payload, capacity)
        response = request(candidate, key, payload)
        response.pop("timings", None)
        check_usage(response, count, payload["max_tokens"])
        exchanges.append({"request": json.loads(json.dumps(payload)), "response": response,
                          "input_tokens": count})
        return response["choices"][0]["message"]

    message = generate()
    calls = message.get("tool_calls", [])
    if not calls or any(c["function"]["name"] != "echo" for c in calls):
        raise RuntimeError("Endpoint did not complete the bounded forced-tool check")
    for call in calls:
        if json.loads(call["function"]["arguments"]).get("value") != "ready":
            raise RuntimeError("Endpoint returned invalid tool arguments")
    payload["messages"].append(message)
    payload["messages"].extend({"role": "tool", "tool_call_id": c["id"], "content": '{"value":"ready"}'} for c in calls)
    payload.pop("tool_choice")
    payload.update(max_tokens=32, reasoning_effort=candidate["reasoning_effort"],
                   chat_template_kwargs={"enable_thinking": True})
    generate()  # Includes real reasoning in the bounded usage-accounting check.
    profile = endpoint_profile(metadata)
    if endpoint_profile(endpoint_metadata(candidate, key)) != profile:
        raise RuntimeError("Endpoint profile changed during preflight")
    return {"valid": True, "candidate": candidate, "context_policy": context_policy(),
            "profile": profile, "metadata": metadata, "exchanges": exchanges}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidates", nargs="+")
    args = parser.parse_args()
    guard()
    candidates = json.loads((ROOT / "config/candidates.json").read_text())["candidates"]
    if args.candidates and set(args.candidates) - {c["id"] for c in candidates}:
        parser.error("Unknown candidate ID")
    failed = False
    for candidate in candidates:
        if args.candidates and candidate["id"] not in args.candidates:
            continue
        try:
            result = check_endpoint(candidate)
        except Exception as error:
            result = {"valid": False, "error": str(error)}
            failed = True
        write_json(LOCAL / "endpoint-checks" / (candidate["id"] + ".json"), result)
        print(json.dumps({"candidate": candidate["id"], "valid": result["valid"], "error": result.get("error")}), flush=True)
    guard()
    raise SystemExit(int(failed))


if __name__ == "__main__":
    main()
