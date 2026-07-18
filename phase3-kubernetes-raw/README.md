# Phase 3 — Kubernetes: Raw YAML Deployment

**No Helm yet.**

We deploy both services to your local Kubernetes cluster using hand-written YAML files.
This is intentionally the "hard way" — so that when Helm solves it in Phase 4, you understand
exactly what it is solving.

---

## The Question This Phase Answers

> In Phase 2, two containers couldn't talk to each other. How does Kubernetes fix that?
> What is a Deployment? What is a Service? How does DNS work inside a cluster?

---

## Prerequisites

Make sure Colima is running with Kubernetes enabled:

```bash
colima start --kubernetes
kubectl get nodes
# Should show: colima   Ready   ...
```

Make sure both images were imported in Phase 2:
```bash
colima ssh -- sudo k3s ctr images list | grep -E "name-service|greeting-service"
```

If you see both images, you are ready. If not, go back and run the import commands in Phase 2 Step 8.

---

## What Is in This Folder

```
phase3-kubernetes-raw/
└── k8s/
    ├── name-service-deployment.yaml      ← Deployment for name-service
    ├── name-service-service.yaml         ← Service (DNS) for name-service
    ├── greeting-service-deployment.yaml  ← Deployment for greeting-service
    └── greeting-service-service.yaml     ← Service (DNS + NodePort) for greeting-service
```

**Read all four YAML files before running anything.** The comments in each file explain every
single field. The concepts in those comments are the real learning for this phase.

---

## Step 1 — Read the YAML Files

Open and read in this order:

1. `k8s/name-service-deployment.yaml` — pay attention to:
   - What `replicas` means
   - What `selector.matchLabels` and `template.metadata.labels` do together
   - What `imagePullPolicy: Never` means and why we need it
   - What `livenessProbe` and `readinessProbe` do

2. `k8s/name-service-service.yaml` — pay attention to:
   - The `name: name-service` in `metadata` — **this becomes the DNS hostname**
   - How `selector` links the Service to the Deployment's Pods
   - What `ClusterIP` means (internal only)

3. `k8s/greeting-service-deployment.yaml` — pay special attention to:
   ```yaml
   env:
     - name: NAME_SERVICE_URL
       value: "http://name-service:8081"
   ```
   This is the moment where Kubernetes fixes the Phase 2 networking problem.
   `name-service` in the URL is the DNS name of the Kubernetes Service above.

4. `k8s/greeting-service-service.yaml` — pay attention to:
   - What `NodePort` means (exposed outside the cluster)
   - What `nodePort: 30080` is (the port on your Mac you can use to reach this service)

---

## Step 2 — Deploy name-service

```bash
cd /Users/kjss920/ideaProjects/mini-boost-demo/phase3-kubernetes-raw

kubectl apply -f k8s/name-service-deployment.yaml
kubectl apply -f k8s/name-service-service.yaml
```

Watch the Pod appear:

```bash
kubectl get pods -w
```

```
NAME                            READY   STATUS              RESTARTS   AGE
name-service-7d9f8b6c4-xk2p9   0/1     ContainerCreating   0          3s
name-service-7d9f8b6c4-xk2p9   0/1     Running             0          8s
name-service-7d9f8b6c4-xk2p9   1/1     Running             0          23s
```

The transition from `0/1` to `1/1` means the readiness probe passed — the Pod is ready to
accept traffic.

Press `Ctrl+C` to stop watching.

---

## Step 3 — Inspect What Kubernetes Created

```bash
kubectl get all
```

You will see a Deployment, a ReplicaSet, a Pod, and a Service — all created from two YAML files.

```
NAME                                READY   STATUS    RESTARTS   AGE
pod/name-service-7d9f8b6c4-xk2p9   1/1     Running   0          1m

NAME                   TYPE        CLUSTER-IP      PORT(S)    AGE
service/name-service   ClusterIP   10.43.xxx.xxx   8081/TCP   1m

NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/name-service   1/1     1            1           1m

NAME                                      DESIRED   CURRENT   READY   AGE
replicaset.apps/name-service-7d9f8b6c4   1         1         1       1m
```

> **What is a ReplicaSet?**
> You wrote a `Deployment`. Kubernetes automatically created a `ReplicaSet` behind the scenes.
> The relationship is: **Deployment** manages **ReplicaSets**, which manage **Pods**.
> When you change the image in a Deployment, Kubernetes creates a NEW ReplicaSet (new Pods)
> while keeping the OLD ReplicaSet alive briefly — this is how rolling updates work with
> zero downtime. You almost never interact with ReplicaSets directly; the Deployment handles them.

Notice the `CLUSTER-IP` — this is a virtual IP assigned to the Service. But **you never use
this IP directly**. You always use the Service name (`name-service`) which Kubernetes DNS
resolves automatically.

Now use `kubectl describe` to see the full details of the Pod:

```bash
# Get the pod name first
kubectl get pods

# Then describe it (replace the pod name with your actual pod name)
kubectl describe pod name-service-7d9f8b6c4-xk2p9
```

Look for these sections in the output:
- `Node:` — which node the Pod is running on (your Colima VM)
- `IP:` — the Pod's internal IP (changes on restart — this is why Services exist)
- `Containers:` → `Image:` — confirms which image is running
- `Events:` — the sequence: Scheduled → Pulling → Pulled → Created → Started

The `Events` section is the most useful for debugging. If a Pod is stuck in
`ContainerCreating`, the Events section will tell you why.

---

## Step 4 — Deploy greeting-service

```bash
kubectl apply -f k8s/greeting-service-deployment.yaml
kubectl apply -f k8s/greeting-service-service.yaml
```

Watch it become ready:

```bash
kubectl get pods -w
```

---

## Step 5 — The Moment of Truth: DNS Discovery

Call `greeting-service` from your Mac. It is exposed via NodePort on port 30080:

```bash
curl http://localhost:30080/api/greet
```

Expected:
```json
{ "message": "Hello, Alice!" }
```

**This is the critical moment.** `greeting-service` (inside a Pod) called `name-service`
using the URL `http://name-service:8081/api/name`. Kubernetes DNS resolved `name-service`
to the ClusterIP of the Service, which then routed the request to the `name-service` Pod.

```
curl from your Mac
      │
      │ HTTP → localhost:30080 (NodePort on Colima VM)
      ▼
greeting-service Pod (Kubernetes routes to it)
      │
      │ HTTP → http://name-service:8081/api/name
      │        ↑
      │        Kubernetes DNS resolves "name-service" to 10.43.xxx.xxx (ClusterIP)
      ▼
name-service Pod
      │
      └── returns { "name": "Alice" }
```

Call it several times — the name changes each time because `name-service` picks randomly.

---

## Step 6 — Observe the Key Difference from Phase 2

In Phase 2, the `greeting-service` container could not reach `name-service` because `localhost`
inside a container means the container itself.

### What "localhost" means depends on where you are

This is one of the most confusing things for people new to containers and Kubernetes.
Here is a clear map:

```
Context                         What "localhost" means
──────────────────────────────────────────────────────────────────
Your Mac terminal                Your Mac (192.168.x.x or 127.0.0.1)

Inside a Docker container        That specific container — NOT your Mac,
                                 NOT other containers

Inside a Kubernetes Pod          That specific Pod — NOT other Pods,
                                 NOT other services

Kubernetes Service DNS           "name-service" resolves to the
(inside any Pod)                 Service's ClusterIP → routes to the Pod
```

This is exactly why:
- Phase 1 worked: both services ran on your Mac, both used `localhost`
- Phase 2 broke: `greeting-service` container tried `localhost:8081` and found nothing
  (its own container has nothing on port 8081)
- Phase 3 works: `greeting-service` uses `http://name-service:8081` — the Kubernetes Service
  DNS name — which resolves correctly from any Pod in the cluster

In Phase 3, it works because:
1. We set the env var `NAME_SERVICE_URL=http://name-service:8081` in the Deployment
2. The name `name-service` is the name of a Kubernetes Service object
3. Kubernetes has a built-in DNS server — every Service name resolves to a ClusterIP
4. No IP addresses are hardcoded anywhere — if the Pod is rescheduled and gets a new IP,
   the Service absorbs the change transparently

This is **service discovery** — services find each other by name, not by IP.

---

## Step 7 — See the Logs

```bash
# Logs from name-service
kubectl logs -l app=name-service

# Logs from greeting-service
kubectl logs -l app=greeting-service

# Follow logs in real time (Ctrl+C to stop)
kubectl logs -l app=greeting-service --follow
```

While following greeting-service logs, call the endpoint from another terminal.
You will see the HTTP request logged in real time.

---

## Step 8 — See What Happens When a Pod Crashes

Delete the name-service Pod manually (simulating a crash):

```bash
kubectl delete pod -l app=name-service
```

Watch what happens immediately:

```bash
kubectl get pods -w
```

```
name-service-7d9f8b6c4-xk2p9   1/1   Terminating   0   5m
name-service-7d9f8b6c4-ab3mn   0/1   Pending       0   1s    ← NEW Pod created automatically
name-service-7d9f8b6c4-ab3mn   0/1   Running       0   3s
name-service-7d9f8b6c4-ab3mn   1/1   Running       0   18s
```

The Deployment controller detected that the actual state (0 replicas) did not match the
desired state (1 replica) and immediately started a replacement Pod. This is Kubernetes's
**self-healing** behaviour.

During those few seconds, `greeting-service` would return errors. In production, you would
run multiple replicas (`replicas: 2`) so there is always at least one Pod serving traffic.

---

## Step 9 — Clean Up

```bash
kubectl delete -f k8s/
```

This deletes all four resources (both Deployments and both Services) in one command.

---

## What You Should Take Away from Phase 3

1. A **Deployment** manages Pod replicas — it restarts Pods on crash and handles rolling updates
2. A **Service** gives a Pod a stable DNS name and IP — other Pods use the name, not the IP
3. **Environment variables** in the Deployment override Spring Boot's `application.yml` —
   same code, different config per environment
4. `kubectl apply -f` is declarative — describe the desired state; Kubernetes makes it real
5. `kubectl logs`, `kubectl describe pod`, `kubectl get pods -w` are your debugging tools
6. Kubernetes **self-heals** — deleted/crashed Pods are automatically replaced

---

## The Problem This Phase Leaves Unsolved

Look at the four YAML files you just applied. They contain 130+ lines in total.
For two tiny services.

The real Boost platform has 40+ services. If every service needed four YAML files with
100+ lines each, maintaining them would be a full-time job. Worse:

- Changing the image version means manually finding and updating the image name in the YAML
- Deploying the same service to dev vs production means duplicating the YAML and changing
  a handful of values
- If you need to change a pattern (e.g. add a readiness probe to all services), you need
  to edit 40 files

There is a better way: write the YAML as a **template** once, and fill in the variables
at deploy time. That is what a **Helm chart** is. Move to Phase 4.

---

## Before Moving to Phase 4

Make sure you can answer these without looking:

- What is the difference between a Deployment and a Pod?
- What does a Kubernetes Service do? What problem does it solve?
- What does `type: ClusterIP` mean? What about `type: NodePort`?
- How does `greeting-service` know how to reach `name-service`?
- What happens when a Pod crashes with `replicas: 1` in the Deployment?
- Why is `imagePullPolicy: Never` needed for our locally imported images?

👉 [Move to Phase 4: phase4-helm-chart/README.md](../phase4-helm-chart/README.md)

