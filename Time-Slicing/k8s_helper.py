import subprocess
import yaml
import tempfile


def apply_configmap(yaml_dict: dict, namespace="gpu-operator"):
    with tempfile.NamedTemporaryFile("w", delete=False, suffix=".yaml") as f:
        yaml.dump(yaml_dict, f)
        f.flush()
        print(f.name)
        subprocess.run(["kubectl", "apply", "-n", namespace, "-f", f.name], check=True)


def patch_cluster_policy(config_name: str, default=None, namespace="gpu-operator"):
    patch = {
        "spec": {
            "devicePlugin": {
                "config": {"name": config_name}
            }
        }
    }
    if default:
        patch["spec"]["devicePlugin"]["config"]["default"] = default

    subprocess.run([
        "kubectl", "patch", "clusterpolicies.nvidia.com/cluster-policy",
        "-n", namespace,
        "--type", "merge",
        "-p", yaml.dump(patch)
    ], check=True)


def label_node(node_name: str, label_key: str, label_value: str):
    subprocess.run(["kubectl", "label", "node", node_name, f"{label_key}={label_value}", "--overwrite"], check=True)
