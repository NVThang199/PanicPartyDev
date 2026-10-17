# generate_full_graph.py
import json
import os
import sys
from pathlib import Path

# Add uv site-packages to sys.path so we can import networkx and graphify
uv_site_packages = Path(r"C:\Users\nguye\AppData\Roaming\uv\tools\graphifyy\Lib\site-packages")
if str(uv_site_packages) not in sys.path:
    sys.path.insert(0, str(uv_site_packages))

import networkx as nx
from graphify.build import build_from_json
from graphify.cluster import cluster, label_communities_by_hub, score_all
from graphify.export import to_json, to_html
from graphify.analyze import god_nodes, surprising_connections, suggest_questions
from graphify.report import generate

proj_root = Path(r"C:\Users\nguye\Godot_v4.7.2-stable_win64.exe\git\PanicPartyDev")
out_dir = proj_root / "graphify-out"
raw_path = out_dir / "raw_extraction.json"

if not raw_path.exists():
    print(f"Error: {raw_path} not found")
    sys.exit(1)

raw_data = json.loads(raw_path.read_text(encoding="utf-8"))

print(f"Loaded raw data: {len(raw_data['nodes'])} nodes, {len(raw_data['edges'])} edges")

# Build Graph (undirected for community clustering)
G = build_from_json(raw_data, directed=False, root=str(proj_root))

# Detect communities with Leiden/Louvain
communities = cluster(G)
community_labels = label_communities_by_hub(G, communities)
cohesion_scores = score_all(G, communities)
print(f"Detected {len(communities)} communities")

# Persist graph.json
graph_json_path = out_dir / "graph.json"
success = to_json(
    G,
    communities,
    str(graph_json_path),
    force=True,
    community_labels=community_labels
)
print(f"Saved graph.json: success={success}")

# Analysis metrics
god_node_list = god_nodes(G, top_n=10)
surprise_list = surprising_connections(G, communities=communities, top_n=10)
suggested_qs = suggest_questions(G, communities, community_labels, top_n=7)

detection_result = {
    "total_files": len(list(proj_root.rglob("*.gd"))) + len(list(proj_root.rglob("*.tscn"))),
    "total_words": 15000,
    "warning": None
}
token_cost = {"total_tokens": 0, "cost_usd": 0.0}

# Generate GRAPH_REPORT.md
try:
    report_content = generate(
        G=G,
        communities=communities,
        cohesion_scores=cohesion_scores,
        community_labels=community_labels,
        god_node_list=god_node_list,
        surprise_list=surprise_list,
        detection_result=detection_result,
        token_cost=token_cost,
        root=str(proj_root),
        suggested_questions=suggested_qs,
        obsidian=False
    )
    (out_dir / "GRAPH_REPORT.md").write_text(report_content, encoding="utf-8")
    print("Generated GRAPH_REPORT.md")
except Exception as e:
    print(f"Warning generate_report: {e}")

# Export graph.html
try:
    html_path = out_dir / "graph.html"
    to_html(G, communities, str(html_path), community_labels=community_labels)
    print("Generated graph.html")
except Exception as e:
    print(f"Warning export_html: {e}")

print("Graphify pipeline completed successfully!")
