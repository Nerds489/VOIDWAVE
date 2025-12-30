"""SQLMap SQL injection tool wrapper."""
import json
import re
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Any, ClassVar

from pydantic import BaseModel

from voidwave.plugins.base import Capability, PluginMetadata, PluginType
from voidwave.tools.base import BaseToolWrapper


class SqlmapConfig(BaseModel):
    """SQLMap-specific configuration."""

    level: int = 1  # 1-5, higher = more tests
    risk: int = 1  # 1-3, higher = more dangerous tests
    threads: int = 1
    timeout: int = 30
    retries: int = 3
    delay: float = 0
    tamper: list[str] = []  # Tamper scripts
    technique: str = "BEUSTQ"  # B=Boolean, E=Error, U=Union, S=Stacked, T=Time, Q=Inline
    batch: bool = True  # Non-interactive mode
    output_dir: str = ""


class SqlmapTool(BaseToolWrapper):
    """SQLMap SQL injection tool wrapper."""

    TOOL_BINARY: ClassVar[str] = "sqlmap"

    METADATA: ClassVar[PluginMetadata] = PluginMetadata(
        name="sqlmap",
        version="1.0.0",
        description="Automatic SQL injection and database takeover tool",
        author="VOIDWAVE",
        plugin_type=PluginType.SCANNER,
        capabilities=[
            Capability.SQL_INJECTION,
            Capability.EXPLOITATION,
            Capability.WEB_SCAN,
        ],
        requires_root=False,
        external_tools=["sqlmap"],
        config_schema=SqlmapConfig,
    )

    # SQL injection techniques
    TECHNIQUES = {
        "B": "Boolean-based blind",
        "E": "Error-based",
        "U": "Union query-based",
        "S": "Stacked queries",
        "T": "Time-based blind",
        "Q": "Inline queries",
    }

    # Database types
    DBMS_TYPES = [
        "mysql", "postgresql", "mssql", "oracle", "sqlite",
        "access", "firebird", "maxdb", "sybase", "db2",
        "hsqldb", "informix", "h2", "monetdb", "derby",
    ]

    def __init__(self, sqlmap_config: SqlmapConfig | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self.sqlmap_config = sqlmap_config or SqlmapConfig()
        self._temp_dir: TemporaryDirectory | None = None
        self._output_dir: Path | None = None

    def build_command(self, target: str, options: dict[str, Any]) -> list[str]:
        """Build sqlmap command."""
        cmd = []

        # Target URL
        if "=" in target or "?" in target:
            cmd.extend(["-u", target])
        else:
            cmd.extend(["-u", target])

        # Level and risk
        level = options.get("level", self.sqlmap_config.level)
        cmd.extend(["--level", str(level)])

        risk = options.get("risk", self.sqlmap_config.risk)
        cmd.extend(["--risk", str(risk)])

        # Threads
        threads = options.get("threads", self.sqlmap_config.threads)
        cmd.extend(["--threads", str(threads)])

        # Timeout
        timeout = options.get("timeout", self.sqlmap_config.timeout)
        cmd.extend(["--timeout", str(timeout)])

        # Retries
        retries = options.get("retries", self.sqlmap_config.retries)
        cmd.extend(["--retries", str(retries)])

        # Delay between requests
        delay = options.get("delay", self.sqlmap_config.delay)
        if delay > 0:
            cmd.extend(["--delay", str(delay)])

        # Technique filter
        technique = options.get("technique", self.sqlmap_config.technique)
        cmd.extend(["--technique", technique])

        # Tamper scripts
        tamper = options.get("tamper", self.sqlmap_config.tamper)
        if tamper:
            cmd.extend(["--tamper", ",".join(tamper)])

        # Specific parameter to test
        param = options.get("param")
        if param:
            cmd.extend(["-p", param])

        # POST data
        data = options.get("data")
        if data:
            cmd.extend(["--data", data])

        # Cookie
        cookie = options.get("cookie")
        if cookie:
            cmd.extend(["--cookie", cookie])

        # Headers
        headers = options.get("headers")
        if headers:
            for header in headers:
                cmd.extend(["-H", header])

        # Database type hint
        dbms = options.get("dbms")
        if dbms:
            cmd.extend(["--dbms", dbms])

        # Enumeration options
        if options.get("dbs"):
            cmd.append("--dbs")
        if options.get("tables"):
            cmd.append("--tables")
        if options.get("columns"):
            cmd.append("--columns")
        if options.get("dump"):
            cmd.append("--dump")
        if options.get("dump_all"):
            cmd.append("--dump-all")

        # Specific database/table
        if options.get("database"):
            cmd.extend(["-D", options["database"]])
        if options.get("table"):
            cmd.extend(["-T", options["table"]])
        if options.get("column"):
            cmd.extend(["-C", options["column"]])

        # OS shell
        if options.get("os_shell"):
            cmd.append("--os-shell")
        if options.get("os_cmd"):
            cmd.extend(["--os-cmd", options["os_cmd"]])

        # Batch mode (non-interactive)
        if options.get("batch", self.sqlmap_config.batch):
            cmd.append("--batch")

        # Output directory
        self._temp_dir = TemporaryDirectory()
        self._output_dir = Path(self._temp_dir.name)
        cmd.extend(["--output-dir", str(self._output_dir)])

        # Flush session
        if options.get("flush_session"):
            cmd.append("--flush-session")

        # Forms parsing
        if options.get("forms"):
            cmd.append("--forms")

        # Crawl depth
        crawl = options.get("crawl")
        if crawl:
            cmd.extend(["--crawl", str(crawl)])

        # Random agent
        if options.get("random_agent"):
            cmd.append("--random-agent")

        # Proxy
        proxy = options.get("proxy")
        if proxy:
            cmd.extend(["--proxy", proxy])

        return cmd

    def parse_output(self, output: str) -> dict[str, Any]:
        """Parse sqlmap output."""
        results = {
            "vulnerable": False,
            "injection_points": [],
            "databases": [],
            "tables": [],
            "columns": [],
            "data": [],
            "dbms": None,
            "os": None,
            "web_server": None,
        }

        # Parse injection points
        injection_pattern = re.compile(
            r"Parameter:\s+(\S+)\s+\(([^)]+)\)"
        )
        for match in injection_pattern.finditer(output):
            results["injection_points"].append({
                "parameter": match.group(1),
                "type": match.group(2),
            })
            results["vulnerable"] = True

        # Parse DBMS info
        dbms_match = re.search(r"back-end DBMS:\s+(.+)", output)
        if dbms_match:
            results["dbms"] = dbms_match.group(1).strip()

        # Parse OS info
        os_match = re.search(r"operating system:\s+(.+)", output)
        if os_match:
            results["os"] = os_match.group(1).strip()

        # Parse web server
        server_match = re.search(r"web server operating system:\s+(.+)", output)
        if server_match:
            results["web_server"] = server_match.group(1).strip()

        # Parse databases
        db_section = re.search(r"available databases.*?:\s*\n((?:\[\*\].+\n)+)", output)
        if db_section:
            for line in db_section.group(1).splitlines():
                db_match = re.search(r"\[\*\]\s+(.+)", line)
                if db_match:
                    results["databases"].append(db_match.group(1).strip())

        # Parse tables
        table_pattern = re.compile(r"\|\s+(\S+)\s+\|")
        in_table_section = False
        for line in output.splitlines():
            if "Table" in line and "entries" not in line.lower():
                in_table_section = True
            elif in_table_section:
                table_match = table_pattern.search(line)
                if table_match and table_match.group(1) not in ["+", "-"]:
                    results["tables"].append(table_match.group(1))
                elif line.strip() == "":
                    in_table_section = False

        # Parse dumped data
        if "dumped to" in output.lower() or "entries" in output.lower():
            # Look for CSV data in output dir
            if self._output_dir and self._output_dir.exists():
                for csv_file in self._output_dir.rglob("*.csv"):
                    try:
                        with open(csv_file) as f:
                            content = f.read()
                            results["data"].append({
                                "file": csv_file.name,
                                "content": content[:5000],  # Limit size
                            })
                    except Exception:
                        pass

        # Check for various success indicators
        success_indicators = [
            "injectable",
            "vulnerability",
            "exploitable",
            "confirmed",
        ]
        for indicator in success_indicators:
            if indicator in output.lower():
                results["vulnerable"] = True
                break

        # Summary
        results["summary"] = {
            "vulnerable": results["vulnerable"],
            "injection_points": len(results["injection_points"]),
            "databases_found": len(results["databases"]),
            "tables_found": len(results["tables"]),
        }

        return results

    async def cleanup(self) -> None:
        """Clean up resources."""
        await super().cleanup()
        if self._temp_dir:
            self._temp_dir.cleanup()
            self._temp_dir = None

    async def test_injection(self, url: str) -> dict[str, Any]:
        """Test URL for SQL injection."""
        result = await self.execute(url, {"batch": True})
        return result.data

    async def enumerate_databases(self, url: str) -> dict[str, Any]:
        """Enumerate databases after finding injection."""
        result = await self.execute(url, {"dbs": True, "batch": True})
        return result.data

    async def dump_table(
        self,
        url: str,
        database: str,
        table: str,
    ) -> dict[str, Any]:
        """Dump specific table contents."""
        result = await self.execute(url, {
            "database": database,
            "table": table,
            "dump": True,
            "batch": True,
        })
        return result.data
