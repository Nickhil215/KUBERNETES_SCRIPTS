#!/bin/bash
NAMESPACE="kubeflow"

echo -e "Pod\tPVC\tMountPath\tSize\tUsed\tAvail\tUse%"
for pod in $(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
  # Get pod volumes and PVCs
  mounts=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{range .spec.volumes[*]}{.name}{"="}{.persistentVolumeClaim.claimName}{" "}{end}')
  for m in $mounts; do
    volumeName=$(echo $m | cut -d= -f1)
    pvcName=$(echo $m | cut -d= -f2)
    if [[ "$pvcName" != "" ]]; then
      mountPath=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath="{.spec.containers[0].volumeMounts[?(@.name=='$volumeName')].mountPath}")
      if [[ "$mountPath" != "" ]]; then
        usage=$(kubectl exec -n $NAMESPACE $pod -- df -h $mountPath 2>/dev/null | tail -1 | awk '{print $2"\t"$3"\t"$4"\t"$5}')
        echo -e "$pod\t$pvcName\t$mountPath\t$usage"
      fi
    fi
  done
done
