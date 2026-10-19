#!/usr/bin/env bash
source "$CKAD_HOME/lib/common.sh"
P="pod musca-pair -n musca"
TIME='[0-9][0-9]:[0-9][0-9]:[0-9][0-9]'   # a `date` line contains hh:mm:ss

check "volume shared is an emptyDir" has "$(jp $P -o jsonpath='{.spec.volumes[?(@.name=="shared")].emptyDir}')" "{"

mounts_shared() { # CONTAINER
  is "$(jp $P -o jsonpath="{.spec.containers[?(@.name==\"$1\")].image}")" "busybox:1.37" &&
    is "$(jp $P -o jsonpath="{.spec.containers[?(@.name==\"$1\")].volumeMounts[?(@.name==\"shared\")].mountPath}")" "/shared"
}
check "container producer (busybox:1.37) mounts shared at /shared" mounts_shared producer
check "container consumer (busybox:1.37) mounts shared at /shared" mounts_shared consumer
check "both containers are running and ready" is "$(jp $P -o jsonpath='{.status.containerStatuses[*].ready}')" "true true"

live() { kubectl logs -n musca musca-pair -c consumer --tail=20 2>/dev/null | grep -q "$TIME"; }
check "consumer's logs show the producer's date lines" live
check "consumer.log holds the consumer's logs" grep -q "$TIME" "$COURSE/36/consumer.log"
check "shared-ls lists out.log" file_has "$COURSE/36/shared-ls" "out.log"

finish
