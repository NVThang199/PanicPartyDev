"""Auto-updater for Graphify knowledge graph & multi-agent instructions.
Syncs CLAUDE.md -> AGENTS.md, GEMINI.md, .cursorrules, .windsurfrules, .clinerules, .github/copilot-instructions.md
Runs gd_graph_extractor.py and generate_full_graph.py when .gd files are modified.
Safe to call from Claude Code hooks (reads stdin JSON) or Git pre-commit hooks.
"""
import sys
import json
import subprocess
from pathlib import Path

RULE_TARGETS = [
    "AGENTS.md",
    "GEMINI.md",
    ".cursorrules",
    ".windsurfrules",
    ".clinerules",
    ".github/copilot-instructions.md",
]

def sync_rule_files(root_dir: Path) -> None:
    source = root_dir / "CLAUDE.md"
    if not source.exists():
        return
    content = source.read_text(encoding="utf-8")
    for target_rel in RULE_TARGETS:
        target = root_dir / target_rel
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists() or target.read_text(encoding="utf-8") != content:
            target.write_text(content, encoding="utf-8")

def rebuild_graph(root_dir: Path) -> int:
    py = sys.executable
    r1 = subprocess.run([py, str(root_dir / "gd_graph_extractor.py")], cwd=str(root_dir))
    if r1.returncode != 0:
        return r1.returncode
    r2 = subprocess.run([py, str(root_dir / "generate_full_graph.py")], cwd=str(root_dir))
    return r2.returncode

def main():
    root_dir = Path(__file__).resolve().parent

    # If invoked by Claude Code PostToolUse hook, inspect the edited file path
    if not sys.stdin.isatty():
        try:
            content = sys.stdin.read().strip()
            if content:
                data = json.loads(content)
                tool_input = data.get("tool_input", {})
                file_path = tool_input.get("file_path", "")
                if file_path:
                    norm = file_path.replace("\\", "/").lower()
                    if norm.endswith("claude.md"):
                        sync_rule_files(root_dir)
                        sys.exit(0)
                    elif not norm.endswith(".gd"):
                        sys.exit(0)
        except Exception:
            pass

    # Full execution (manual run, git pre-commit, or .gd file edit)
    sync_rule_files(root_dir)
    sys.exit(rebuild_graph(root_dir))

if __name__ == "__main__":
    main()
