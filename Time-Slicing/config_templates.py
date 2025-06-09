def get_cluster_wide_config(replicas: int = 4):
    return {
        "apiVersion": "v1",
        "kind": "ConfigMap",
        "metadata": {"name": "time-slicing-config-all"},
        "data": {
            "any": f"""\
version: v1
flags:
  migStrategy: none
sharing:
  timeSlicing:
    resources:
    - name: nvidia.com/gpu
      replicas: {replicas}
"""
        },
    }

import yaml
from typing import Dict, List
from pydantic import BaseModel


class FineGrainedEntry(BaseModel):
    name: str
    replicas: int


class FineGrainedConfig(BaseModel):
    config_name: str
    data: Dict[str, List[FineGrainedEntry]]



def get_fine_grained_config(config_name: str, data: Dict[str, List[FineGrainedEntry]]) -> dict:
    configmap = {
        "apiVersion": "v1",
        "kind": "ConfigMap",
        "metadata": {
            "name": config_name
        },
        "data": {}
    }

    for device_type, entries in data.items():
        config_block = {
            "version": "v1",
            "flags": {
                "migStrategy": "mixed" if any("mig" in entry.name for entry in entries) else "none"
            },
            "sharing": {
                "timeSlicing": {
                    "resources": [
                        {
                            "name": entry.name,
                            "replicas": entry.replicas
                        } for entry in entries
                    ]
                }
            }
        }
        configmap["data"][device_type] = yaml.dump(config_block, sort_keys=False)

    return configmap