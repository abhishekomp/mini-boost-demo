# Phase 4 — The Helm Chart

**No raw YAML files this time.**

We replace the four hand-written YAML files from Phase 3 with two Helm charts.
The charts produce the exact same Kubernetes objects — but from parameterised templates.

---

## The Question This Phase Answers

> Why did the real Boost manifest have a `"helm-chart"` block alongside the `"image"` block?
> What IS a Helm chart? What does `helm install` actually do?
> How is it different from `kubectl apply -f`?

---

## Prerequisites

Everything from Phase 3. Both images imported into k3s. Helm installed:

```bash
helm version
# version.BuildInfo{Version:"v3.x.x", ...}
```

---

## What Is in This Folder

```
phase4-helm-chart/
└── charts/
    ├── name-service/
    │   ├── Chart.yaml          ← identity card: chart name, version, description
    │   ├── values.yaml         ← default configuration values
    │   └── templates/
    │       ├── deployment.yaml ← Deployment template (compare to Phase 3's raw YAML)
    │       └── service.yaml    ← Service template
    │
    └── greeting-service/
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
            ├── deployment.yaml
            └── service.yaml
```

---

## Step 1 — Compare a Template to the Raw YAML

Open Phase 3's `k8s/name-service-deployment.yaml` and this phase's
`charts/name-service/templates/deployment.yaml` side by side.

They describe exactly the same Kubernetes object. The difference is:

| Phase 3 (raw YAML) | Phase 4 (Helm template) |
|---|---|
| `name: name-service` | `name: {{ .Release.Name }}` |
| `image: name-service:1.0.0` | `image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"` |
| `replicas: 1` | `replicas: {{ .Values.replicaCount }}` |

Every hardcoded value in Phase 3 is now a `{{ }}` expression filled from `values.yaml` or from
`--set` overrides at install time. That is the complete concept of a Helm chart.

Now open `charts/name-service/values.yaml`. These are the defaults that fill in the `{{ }}` expressions.

---

## Step 2 — See What Helm Would Generate (Without Deploying)

Before deploying, render the templates to see the real YAML Helm would produce:

```bash
cd /Users/kjss920/ideaProjects/mini-boost-demo/phase4-helm-chart

helm template name-service ./charts/name-service
```

You will see two YAML documents separated by `---`:
1. A `Deployment` — compare it to `../phase3-kubernetes-raw/k8s/name-service-deployment.yaml`
2. A `Service` — compare it to `../phase3-kubernetes-raw/k8s/name-service-service.yaml`

Look for these specific lines in the rendered output and find their equivalent in the Phase 3 YAML:

| In helm template output | In phase3 raw YAML | Where it came from |
|---|---|---|
| `name: name-service` | `name: name-service` | `.Release.Name` = the release name you pass to `helm install` |
| `image: "name-service:1.0.0"` | `image: name-service:1.0.0` | `values.yaml` image.repository + image.tag |
| `replicas: 1` | `replicas: 1` | `values.yaml` replicaCount |
| `containerPort: 8081` | `containerPort: 8081` | `values.yaml` container.port |

They are structurally identical. Helm just filled in the blanks from `values.yaml`.

This `helm template` command is one of your most useful debugging tools. You can always
see what Helm will actually apply before it touches the cluster.

---

## Step 3 — Deploy name-service with Helm

```bash
helm install name-service ./charts/name-service
```

Breaking down the command:
- `helm install` — install a new release
- `name-service` — the **release name** (the name of this particular installation)
- `./charts/name-service` — the path to the chart

Output:
```
NAME: name-service
LAST DEPLOYED: ...
NAMESPACE: default
STATUS: deployed
REVISION: 1
```

Check what appeared in the cluster:

```bash
kubectl get pods
kubectl get services
helm list
```

You will see the same Pod and Service as Phase 3, but now Helm is tracking them.

---

## Step 4 — Deploy greeting-service with Helm

```bash
helm install greeting-service ./charts/greeting-service
```

Wait for it to become ready:

```bash
kubectl get pods -w
```

Then test the full flow:

```bash
curl http://localhost:30080/api/greet
# { "message": "Hello, Alice!" }
```

---

## Step 5 — Override a Value at Install Time

One of the most powerful Helm features: override any value from `values.yaml` with `--set`.
This is exactly what `dev-tools` does when it reads the image digest from the manifest
and passes it to `helm install`.

Try deploying with a different replica count without touching any file:

```bash
helm upgrade name-service ./charts/name-service --set replicaCount=2
```

```bash
kubectl get pods
# Two name-service Pods now running
```

Scale back down:

```bash
helm upgrade name-service ./charts/name-service --set replicaCount=1
```

---

## Step 6 — Update the Image Version (Simulate a New Release)

In the real Boost platform, when a new version of `userpod` is released:
1. A new Docker image is built: `userpod:2.36.0` with a new digest
2. The manifest is updated with the new version and new digest
3. `dev-tools` runs `helm upgrade userpod ... --set image.tag=2.36.0 --set image.digest=sha256:newdigest`
4. Kubernetes performs a rolling update — new Pod starts before old one stops

Let's simulate this:

```bash
# Simulate upgrading to a hypothetical version 1.0.1
helm upgrade name-service ./charts/name-service \
  --set image.tag=1.0.0 \
  --set replicaCount=1
```

(We use 1.0.0 since that's the only image we have, but the mechanism is identical.)

Watch the rolling update:

```bash
kubectl get pods -w
```

With `replicas: 1`, the old Pod terminates and a new one starts. With `replicas: 2`, you would
see new Pods start before old ones terminate — zero-downtime deployment.

---

## Step 7 — Roll Back

Helm remembers every deployment as a numbered revision:

```bash
helm history name-service
```

```
REVISION  UPDATED                  STATUS     CHART                DESCRIPTION
1         Fri Jul 18 10:00:00      superseded name-service-1.0.0   Install complete
2         Fri Jul 18 10:05:00      superseded name-service-1.0.0   Upgrade complete
3         Fri Jul 18 10:10:00      deployed   name-service-1.0.0   Upgrade complete
```

Roll back to revision 1:

```bash
helm rollback name-service 1
kubectl get pods -w
```

This is how the team recovers from a bad deployment — one command, instant rollback.

---

## Step 8 — Clean Up

```bash
helm uninstall name-service
helm uninstall greeting-service

# Verify everything is gone
kubectl get all
helm list
```

`helm uninstall` removes every Kubernetes object the release created. No orphaned resources left behind.

---

## The Key Insight: Chart Version vs Image Version

Look at these two things:

```yaml
# Chart.yaml
version: 1.0.0       ← VERSION OF THE HELM CHART (the deployment recipe)
appVersion: "1.0.0"  ← version of the app (informational)

# values.yaml
image:
  tag: "1.0.0"       ← VERSION OF THE DOCKER IMAGE (what actually runs)
```

These can (and do) evolve independently:
- The chart version changes when the deployment recipe changes (new probe, new resource limit)
- The image tag/digest changes when the application code changes

This is why `boost-manifest.json` stores BOTH:
```json
"helm-chart": {
  "name": "boost/charts/userpod",
  "version": "2.35.1"       ← which deployment recipe to use
},
"image": {
  "tag": "2.35.1",
  "digest": "sha256:19e6..." ← which exact code to run
}
```

Both are pinned. Both must match what was tested. This is the heart of reproducible deployments.

---

## What You Should Take Away from Phase 4

1. A **Helm chart** = a directory of Kubernetes YAML templates + default values
2. `values.yaml` holds defaults; `--set key=value` overrides them at deploy time
3. `helm template` renders YAML without deploying — use it to debug templates
4. `helm install` deploys; `helm upgrade` updates; `helm rollback` reverts
5. `helm list` and `helm history` show what is deployed and its revision history
6. **Chart version** (the recipe) and **image version** (the code) are independent concepts
7. The real `boost-manifest.json` pins both, because both must match what was tested

---

## The Problem This Phase Leaves Unsolved

You now know how to deploy services with Helm. But you still have to decide manually:
- Which chart to use?
- Which version of the chart?
- Which image tag?
- Which image digest?
- Which `nameServiceUrl` value?

When the team releases version 9.0.4 of the whole platform, 40+ services all get new
versions at once. Someone needs to write down all those decisions in one place, and
`dev-tools` needs to read that and automate the Helm calls.

That file is the manifest. Move to Phase 5.

---

## Before Moving to Phase 5

Make sure you can answer these without looking:

- What are the three parts of a Helm chart folder?
- What is a Helm release? How is it different from a chart?
- What does `helm template` do and when would you use it?
- What is the difference between `helm install` and `helm upgrade`?
- Why does `boost-manifest.json` pin both a chart version AND an image digest?

👉 [Move to Phase 5: phase5-the-manifest/README.md](../phase5-the-manifest/README.md)

