/* One shared plot. All values come from the public export. */
(() => {
  "use strict";
  const data = window.BENCHMARK_DATA;
  const $ = id => document.getElementById(id);
  const node = (tag, className, text) => {
    const e = document.createElement(tag);
    if (className) e.className = className;
    if (text !== undefined) e.textContent = text;
    return e;
  };
  if (!data || data.schema_version !== 4) {
    $("chart").append(node("p", "empty", "Results could not be loaded. Please reload."));
    $("size-limit").disabled = true;
    return;
  }
  const records = data.results;
  if (records.length === 0) {
    document.querySelector(".size-control").remove();
    document.querySelector("footer").remove();
    $("chart").append(node("p", "empty", "No benchmark results yet."));
    return;
  }
  $("snapshot-note").hidden = !records.some(r => r.resources?.kind === "loaded_snapshot");
  const number = new Intl.NumberFormat("en-US");
  const fmt = value => number.format(value);
  const gb = bytes => bytes == null ? "Not recorded" : `${(bytes / 1e9).toFixed(1)} GB`;
  const hosted = r => r.model.backend === "openai_subscription";
  const thinking = r => ({unknown: "Not reported", on: "On (no level)", off: "Off",
    default: "Server/provider default", unsupported: "Not supported"})[r.settings.reasoning_effort] ||
    r.settings.reasoning_effort || "Not recorded";
  const vram = r => r.resources ? (r.resources.peak_vram_bytes ?? r.resources.gpus.reduce((sum, gpu) => sum + gpu.used_bytes, 0)) : null;
  const context = r => r.settings.window_tokens ? `${fmt(r.settings.window_tokens)} context` : "API";
  const sum = (r, key) => r.cases.every(c => Number.isInteger(c[key])) ? r.cases.reduce((n, c) => n + c[key], 0) : null;
  const measured = r => r.cases.every(c => c.measurement);
  const millis = r => r.cases.reduce((n, c) => n + c.measurement.attempt_ms, 0);
  const readable = value => value == null ? "Not recorded" : typeof value === "boolean" ? (value ? "Enabled" : "Disabled") :
    typeof value === "number" ? fmt(value) : value.replaceAll("_", " ");
  const largest = records.reduce((max, r) => Math.max(max, (r.model.size_bytes || 0) / 1e9), 0);
  const allValue = Math.max(100, Math.ceil(largest / 10) * 10) + 1;
  $("size-limit").max = allValue;
  $("size-limit").value = allValue;
  const settings = {
    max_tokens: "Generation budget / case", budget_policy: "Budget policy", context_policy: "Context policy",
    window_tokens: "Context limit", response_tokens: "Tokens / response", safety_tokens: "Safety tokens",
    seed: "Seed", compaction: "History compaction", reasoning_effort: "Reasoning effort",
    reasoning_effort_source: "Thinking source", thinking_policy: "Thinking policy",
  };
  let selected = null;

  function ticks(total) {
    if (total <= 10) return Array.from({length: total + 1}, (_, i) => i);
    const rough = total / 6, magnitude = 10 ** Math.floor(Math.log10(rough));
    const step = [1, 2, 5, 10].find(n => n * magnitude >= rough) * magnitude;
    const values = Array.from({length: Math.floor(total / step) + 1}, (_, i) => i * step);
    if (values.at(-1) !== total) {
      if (total - values.at(-1) <= step / 2) values.pop();
      values.push(total);
    }
    return values;
  }
  function definitionList(entries) {
    const list = node("dl", "setting-list");
    for (const [label, value] of entries) list.append(node("dt", "", label), node("dd", "", value));
    return list;
  }
  function details(r) {
    const body = node("section", "run-detail");
    body.id = "run-detail";
    body.setAttribute("aria-label", `${r.model.name} details`);
    const heading = node("div", "detail-heading");
    heading.append(node("h2", "", `${r.model.name}${r.model.quantization ? ` · ${r.model.quantization}` : ""} · Thinking: ${thinking(r)}`));
    const close = node("button", "close-detail", "Close ×");
    close.addEventListener("click", () => {
      selected = null;
      render();
      document.getElementById(`point-${r.run_id}`)?.focus();
    });
    heading.append(close);
    body.append(heading);
    if (r.note) body.append(node("p", "detail-note", r.note));
    const layout = node("div", "detail-layout");
    const outcomes = node("div");
    outcomes.append(node("h3", "", "Case outcomes"));
    const table = node("table", "case-table");
    const head = node("thead"), hr = node("tr");
    for (const title of ["Case", "Result", "Output tokens", "Minutes"]) hr.append(node("th", "", title));
    head.append(hr); table.append(head);
    const tbody = node("tbody");
    for (const c of r.cases) {
      const row = node("tr");
      row.append(node("td", "case-id", c.id), node("td", c.passed ? "passed" : "failed", c.passed ? "Pass" : "Fail"),
        node("td", "numeric", c.generated_tokens == null ? "—" : fmt(c.generated_tokens)),
        node("td", "numeric", c.measurement ? (c.measurement.attempt_ms / 60000).toFixed(1) : "—"));
      tbody.append(row);
    }
    table.append(tbody); outcomes.append(table);
    const totalTokens = sum(r, "generated_tokens");
    outcomes.append(definitionList([
      ["Generated tokens · all cases", totalTokens == null ? "Not recorded" : fmt(totalTokens)],
      ["Model calls", sum(r, "model_calls") == null ? "Not recorded" : fmt(sum(r, "model_calls"))],
      ["Attempt time · all cases", measured(r) ? `${(millis(r) / 60000).toFixed(1)} min` : "Not measured"],
    ]));
    if (measured(r)) outcomes.append(node("p", "detail-note", "Attempt time includes model and tool calls; preparation and grading are excluded."));
    const conditions = node("div");
    conditions.append(node("h3", "", "Memory & deployment"));
    const memory = [["Model weights", gb(r.model.size_bytes)], ["Context limit", context(r)]];
    if (r.resources) {
      const p = r.resources;
      if (p.kind === "run_samples") {
        memory.push(["Server context capacity", `${fmt(p.context_tokens)} tokens`], ["VRAM · run peak", gb(p.peak_vram_bytes)], ["Service RAM · run peak", gb(p.peak_ram_bytes)],
          ["RAM + VRAM · simultaneous peak", gb(p.peak_combined_bytes)], ["Process RSS · run peak", gb(p.peak_rss_bytes)],
          ["Memory coverage", `${p.coverage} · ${fmt(p.sample_count)} samples · ${p.interval_ms / 1000}s interval`],
          ["KV cache", p.kv_cache || "Not recorded"], ["Runtime", p.backend_version], ["CPU", p.cpu]);
        for (const [i, gpu] of p.gpus.entries()) memory.push([`GPU ${i + 1} · ${gpu.name} · peak`, `${gb(gpu.used_bytes)} / ${(gpu.capacity_bytes / 2**30).toFixed(0)} GiB`]);
        conditions.append(definitionList(memory), node("p", "detail-note", "Sampled across this run. Service RAM includes charged page cache. Configured context is capacity; actual occupancy varies with the tasks."));
      } else {
      memory.push(["GPU memory · sampled", gb(vram(r))], ["Engine RAM · sampled RSS", gb(p.ram_rss_bytes)],
        ["Engine RAM · lifetime peak RSS", gb(p.ram_lifetime_peak_bytes)],
        ["Service RAM · sampled", gb(p.service_ram_bytes)], ["Service RAM · lifetime peak", gb(p.service_ram_lifetime_peak_bytes)],
        ["KV cache", p.kv_cache || "Not recorded"], ["Runtime", p.backend_version], ["CPU", p.cpu]);
      for (const [i, gpu] of p.gpus.entries()) memory.push([`GPU ${i + 1} · ${gpu.name}`, `${gb(gpu.used_bytes)} / ${(gpu.capacity_bytes / 2**30).toFixed(0)} GiB`]);
      conditions.append(definitionList(memory), node("p", "detail-note", `Loaded-process observation: ${new Date(p.observed_at).toISOString().replace("T", " ")}. Lifetime peaks cover the process/service lifetime, not this run. The configured context limit does not establish a fully occupied context measurement.`));
      }
    } else {
      memory.push(["GPU / RAM observation", hosted(r) ? "Hosted API" : "Not captured"]);
      conditions.append(definitionList(memory));
    }
    conditions.append(node("h3", "settings-heading", "Run settings"), definitionList(
      Object.entries(r.settings).map(([key, value]) => [settings[key] || readable(key), readable(value)])));
    conditions.append(node("p", "record-id", `Date: ${r.created_at}\nRun: ${r.run_id}`));
    if (r.evidence_url) {
      const link = node("a", "", "Recorded evidence ↗"); link.href = r.evidence_url; conditions.append(link);
    }
    layout.append(outcomes, conditions); body.append(layout);
    return body;
  }
  function plot(shown) {
    const figure = node("div", "plot");
    const area = node("div", "plot-area");
    area.style.setProperty("--row-count", Math.max(shown.length, 1));
    for (const value of ticks(data.benchmark.case_count)) {
      const line = node("div", "plot-grid");
      line.style.left = `${value / data.benchmark.case_count * 100}%`;
      line.append(node("span", "plot-tick", value));
      area.append(line);
    }
    for (const [i, r] of shown.entries()) {
      const position = r.passed / r.total;
      const point = node("button", "plot-point" + (selected === r.run_id ? " selected" : "") + (position < .2 ? " near-start" : ""));
      point.id = `point-${r.run_id}`;
      point.style.left = `${position * 100}%`;
      point.style.setProperty("--score-position", position);
      point.style.setProperty("--row-index", i);
      point.setAttribute("aria-label", `${r.model.name}${r.model.quantization ? ` ${r.model.quantization}` : ""}, thinking ${thinking(r)}, ${r.passed} of ${r.total} cases passed. Show details`);
      point.setAttribute("aria-expanded", String(selected === r.run_id));
      if (selected === r.run_id) point.setAttribute("aria-controls", "run-detail");
      const label = node("span", "point-label");
      label.append(node("span", "model-name", r.model.name), node("span", "point-meta", [r.model.quantization, `Thinking: ${thinking(r)}`,
        hosted(r) ? "API" : `${gb(r.model.size_bytes)} weights`, r.settings.window_tokens ? `${r.settings.window_tokens / 1024}K ctx` : null].filter(Boolean).join(" · ")));
      if (r.resources) label.append(node("span", "point-memory", r.resources.kind === "run_samples" ?
        `${gb(vram(r))} VRAM · ${gb(r.resources.peak_ram_bytes)} RAM · ${r.resources.coverage === "complete" ? "run peaks" : "partial samples"}` :
        `${gb(vram(r))} VRAM · ${gb(r.resources.service_ram_lifetime_peak_bytes ?? r.resources.ram_lifetime_peak_bytes)} RAM peak¹`));
      else if (!hosted(r)) label.append(node("span", "point-memory", "RAM / VRAM not recorded"));
      if (records.filter(other => other.model.name === r.model.name && other.model.quantization === r.model.quantization).length > 1) {
        label.append(node("span", "point-meta", `${r.created_at.slice(0, 10)} · ${r.run_id.split("-").at(-1)}`));
      }
      const dot = node("span", "result-dot");
      const score = node("span", "point-score", `${r.passed}/${r.total}`);
      point.append(label, dot, score);
      point.addEventListener("click", () => {
        selected = selected === r.run_id ? null : r.run_id;
        render();
        document.getElementById(point.id)?.focus();
      });
      area.append(point);
    }
    figure.append(area, node("div", "axis-caption", "Cases passed"));
    return figure;
  }
  function render() {
    const cap = Number($("size-limit").value), all = cap === allValue;
    const shown = records.filter(r => all || r.model.size_bytes !== null && r.model.size_bytes / 1e9 <= cap)
      .sort((a, b) => b.passed - a.passed || a.model.name.localeCompare(b.model.name) || Date.parse(b.created_at) - Date.parse(a.created_at));
    $("size-value").textContent = all ? "All" : `${cap} GB`;
    $("size-limit").setAttribute("aria-valuetext", all ? "All models" : `Up to ${cap} GB of model weights`);
    $("chart").replaceChildren();
    if (shown.length) $("chart").append(plot(shown));
    else $("chart").append(node("p", "empty", "No models within this size limit."));
    const active = shown.find(r => r.run_id === selected);
    if (active) $("chart").append(details(active)); else selected = null;
    const unknownSizes = records.some(r => r.model.size_bytes === null);
    $("result-status").textContent = `${shown.length} / ${records.length} runs` + (!all && unknownSizes ? " · API / unknown sizes hidden" : "");
  }
  $("size-limit").addEventListener("input", render);
  render();
})();
