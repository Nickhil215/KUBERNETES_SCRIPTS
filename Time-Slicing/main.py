from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Dict
from config_templates import get_cluster_wide_config, get_fine_grained_config, FineGrainedConfig, FineGrainedEntry
from k8s_helper import apply_configmap, patch_cluster_policy, label_node


app = FastAPI()


class ClusterWideConfig(BaseModel):
    replicas: int

@app.post("/timeslicing/clusterwide")
def configure_cluster_wide(cfg: ClusterWideConfig):
    try:
        configmap = get_cluster_wide_config(cfg.replicas)
        print(configmap)
        apply_configmap(configmap)
        patch_cluster_policy("time-slicing-config-all", default="any")
        return {"status": "success", "message": "Cluster-wide time slicing applied."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/timeslicing/finegrained")
def configure_fine_grained(cfg: FineGrainedConfig):
    try:
        configmap = get_fine_grained_config(cfg.config_name, cfg.data)

        print(configmap)
        apply_configmap(configmap)
        patch_cluster_policy(cfg.config_name)  # no default set
        return {"status": "success", "message": "Fine-grained time slicing applied."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/node/label")
def label_k8s_node(node_name: str, config_key: str, config_value: str):
    try:
        label_node(node_name, config_key, config_value)
        return {"status": "success", "message": f"Label applied to node {node_name}."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
