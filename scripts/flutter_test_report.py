#!/usr/bin/env python3
"""
Run Flutter tests/analyze and write an HTML report.

Usage:
    python3 scripts/flutter_test_report.py
    python3 scripts/flutter_test_report.py --output-dir flutter/test/output_results
"""

import argparse
import datetime as dt
import html
import json
import os
import shlex
import subprocess
import sys
from collections import defaultdict
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
FLUTTER_DIR = PROJECT_ROOT / "flutter"
DEFAULT_OUTPUT_DIR = FLUTTER_DIR / "test" / "output_results"
LOGIN_SHELL = os.environ.get("SHELL", "/bin/zsh")


def _relative_to_flutter(path_value):
    if not path_value:
        return ""

    path = Path(path_value)
    if not path.is_absolute():
        return path_value

    try:
        return str(path.relative_to(FLUTTER_DIR))
    except ValueError:
        return str(path)


class MachineReport:
    def __init__(self):
        self.suites = {}
        self.tests = {}
        self.test_order = []
        self.errors = defaultdict(list)
        self.prints = defaultdict(list)

    def add_line(self, line):
        try:
            decoded = json.loads(line)
        except json.JSONDecodeError:
            return

        if isinstance(decoded, list):
            for event in decoded:
                if isinstance(event, dict):
                    self._add_event(event)
            return

        if isinstance(decoded, dict):
            self._add_event(decoded)

    def _add_event(self, event):
        event_type = event.get("type")
        if event_type == "suite":
            suite = event.get("suite", {})
            suite_id = suite.get("id")
            if suite_id is not None:
                self.suites[suite_id] = suite.get("path") or ""
            return

        if event_type == "testStart":
            test = event.get("test", {})
            test_id = test.get("id")
            if test_id is None:
                return
            self.tests[test_id] = {
                "id": test_id,
                "name": test.get("name", "(unnamed test)"),
                "suite_id": test.get("suiteID"),
                "hidden": bool(test.get("hidden", False)),
                "result": "running",
                "time_ms": None,
            }
            self.test_order.append(test_id)
            return

        if event_type == "print":
            test_id = event.get("testID")
            if test_id is not None:
                self.prints[test_id].append(event.get("message", ""))
            return

        if event_type == "error":
            test_id = event.get("testID", "__global__")
            message = event.get("error", "")
            stack = event.get("stackTrace", "")
            if stack:
                message = "{}\n{}".format(message, stack)
            self.errors[test_id].append(message)
            return

        if event_type == "testDone":
            test = event.get("test", {})
            test_id = test.get("id")
            if test_id is None:
                return

            test_entry = self.tests.setdefault(
                test_id,
                {
                    "id": test_id,
                    "name": test.get("name", "(unnamed test)"),
                    "suite_id": test.get("suiteID"),
                    "hidden": bool(test.get("hidden", False)),
                    "result": "running",
                    "time_ms": None,
                },
            )
            if test_id not in self.test_order:
                self.test_order.append(test_id)
            test_entry["hidden"] = bool(test.get("hidden", test_entry["hidden"]))
            test_entry["result"] = event.get("result", "unknown")
            test_entry["time_ms"] = event.get("time")

    def visible_tests(self):
        visible = []
        for test_id in self.test_order:
            test = self.tests[test_id]
            if test["hidden"]:
                continue
            if str(test["name"]).startswith("loading "):
                continue
            visible.append(
                {
                    "name": test["name"],
                    "suite": _relative_to_flutter(
                        self.suites.get(test["suite_id"], "")
                    ),
                    "result": test["result"],
                    "time_ms": test["time_ms"],
                    "errors": self.errors.get(test_id, []),
                    "prints": self.prints.get(test_id, []),
                }
            )
        return visible


def run_machine_command(command, cwd):
    shell_command = shlex.join(command)
    process = subprocess.Popen(
        [LOGIN_SHELL, "-lc", shell_command],
        cwd=str(cwd),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    tracker = MachineReport()
    output_lines = []

    assert process.stdout is not None
    for line in process.stdout:
        stripped = line.rstrip("\n")
        output_lines.append(stripped)
        tracker.add_line(stripped)

    return_code = process.wait()
    return return_code, "\n".join(output_lines), tracker


def run_text_command(command, cwd):
    shell_command = shlex.join(command)
    completed = subprocess.run(
        [LOGIN_SHELL, "-lc", shell_command],
        cwd=str(cwd),
        capture_output=True,
        text=True,
    )
    output = completed.stdout
    if completed.stderr:
        output = "{}\n{}".format(output, completed.stderr).strip()
    return completed.returncode, output


def build_html(
    test_rows, test_exit_code, analyze_exit_code, analyze_output, generated_at
):
    passed = sum(1 for row in test_rows if row["result"] == "success")
    failed = sum(1 for row in test_rows if row["result"] in {"failure", "error"})
    skipped = sum(1 for row in test_rows if row["result"] == "skipped")

    test_status = "PASS" if test_exit_code == 0 else "FAIL"
    analyze_status = "PASS" if analyze_exit_code == 0 else "FAIL"

    row_html = []
    for row in test_rows:
        status = row["result"].upper()
        css_class = "pass"
        if row["result"] in {"failure", "error"}:
            css_class = "fail"
        elif row["result"] == "skipped":
            css_class = "skip"

        details = []
        if row["prints"]:
            details.append(
                "<details><summary>Captured logs</summary><pre>{}</pre></details>".format(
                    html.escape("\n".join(row["prints"]))
                )
            )
        if row["errors"]:
            details.append(
                "<details open><summary>Errors</summary><pre>{}</pre></details>".format(
                    html.escape("\n\n".join(row["errors"]))
                )
            )

        duration = ""
        if row["time_ms"] is not None:
            duration = "{:.2f}s".format(row["time_ms"] / 1000.0)

        row_html.append(
            """
            <tr>
              <td><span class="badge {css_class}">{status}</span></td>
              <td>{name}</td>
              <td>{suite}</td>
              <td>{duration}</td>
            </tr>
            <tr class="detail-row">
              <td colspan="4">{details}</td>
            </tr>
            """.format(
                css_class=css_class,
                status=html.escape(status),
                name=html.escape(row["name"]),
                suite=html.escape(row["suite"]),
                duration=html.escape(duration),
                details="".join(details)
                or '<span class="muted">No extra output</span>',
            )
        )

    return """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Flutter Test Report</title>
  <style>
    :root {{
      --bg: #f5f1e8;
      --panel: #fffdf8;
      --ink: #1f2933;
      --muted: #667085;
      --pass: #1f7a4d;
      --fail: #b42318;
      --skip: #9a6700;
      --border: #d8cec0;
      --accent: #c66b3d;
    }}
    body {{
      margin: 0;
      font-family: "IBM Plex Sans", "Segoe UI", sans-serif;
      background:
        radial-gradient(circle at top right, rgba(198, 107, 61, 0.12), transparent 28%),
        linear-gradient(180deg, #f8f4eb 0%, var(--bg) 100%);
      color: var(--ink);
    }}
    main {{
      max-width: 1200px;
      margin: 0 auto;
      padding: 32px 20px 48px;
    }}
    .hero {{
      background: var(--panel);
      border: 1px solid var(--border);
      border-radius: 18px;
      padding: 24px;
      box-shadow: 0 18px 50px rgba(31, 41, 51, 0.08);
    }}
    h1, h2 {{
      margin: 0 0 12px;
      font-family: "Space Grotesk", "IBM Plex Sans", sans-serif;
    }}
    .meta {{
      color: var(--muted);
      margin-top: 8px;
    }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 12px;
      margin-top: 20px;
    }}
    .card {{
      background: var(--panel);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 16px;
    }}
    .card .label {{
      color: var(--muted);
      font-size: 0.85rem;
      text-transform: uppercase;
      letter-spacing: 0.04em;
    }}
    .card .value {{
      margin-top: 8px;
      font-size: 1.8rem;
      font-weight: 700;
    }}
    .badge {{
      display: inline-block;
      min-width: 72px;
      padding: 4px 10px;
      border-radius: 999px;
      font-size: 0.8rem;
      font-weight: 700;
      text-align: center;
    }}
    .pass {{
      color: var(--pass);
      background: rgba(31, 122, 77, 0.12);
    }}
    .fail {{
      color: var(--fail);
      background: rgba(180, 35, 24, 0.12);
    }}
    .skip {{
      color: var(--skip);
      background: rgba(154, 103, 0, 0.12);
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      margin-top: 16px;
      background: var(--panel);
      border: 1px solid var(--border);
      border-radius: 16px;
      overflow: hidden;
    }}
    th, td {{
      text-align: left;
      padding: 14px 16px;
      border-bottom: 1px solid var(--border);
      vertical-align: top;
    }}
    th {{
      background: rgba(198, 107, 61, 0.08);
      font-size: 0.85rem;
      text-transform: uppercase;
      letter-spacing: 0.04em;
    }}
    .detail-row td {{
      background: rgba(31, 41, 51, 0.02);
    }}
    details {{
      margin: 8px 0;
    }}
    pre {{
      white-space: pre-wrap;
      word-break: break-word;
      margin: 8px 0 0;
      padding: 12px;
      border-radius: 12px;
      background: #1f2933;
      color: #f8fafc;
      overflow-x: auto;
    }}
    .section {{
      margin-top: 24px;
    }}
    .muted {{
      color: var(--muted);
    }}
  </style>
</head>
<body>
  <main>
    <section class="hero">
      <h1>Flutter Quality Report</h1>
      <div class="meta">Generated {generated_at}</div>
      <div class="grid">
        <div class="card">
          <div class="label">Flutter Test</div>
          <div class="value"><span class="badge {test_badge}">{test_status}</span></div>
        </div>
        <div class="card">
          <div class="label">Flutter Analyze</div>
          <div class="value"><span class="badge {analyze_badge}">{analyze_status}</span></div>
        </div>
        <div class="card">
          <div class="label">Passed</div>
          <div class="value">{passed}</div>
        </div>
        <div class="card">
          <div class="label">Failed</div>
          <div class="value">{failed}</div>
        </div>
        <div class="card">
          <div class="label">Skipped</div>
          <div class="value">{skipped}</div>
        </div>
        <div class="card">
          <div class="label">Total Visible Tests</div>
          <div class="value">{total}</div>
        </div>
      </div>
    </section>

    <section class="section">
      <h2>Test Cases</h2>
      <table>
        <thead>
          <tr>
            <th>Status</th>
            <th>Test</th>
            <th>Suite</th>
            <th>Duration</th>
          </tr>
        </thead>
        <tbody>
          {rows}
        </tbody>
      </table>
    </section>

    <section class="section">
      <h2>Analyzer Output</h2>
      <pre>{analyze_output}</pre>
    </section>
  </main>
</body>
</html>
""".format(
        generated_at=html.escape(generated_at),
        test_badge="pass" if test_exit_code == 0 else "fail",
        test_status=html.escape(test_status),
        analyze_badge="pass" if analyze_exit_code == 0 else "fail",
        analyze_status=html.escape(analyze_status),
        passed=passed,
        failed=failed,
        skipped=skipped,
        total=len(test_rows),
        rows="".join(row_html),
        analyze_output=html.escape(analyze_output.strip() or "(no analyzer output)"),
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output-dir",
        default=str(DEFAULT_OUTPUT_DIR),
        help="Directory where the HTML report and raw logs will be written.",
    )
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    print("Running flutter test --machine ...")
    test_exit_code, test_output, machine_report = run_machine_command(
        ["flutter", "test", "--machine"],
        FLUTTER_DIR,
    )
    (output_dir / "flutter_test_machine.log").write_text(
        test_output + "\n",
        encoding="utf-8",
    )

    print("Running flutter analyze ...")
    analyze_exit_code, analyze_output = run_text_command(
        ["flutter", "analyze"],
        FLUTTER_DIR,
    )
    (output_dir / "flutter_analyze.log").write_text(
        analyze_output + "\n",
        encoding="utf-8",
    )

    generated_at = dt.datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")
    report_html = build_html(
        machine_report.visible_tests(),
        test_exit_code,
        analyze_exit_code,
        analyze_output,
        generated_at,
    )
    report_path = output_dir / "index.html"
    report_path.write_text(report_html, encoding="utf-8")

    print("Wrote HTML report to {}".format(report_path))

    if test_exit_code != 0 or analyze_exit_code != 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
