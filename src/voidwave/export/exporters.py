"""Export format implementations."""

import csv
import json
from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any


@dataclass
class ExportResult:
    """Result of an export operation."""
    path: Path
    format: str
    size: int
    success: bool
    error: str | None = None


class Exporter(ABC):
    """Base class for exporters."""

    @property
    @abstractmethod
    def format_name(self) -> str:
        """Return the format name."""
        pass

    @abstractmethod
    async def export(self, data: Any, path: Path) -> ExportResult:
        """Export data to the specified path."""
        pass


class JsonExporter(Exporter):
    """Export to JSON format."""

    @property
    def format_name(self) -> str:
        return "json"

    async def export(self, data: Any, path: Path) -> ExportResult:
        path.parent.mkdir(parents=True, exist_ok=True)

        try:
            content = json.dumps(data, indent=2, default=str, ensure_ascii=False)
            path.write_text(content, encoding="utf-8")
            return ExportResult(
                path=path,
                format=self.format_name,
                size=path.stat().st_size,
                success=True
            )
        except Exception as e:
            return ExportResult(
                path=path,
                format=self.format_name,
                size=0,
                success=False,
                error=str(e)
            )


class CsvExporter(Exporter):
    """Export to CSV format."""

    @property
    def format_name(self) -> str:
        return "csv"

    async def export(self, data: list[dict], path: Path) -> ExportResult:
        path.parent.mkdir(parents=True, exist_ok=True)

        try:
            with path.open("w", newline="", encoding="utf-8") as f:
                if data and isinstance(data, list) and len(data) > 0:
                    # Flatten nested data for CSV
                    flat_data = [self._flatten(item) for item in data]
                    fieldnames = set()
                    for item in flat_data:
                        fieldnames.update(item.keys())

                    writer = csv.DictWriter(f, fieldnames=sorted(fieldnames))
                    writer.writeheader()
                    writer.writerows(flat_data)

            return ExportResult(
                path=path,
                format=self.format_name,
                size=path.stat().st_size,
                success=True
            )
        except Exception as e:
            return ExportResult(
                path=path,
                format=self.format_name,
                size=0,
                success=False,
                error=str(e)
            )

    def _flatten(self, d: dict, parent_key: str = "", sep: str = "_") -> dict:
        """Flatten nested dict for CSV export."""
        items: list[tuple[str, Any]] = []
        for k, v in d.items():
            new_key = f"{parent_key}{sep}{k}" if parent_key else k
            if isinstance(v, dict):
                items.extend(self._flatten(v, new_key, sep).items())
            elif isinstance(v, list):
                items.append((new_key, json.dumps(v)))
            else:
                items.append((new_key, v))
        return dict(items)


class HtmlExporter(Exporter):
    """Export to HTML report."""

    DEFAULT_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VOIDWAVE Session Report</title>
    <style>
        :root {{
            --bg-primary: #0a0a0a;
            --bg-secondary: #1a1a1a;
            --text-primary: #00ff00;
            --text-secondary: #00ffff;
            --accent: #ff00ff;
            --critical: #ff0000;
            --high: #ff6600;
            --medium: #ffff00;
            --low: #00ff00;
            --info: #00ffff;
        }}
        * {{ box-sizing: border-box; }}
        body {{
            font-family: 'Courier New', 'Fira Code', monospace;
            background: var(--bg-primary);
            color: var(--text-primary);
            margin: 0;
            padding: 20px;
            line-height: 1.6;
        }}
        .container {{
            max-width: 1200px;
            margin: 0 auto;
        }}
        h1 {{
            color: var(--accent);
            border-bottom: 2px solid var(--accent);
            padding-bottom: 10px;
            text-transform: uppercase;
            letter-spacing: 2px;
        }}
        h2 {{
            color: var(--text-secondary);
            border-left: 4px solid var(--text-secondary);
            padding-left: 10px;
            margin-top: 30px;
        }}
        .section {{
            background: var(--bg-secondary);
            padding: 20px;
            margin: 15px 0;
            border-left: 3px solid var(--text-primary);
            border-radius: 0 5px 5px 0;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            margin: 10px 0;
        }}
        th, td {{
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid #333;
        }}
        th {{
            background: #2a2a2a;
            color: var(--accent);
            text-transform: uppercase;
            font-size: 0.9em;
            letter-spacing: 1px;
        }}
        tr:hover {{
            background: rgba(0, 255, 0, 0.05);
        }}
        .severity-critical {{ color: var(--critical); font-weight: bold; }}
        .severity-high {{ color: var(--high); }}
        .severity-medium {{ color: var(--medium); }}
        .severity-low {{ color: var(--low); }}
        .severity-info {{ color: var(--info); }}
        .badge {{
            display: inline-block;
            padding: 3px 8px;
            border-radius: 3px;
            font-size: 0.8em;
            text-transform: uppercase;
        }}
        .badge-success {{ background: rgba(0, 255, 0, 0.2); color: var(--low); }}
        .badge-warning {{ background: rgba(255, 255, 0, 0.2); color: var(--medium); }}
        .badge-error {{ background: rgba(255, 0, 0, 0.2); color: var(--critical); }}
        .stat-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin: 20px 0;
        }}
        .stat-card {{
            background: var(--bg-secondary);
            padding: 20px;
            text-align: center;
            border: 1px solid #333;
        }}
        .stat-value {{
            font-size: 2.5em;
            color: var(--accent);
            font-weight: bold;
        }}
        .stat-label {{
            color: #888;
            text-transform: uppercase;
            font-size: 0.8em;
        }}
        .timeline {{
            position: relative;
            padding-left: 30px;
        }}
        .timeline::before {{
            content: '';
            position: absolute;
            left: 10px;
            top: 0;
            bottom: 0;
            width: 2px;
            background: var(--text-secondary);
        }}
        .timeline-item {{
            position: relative;
            margin-bottom: 15px;
            padding: 10px 15px;
            background: var(--bg-secondary);
        }}
        .timeline-item::before {{
            content: '';
            position: absolute;
            left: -24px;
            top: 15px;
            width: 10px;
            height: 10px;
            background: var(--text-primary);
            border-radius: 50%;
        }}
        .timeline-time {{
            color: #888;
            font-size: 0.9em;
        }}
        footer {{
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #333;
            text-align: center;
            color: #666;
        }}
        .logo {{
            font-size: 0.8em;
            letter-spacing: 3px;
            color: var(--accent);
        }}
        code {{
            background: #2a2a2a;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: inherit;
        }}
        pre {{
            background: #2a2a2a;
            padding: 15px;
            overflow-x: auto;
            border-radius: 5px;
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>VOIDWAVE Session Report</h1>

        <div class="stat-grid">
            <div class="stat-card">
                <div class="stat-value">{targets_count}</div>
                <div class="stat-label">Targets</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">{findings_count}</div>
                <div class="stat-label">Findings</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">{tools_count}</div>
                <div class="stat-label">Tools Run</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">{duration}</div>
                <div class="stat-label">Duration</div>
            </div>
        </div>

        <div class="section">
            <h2>Session Information</h2>
            <table>
                <tr><th>Session ID</th><td>{session_id}</td></tr>
                <tr><th>Name</th><td>{session_name}</td></tr>
                <tr><th>Started</th><td>{created_at}</td></tr>
                <tr><th>Status</th><td><span class="badge badge-{status_class}">{status}</span></td></tr>
            </table>
        </div>

        <div class="section">
            <h2>Targets ({targets_count})</h2>
            {targets_table}
        </div>

        <div class="section">
            <h2>Findings ({findings_count})</h2>
            {findings_content}
        </div>

        <div class="section">
            <h2>Tool Executions</h2>
            {tools_table}
        </div>

        <div class="section">
            <h2>Activity Timeline</h2>
            <div class="timeline">
                {timeline_content}
            </div>
        </div>

        <footer>
            <div class="logo">VOIDWAVE</div>
            <p>Generated: {generated_at} | Version {version}</p>
        </footer>
    </div>
</body>
</html>"""

    def __init__(self, template_path: Path | None = None):
        self.template_path = template_path

    @property
    def format_name(self) -> str:
        return "html"

    async def export(self, data: dict, path: Path) -> ExportResult:
        path.parent.mkdir(parents=True, exist_ok=True)

        try:
            # Load custom template if provided
            if self.template_path and self.template_path.exists():
                template = self.template_path.read_text()
            else:
                template = self.DEFAULT_TEMPLATE

            # Prepare template variables
            context = self._prepare_context(data)

            # Render template
            content = template.format(**context)
            path.write_text(content, encoding="utf-8")

            return ExportResult(
                path=path,
                format=self.format_name,
                size=path.stat().st_size,
                success=True
            )
        except Exception as e:
            return ExportResult(
                path=path,
                format=self.format_name,
                size=0,
                success=False,
                error=str(e)
            )

    def _prepare_context(self, data: dict) -> dict:
        """Prepare context variables for template."""
        from voidwave import __version__

        session = data.get("session", {})
        targets = data.get("targets", [])
        loot = data.get("loot", [])
        tool_runs = data.get("tool_executions", [])
        audit = data.get("audit_log", [])

        # Build targets table
        targets_table = self._build_table(
            targets,
            ["Type", "Value", "Status"],
            ["type", "value", "status"]
        )

        # Build findings content
        findings_content = self._build_findings(loot)

        # Build tools table
        tools_table = self._build_table(
            tool_runs,
            ["Tool", "Exit Code", "Duration"],
            ["tool_name", "exit_code", "duration"]
        )

        # Build timeline
        timeline_content = self._build_timeline(audit)

        # Determine status class
        status = session.get("state", "unknown")
        status_class = "success" if status == "completed" else "warning"

        return {
            "session_id": session.get("id", "N/A"),
            "session_name": session.get("name", "Unnamed Session"),
            "created_at": session.get("created_at", "N/A"),
            "status": status,
            "status_class": status_class,
            "targets_count": len(targets),
            "findings_count": len(loot),
            "tools_count": len(tool_runs),
            "duration": self._calculate_duration(session),
            "targets_table": targets_table,
            "findings_content": findings_content,
            "tools_table": tools_table,
            "timeline_content": timeline_content,
            "generated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "version": __version__,
        }

    def _build_table(self, data: list, headers: list, keys: list) -> str:
        """Build an HTML table from data."""
        if not data:
            return "<p>No data available.</p>"

        rows = []
        for item in data:
            cells = []
            for key in keys:
                value = item.get(key, "N/A") if isinstance(item, dict) else "N/A"
                cells.append(f"<td>{value}</td>")
            rows.append(f"<tr>{''.join(cells)}</tr>")

        header_cells = "".join(f"<th>{h}</th>" for h in headers)
        return f"""<table>
            <tr>{header_cells}</tr>
            {''.join(rows)}
        </table>"""

    def _build_findings(self, loot: list) -> str:
        """Build findings section HTML."""
        if not loot:
            return "<p>No findings recorded.</p>"

        items = []
        for item in loot:
            loot_type = item.get("type", "unknown")
            target = item.get("target", "N/A")
            severity = item.get("severity", "info")
            items.append(
                f'<div class="severity-{severity}">'
                f'<strong>{loot_type}</strong>: {target}</div>'
            )

        return "\n".join(items)

    def _build_timeline(self, audit: list) -> str:
        """Build activity timeline HTML."""
        if not audit:
            return "<p>No activity logged.</p>"

        items = []
        for entry in audit[-20:]:  # Last 20 entries
            timestamp = entry.get("timestamp", "")
            action = entry.get("action", "")
            details = entry.get("details", "")
            items.append(
                f'<div class="timeline-item">'
                f'<div class="timeline-time">{timestamp}</div>'
                f'<strong>{action}</strong>: {details}'
                f'</div>'
            )

        return "\n".join(items)

    def _calculate_duration(self, session: dict) -> str:
        """Calculate session duration."""
        try:
            start = session.get("created_at", "")
            end = session.get("completed_at", "")
            if start and end:
                # Parse and calculate
                return "N/A"
        except Exception:
            pass
        return "N/A"


class PdfExporter(Exporter):
    """Export to PDF format (via HTML)."""

    @property
    def format_name(self) -> str:
        return "pdf"

    async def export(self, data: dict, path: Path) -> ExportResult:
        path.parent.mkdir(parents=True, exist_ok=True)

        # First generate HTML
        html_path = path.with_suffix(".html")
        html_exporter = HtmlExporter()
        html_result = await html_exporter.export(data, html_path)

        if not html_result.success:
            return ExportResult(
                path=path,
                format=self.format_name,
                size=0,
                success=False,
                error=f"HTML generation failed: {html_result.error}"
            )

        # Try weasyprint first, then wkhtmltopdf
        try:
            from weasyprint import HTML
            HTML(str(html_path)).write_pdf(str(path))
            html_path.unlink()  # Remove temp HTML
            return ExportResult(
                path=path,
                format=self.format_name,
                size=path.stat().st_size,
                success=True
            )
        except ImportError:
            pass

        # Try wkhtmltopdf
        import shutil
        import asyncio

        if shutil.which("wkhtmltopdf"):
            try:
                proc = await asyncio.create_subprocess_exec(
                    "wkhtmltopdf", "--quiet", str(html_path), str(path),
                    stdout=asyncio.subprocess.DEVNULL,
                    stderr=asyncio.subprocess.DEVNULL,
                )
                await proc.wait()

                if proc.returncode == 0:
                    html_path.unlink()
                    return ExportResult(
                        path=path,
                        format=self.format_name,
                        size=path.stat().st_size,
                        success=True
                    )
            except Exception as e:
                return ExportResult(
                    path=path,
                    format=self.format_name,
                    size=0,
                    success=False,
                    error=str(e)
                )

        # If no PDF converter available, keep HTML
        return ExportResult(
            path=html_path,
            format="html",
            size=html_path.stat().st_size,
            success=True,
            error="PDF converter not available, HTML generated instead"
        )


class MarkdownExporter(Exporter):
    """Export to Markdown format."""

    @property
    def format_name(self) -> str:
        return "md"

    async def export(self, data: dict, path: Path) -> ExportResult:
        path.parent.mkdir(parents=True, exist_ok=True)

        try:
            content = self._generate_markdown(data)
            path.write_text(content, encoding="utf-8")

            return ExportResult(
                path=path,
                format=self.format_name,
                size=path.stat().st_size,
                success=True
            )
        except Exception as e:
            return ExportResult(
                path=path,
                format=self.format_name,
                size=0,
                success=False,
                error=str(e)
            )

    def _generate_markdown(self, data: dict) -> str:
        """Generate Markdown report content."""
        from voidwave import __version__

        session = data.get("session", {})
        targets = data.get("targets", [])
        loot = data.get("loot", [])
        tool_runs = data.get("tool_executions", [])
        audit = data.get("audit_log", [])

        lines = [
            "# VOIDWAVE Session Report",
            "",
            "## Session Information",
            "",
            f"| Field | Value |",
            f"|-------|-------|",
            f"| Session ID | {session.get('id', 'N/A')} |",
            f"| Name | {session.get('name', 'Unnamed')} |",
            f"| Started | {session.get('created_at', 'N/A')} |",
            f"| Status | {session.get('state', 'unknown')} |",
            "",
            f"## Targets ({len(targets)})",
            "",
        ]

        if targets:
            lines.extend([
                "| Type | Value | Status |",
                "|------|-------|--------|",
            ])
            for t in targets:
                lines.append(
                    f"| {t.get('type', 'N/A')} | {t.get('value', 'N/A')} | {t.get('status', 'N/A')} |"
                )
        else:
            lines.append("No targets recorded.")

        lines.extend([
            "",
            f"## Findings ({len(loot)})",
            "",
        ])

        if loot:
            for item in loot:
                lines.append(f"- **{item.get('type', 'unknown')}**: {item.get('target', 'N/A')}")
        else:
            lines.append("No findings recorded.")

        lines.extend([
            "",
            "## Tool Executions",
            "",
        ])

        if tool_runs:
            lines.extend([
                "| Tool | Exit Code | Duration |",
                "|------|-----------|----------|",
            ])
            for run in tool_runs:
                lines.append(
                    f"| {run.get('tool_name', 'N/A')} | {run.get('exit_code', 'N/A')} | {run.get('duration', 'N/A')}s |"
                )
        else:
            lines.append("No tool executions recorded.")

        lines.extend([
            "",
            "## Activity Log",
            "",
        ])

        if audit:
            for entry in audit[-20:]:
                lines.append(
                    f"- `{entry.get('timestamp', '')}` **{entry.get('action', '')}**: {entry.get('details', '')}"
                )
        else:
            lines.append("No activity logged.")

        lines.extend([
            "",
            "---",
            "",
            f"*Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} | VOIDWAVE v{__version__}*",
        ])

        return "\n".join(lines)
