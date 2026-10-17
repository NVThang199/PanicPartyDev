# gd_graph_extractor.py
import os
import re
import json
from pathlib import Path

def parse_gdscript(file_path: Path, proj_root: Path):
    rel_path = file_path.relative_to(proj_root).as_posix()
    file_id = rel_path.lower().replace("/", "_").replace(".", "_")

    content = file_path.read_text(encoding="utf-8")
    lines = content.splitlines()

    nodes = []
    edges = []

    # 1. File node
    nodes.append({
        "id": file_id,
        "label": file_path.name,
        "file_type": "code",
        "source_file": rel_path,
        "source_location": "L1"
    })

    extends_class = None
    class_name = None

    func_pattern = re.compile(r"^(?:@rpc\([^)]*\)\s+)?func\s+([a-zA-Z0-9_]+)\s*\((.*?)\)(?:\s*->\s*([a-zA-Z0-9_]+))?:")
    rpc_pattern = re.compile(r"^@rpc\((.*?)\)")
    var_pattern = re.compile(r"^(?:@onready\s+)?var\s+([a-zA-Z0-9_]+)(?:\s*:\s*([a-zA-Z0-9_]+))?")
    const_pattern = re.compile(r"^const\s+([a-zA-Z0-9_]+)")
    signal_pattern = re.compile(r"^signal\s+([a-zA-Z0-9_]+)")

    current_func_id = None

    for idx, line in enumerate(lines, 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        if stripped.startswith("class_name "):
            class_name = stripped.split()[1]
            c_id = f"{file_id}_{class_name.lower()}"
            nodes.append({
                "id": c_id,
                "label": f"class {class_name}",
                "file_type": "code",
                "source_file": rel_path,
                "source_location": f"L{idx}"
            })
            edges.append({
                "source": file_id,
                "target": c_id,
                "relation": "defines_class",
                "confidence": "EXTRACTED",
                "source_file": rel_path,
                "source_location": f"L{idx}",
                "weight": 1.0
            })
            continue

        if stripped.startswith("extends "):
            extends_class = stripped.split()[1]
            edges.append({
                "source": file_id,
                "target": extends_class.lower(),
                "relation": "extends",
                "confidence": "EXTRACTED",
                "source_file": rel_path,
                "source_location": f"L{idx}",
                "weight": 1.0
            })
            continue

        # Function
        m_func = func_pattern.match(stripped)
        if m_func:
            fn_name = m_func.group(1)
            current_func_id = f"{file_id}_{fn_name.lower()}"

            # Check previous line or line itself for @rpc
            is_rpc = "@rpc" in stripped or (idx > 1 and "@rpc" in lines[idx-2])
            fn_label = f"rpc func {fn_name}()" if is_rpc else f"func {fn_name}()"

            nodes.append({
                "id": current_func_id,
                "label": fn_label,
                "file_type": "code",
                "source_file": rel_path,
                "source_location": f"L{idx}"
            })
            edges.append({
                "source": file_id,
                "target": current_func_id,
                "relation": "contains",
                "confidence": "EXTRACTED",
                "source_file": rel_path,
                "source_location": f"L{idx}",
                "weight": 1.0
            })
            continue

        # Signal
        m_sig = signal_pattern.match(stripped)
        if m_sig:
            sig_name = m_sig.group(1)
            sig_id = f"{file_id}_sig_{sig_name.lower()}"
            nodes.append({
                "id": sig_id,
                "label": f"signal {sig_name}",
                "file_type": "code",
                "source_file": rel_path,
                "source_location": f"L{idx}"
            })
            edges.append({
                "source": file_id,
                "target": sig_id,
                "relation": "declares_signal",
                "confidence": "EXTRACTED",
                "source_file": rel_path,
                "source_location": f"L{idx}",
                "weight": 1.0
            })
            continue

        # Detect cross-script references / preload / load / calls in lines
        # e.g., preload("res://...")
        for match in re.finditer(r'preload\("res://([^"]+)"\)', stripped):
            target_res = match.group(1).lower().replace("/", "_").replace(".", "_")
            edges.append({
                "source": current_func_id or file_id,
                "target": target_res,
                "relation": "preloads",
                "confidence": "EXTRACTED",
                "source_file": rel_path,
                "source_location": f"L{idx}",
                "weight": 1.0
            })

        # e.g., RPC calls: foo.rpc(...) or foo.rpc_id(...)
        for match in re.finditer(r'([a-zA-Z0-9_]+)\.(?:rpc|rpc_id)\(', stripped):
            rpc_callee = match.group(1)
            edges.append({
                "source": current_func_id or file_id,
                "target": rpc_callee.lower(),
                "relation": "calls_rpc",
                "confidence": "EXTRACTED",
                "source_file": rel_path,
                "source_location": f"L{idx}",
                "weight": 1.0
            })

        # Global singletons: GameSession, Networking, Steam
        for singleton in ["GameSession", "Networking", "Steam"]:
            if singleton in stripped and not stripped.startswith(f"class_name {singleton}"):
                edges.append({
                    "source": current_func_id or file_id,
                    "target": singleton.lower(),
                    "relation": "uses_singleton",
                    "confidence": "EXTRACTED",
                    "source_file": rel_path,
                    "source_location": f"L{idx}",
                    "weight": 1.0
                })

    return nodes, edges

def main():
    proj_root = Path(r"C:\Users\nguye\Godot_v4.7.2-stable_win64.exe\git\PanicPartyDev")
    out_dir = proj_root / "graphify-out"
    out_dir.mkdir(parents=True, exist_ok=True)

    all_nodes = []
    all_edges = []
    seen_nodes = set()

    # Builtin singletons / classes as anchor nodes
    for s in ["gamesession", "networking", "steam", "characterbody3d", "node3d", "control", "node"]:
        all_nodes.append({
            "id": s,
            "label": s.capitalize(),
            "file_type": "code",
            "source_file": "core",
            "source_location": "L1"
        })
        seen_nodes.add(s)

    for gd_file in proj_root.rglob("*.gd"):
        # Skip addons if any
        if "addons" in gd_file.parts:
            continue
        nodes, edges = parse_gdscript(gd_file, proj_root)
        for n in nodes:
            if n["id"] not in seen_nodes:
                seen_nodes.add(n["id"])
                all_nodes.append(n)
        all_edges.extend(edges)

    # Also add scene files (.tscn)
    for tscn_file in proj_root.rglob("*.tscn"):
        rel_path = tscn_file.relative_to(proj_root).as_posix()
        tscn_id = rel_path.lower().replace("/", "_").replace(".", "_")
        if tscn_id not in seen_nodes:
            seen_nodes.add(tscn_id)
            all_nodes.append({
                "id": tscn_id,
                "label": tscn_file.name,
                "file_type": "scene",
                "source_file": rel_path,
                "source_location": "L1"
            })

    graph_data = {
        "nodes": all_nodes,
        "edges": all_edges,
        "hyperedges": [],
        "directed": True
    }

    raw_path = out_dir / "raw_extraction.json"
    raw_path.write_text(json.dumps(graph_data, indent=2), encoding="utf-8")
    print(f"Generated raw extraction: {len(all_nodes)} nodes, {len(all_edges)} edges -> {raw_path}")

if __name__ == "__main__":
    main()
