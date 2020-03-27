# Kubernetes One-Liners

Run MySQL Client:
`kubectl run -it --rm --image=mysql:5.6 --restart=Never mysql-client -- bash`

Run busybox with Curl:
`kubectl run -i --tty busybox-curl --image=odise/busybox-curl --restart=Never --rm -- sh`

Another Image with curl:
`kubectl run curl --image=appropriate/curl -i -t --restart= --rm --command -- sh`

Run busybox without Curl:
`kubectl run -i --tty busybox --image=busybox --restart=Never --rm -- sh`

Create template YAML:
`kubectl create deployment —image=busybox busybox —dry-run -o yaml`

To keep process running forever:  `sh -c "exec tail -f /dev/null"` or `sleep infinity`

Run on host to see traffic on port:  `sudo tcpdump -i eth0 -s 1500 port $PORT`

Get all pods on a node: `kgpo --all-namespaces --field-selector spec.nodeName=$NODE -o wide`

Delete all completed pods: `kubectl delete pod --field-selector=status.phase==Succeeded`
