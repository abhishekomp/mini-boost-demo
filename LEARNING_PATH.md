# Learning Path: From Spring Boot to Kubernetes via Helm and a Manifest

## Start Here

👉 If you have not read [WHAT_THIS_IS.md](./WHAT_THIS_IS.md) yet, read it first. It explains
what this project is, why it exists, and how it connects to the real Boost platform.

---

## The Goal

By the end of this learning path you will be able to answer — from memory, without looking —
exactly what happens when a developer runs:

```bash
dev-tools deploy manifest -m 9.0.4 -i userpod,messagingpod,studypod
```

You will have built a working miniature of that entire flow yourself.

---

## The Core Idea in One Picture

```
  Developer                 CI/CD Pipeline              You (developer)
  writes code               builds & ships              deploys locally
      │                          │                           │
  Spring Boot   ──(mvn)──►  Docker Image  ──(push)──►  Manifest JSON
  application               with digest                 + deploy.sh
                            sha256:abc123               reads manifest
                                                        calls helm install
                                                             │
                                                             ▼
                                                        Kubernetes cluster
                                                        (Colima on your Mac)
                                                             │
                                                             ▼
                                                        Running Pod
```

Each phase of this learning path builds one segment of this picture.

---

## The Five Phases

> **Total estimated time: 3–4 hours** spread across one or two sessions.
> Each phase builds directly on the last — do not skip.

```
Phase 1 ──► Phase 2 ──► Phase 3 ──► Phase 4 ──► Phase 5
   │             │            │            │            │
Two Spring   Dockerfile   Kubernetes   Helm Chart   Manifest +
Boot apps    + Docker     raw YAML     (replaces    deploy.sh
talking to   image        deploy       raw YAML)    (mini
each other   (+ digest)               cleanly)     dev-tools)
```

---

### Phase 1 — The Two Services
**Folder:** `phase1-the-services/` | **Time:** 30 min | **Needs:** Java, Maven only

Two Spring Boot apps that talk to each other over HTTP.
`greeting-service` calls `name-service`. Everything runs on your Mac with `mvn spring-boot:run`.

**One new concept:** microservices communicating over HTTP — service A calls service B by URL.

**You will NOT need:** Docker, Kubernetes, Helm, or anything else.

👉 [Start here: phase1-the-services/README.md](./phase1-the-services/README.md)

---

### Phase 2 — The Dockerfile
**Folder:** `phase2-dockerfile/` | **Time:** 45 min | **Needs:** Colima running

Add a `Dockerfile` to each service. Build Docker images. Run them as containers.
Understand image layers and the SHA256 digest. See why the digest matters for reproducibility.

**One new concept:** A Dockerfile turns a Spring Boot JAR into a portable Docker image.
The SHA256 digest is the image's immutable fingerprint — the real version pin.

**You will NOT need:** Kubernetes or Helm.

👉 [Start here: phase2-dockerfile/README.md](./phase2-dockerfile/README.md)

---

### Phase 3 — Kubernetes Raw YAML
**Folder:** `phase3-kubernetes-raw/` | **Time:** 45 min | **Needs:** Colima with `--kubernetes`

Deploy both services to your local Kubernetes cluster using raw YAML files.
Write a `Deployment` and a `Service` for each. Apply them with `kubectl apply`.
Watch `greeting-service` find `name-service` by DNS name — not by IP address.

**One new concept:** Kubernetes manages containers declaratively. A `Service` gives a Pod
a stable DNS name so other Pods can find it without knowing its IP.

**You will NOT need:** Helm.

👉 [Start here: phase3-kubernetes-raw/README.md](./phase3-kubernetes-raw/README.md)

---

### Phase 4 — The Helm Chart
**Folder:** `phase4-helm-chart/` | **Time:** 60 min | **Needs:** Helm installed

Replace the raw YAML files with a proper Helm chart for each service.
See how templates and `values.yaml` replace hardcoded values.
Use `helm install`, `helm upgrade`, `helm rollback`, `helm template`.

**One new concept:** A Helm chart is a parameterised template for Kubernetes YAML.
One chart can deploy the same service with different settings in different environments.

👉 [Start here: phase4-helm-chart/README.md](./phase4-helm-chart/README.md)

---

### Phase 5 — The Manifest and the Deploy Script
**Folder:** `phase5-the-manifest/` | **Time:** 45 min | **Needs:** Everything from Phases 1–4

Write a `demo-manifest.json` that mirrors the structure of `boost-manifest.json`.
Write a `deploy.sh` script (30 lines) that reads the manifest and calls `helm install`.
Run `./deploy.sh` — and watch both services deploy from a single command.

**One new concept:** The manifest is a version registry — a JSON file that says
"for this release, use this exact chart version and this exact image digest."
The deploy script is what `dev-tools` does, demystified.

👉 [Start here: phase5-the-manifest/README.md](./phase5-the-manifest/README.md)

---

## The Sequence at a Glance

```
WHAT_THIS_IS.md               ← read first (context)
LEARNING_PATH.md              ← you are here
        │
        ▼
phase1-the-services/
  README.md                   ← mvn spring-boot:run both services, curl them
        │
        ▼
phase2-dockerfile/
  README.md                   ← docker build, see layers and digest
  name-service/Dockerfile
  greeting-service/Dockerfile
        │
        ▼
phase3-kubernetes-raw/
  README.md                   ← kubectl apply, service DNS discovery
  k8s/*.yaml
        │
        ▼
phase4-helm-chart/
  README.md                   ← helm install, values, templates
  charts/name-service/
  charts/greeting-service/
        │
        ▼
phase5-the-manifest/
  README.md                   ← the full picture: manifest + deploy.sh
  demo-manifest.json
  deploy.sh
  charts/                     ← same charts as phase4
```

---

## After All Five Phases

Go back and look at a real entry in `boost-manifests/boost/9.0/9.0.4/boost-manifest.json`.

Every field will make complete sense — because you will have written all of them yourself,
at a smaller scale, in this project.

---

## One Rule

> **Do not skip phases.** Every phase ends with an unsolved problem that the next phase fixes.
> Skipping means you will hit the next phase's solution without understanding what problem it solves —
> and it will feel arbitrary and confusing.

