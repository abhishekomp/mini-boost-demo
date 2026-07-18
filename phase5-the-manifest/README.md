# Phase 5 — The Manifest and the Deploy Script

**The full circle.**

In this phase we write a `demo-manifest.json` that mirrors the structure of the real
`boost-manifest.json`, and a `deploy.sh` that reads it and calls Helm — exactly what
`dev-tools deploy manifest` does in the real Boost platform.

---

## The Question This Phase Answers

> What is `boost-manifest.json` really for?
> What does `dev-tools deploy manifest -m 9.0.4 -i userpod,messagingpod` actually do?
> How do the manifest, Helm, and Kubernetes all connect?

---

## Prerequisites

Everything from Phase 4. Both images imported into k3s.
No outstanding `helm list` releases (run `helm uninstall name-service greeting-service` if needed).

---

## What Is in This Folder

```
phase5-the-manifest/
├── demo-manifest.json    ← mirrors boost-manifest.json structure exactly
├── deploy.sh             ← reads the manifest and calls helm install (mini dev-tools)
└── charts/               ← same charts as Phase 4 (self-contained)
    ├── name-service/
    └── greeting-service/
```

---

## Is demo-manifest.json (and boost-manifest.json) an Industry Standard?

This is a natural question to ask when you see the manifest for the first time.

**Short answer: the format is custom. The idea is standard.**

The Unified Trials team invented the `boost-manifest.json` format themselves — they even wrote
their own JSON Schema to validate it (`boost.manifest.v0.2.schema.json` in the repo).
No external tool in the industry reads this format. Field names like `dmdp-box-version`,
`capabilities`, and `deployment-method` exist nowhere outside this codebase.

However, the concept it embodies — *"declare the exact versions of all your components in one
versioned file, store it in Git, deploy from it"* — is a very well-established industry practice
called a **Software Bill of Materials (SBOM)** or **Deployment Manifest**.

The closest industry standards that solve the same problem are:

| Standard | What it does |
|---|---|
| **SPDX** (Linux Foundation) | Formal component declaration — who makes what, at what version |
| **CycloneDX** (OWASP) | SBOM focused on supply chain security — widely tooled |
| **Helm `Chart.lock`** | Pins chart-to-chart dependencies (smaller scope) |
| **`docker-compose.yml`** | Declares which containers to run together locally |

The reason the team built their own instead of using one of these: none of them express
everything at once — Helm chart version pinning + image digest pinning + infrastructure
requirements + capability declarations + test suite version — in one file designed for
a custom CLI to parse. Building a minimal custom format was the pragmatic choice, and it
is a completely normal decision for a mature platform.

---

## Step 1 — Read demo-manifest.json

Open `demo-manifest.json` and read it carefully.

Now open `boost-manifests/boost/9.0/9.0.4/boost-manifest.json` from the real repository.

Find the `userpod` entry and compare it to the `name-service` entry in `demo-manifest.json`:

```
Real Boost:                            This demo:
───────────────────────────────────    ──────────────────────────────────
"name": "userpod"                      "name": "name-service"
"version": "2.35.1"                    "version": "1.0.0"
"deployment-method": "helm"            "deployment-method": "helm"
"helm-chart": {                        "helm-chart": {
  "name": "boost/charts/userpod",        "name": "charts/name-service",
  "version": "2.35.1"                    "version": "1.0.0"
}                                      }
"image": {                             "image": {
  "name": "boost/images/userpod",        "name": "name-service",
  "tag": "2.35.1",                       "tag": "1.0.0",
  "digest": "sha256:19e6aec5..."          "digest": "sha256:PLACEHOLDER"
}                                      }
```

They are structurally identical. The real manifest has more fields (`capabilities`,
`requirements`, 40 more components) — but the core idea is the same:

> **For this release, deploy THIS chart at THIS version with THIS exact image.**

---

## Step 2 — Update the Digest in the Manifest

The manifest should pin the exact image fingerprint. Get the image ID for each:

```bash
docker inspect name-service:1.0.0 --format='{{.Id}}'
docker inspect greeting-service:1.0.0 --format='{{.Id}}'
```

Each will return a SHA256 like:
```
sha256:a8f3c91d2b7e4f1a9c3e8b7d2f6c4e5a1b9d3f7c2e8a4b6d9f1c3e7a2b5d8f4
```

Open `demo-manifest.json` and replace both `sha256:USE_REAL_DIGEST_FROM_DOCKER_INSPECT`
values with your actual image IDs.

> **Note:** In the real Boost platform, CI/CD fills in the digest automatically after
> `docker push` to the registry. For locally-built images, the `.Id` field is the equivalent —
> the SHA256 of the image content. If you change a single line of application code and
> rebuild, this value will change completely, which is exactly the property that makes
> pinning meaningful.

---

## Step 3 — Read deploy.sh

Open `deploy.sh` and read every line. The comments explain each step.

The script does five things:
1. **Preflight checks** — verifies helm, kubectl, python3 are installed and the cluster is reachable
2. Read the manifest JSON (using Python, which is available on all Macs)
3. Filter to only the requested components (or all, if no filter given)
4. Extract: name, chart path, chart version, image name, image tag
5. Run `helm upgrade --install` for each component

**One thing to notice:** the manifest records `helm-chart.version` (e.g. `1.0.0`) but `deploy.sh`
does not pass `--version` to `helm upgrade --install`. That is intentional — the `--version` flag
is only meaningful when pulling a chart from a remote Helm repository by name. When using a local
directory path (`./charts/name-service`), Helm reads the version directly from `Chart.yaml` inside
that directory. In the real `dev-tools`, charts ARE pulled from a remote repository
(`boost/charts/userpod`), and `--version 2.35.1` is passed to pin the exact chart version.
This demo simplifies that by using local chart directories.

This is **exactly what `dev-tools deploy manifest` does** — just 100 lines of bash instead
of thousands of lines of Python.

---

## Step 4 — Deploy Everything with One Command

```bash
cd /Users/kjss920/ideaProjects/mini-boost-demo/phase5-the-manifest

./deploy.sh
```

You will see:

```
========================================
  mini-boost deploy.sh
  Manifest: demo-manifest.json
  Include:  all
========================================

---
Deploying: name-service
  Chart:   charts/name-service (version 1.0.0)
  Image:   name-service:1.0.0

Release "name-service" does not exist. Installing it now.
NAME: name-service
STATUS: deployed
  ✓ name-service deployed

---
Deploying: greeting-service
  Chart:   charts/greeting-service (version 1.0.0)
  Image:   greeting-service:1.0.0

Release "greeting-service" does not exist. Installing it now.
NAME: greeting-service
STATUS: deployed
  ✓ greeting-service deployed

========================================
  Deployment complete!
  ...
========================================
```

Wait for Pods to be ready:

```bash
kubectl get pods -w
```

Test the full flow:

```bash
curl http://localhost:30080/api/greet
# { "message": "Hello, Alice!" }
```

---

## Step 5 — Deploy Only Specific Components

Just like `dev-tools deploy manifest -i userpod,messagingpod`, you can target specific components:

```bash
# Deploy only name-service
./deploy.sh name-service

# Deploy only greeting-service
./deploy.sh greeting-service

# Deploy both (same as ./deploy.sh with no argument)
./deploy.sh name-service,greeting-service
```

---

## Step 6 — The Full Picture, Assembled

You have now built every piece. Here is how they connect:

```
demo-manifest.json
  │
  │  deploy.sh reads this file
  │  Finds: name-service → chart: charts/name-service v1.0.0 → image: name-service:1.0.0
  │
  ▼
helm upgrade --install name-service ./charts/name-service \
  --set image.repository=name-service \
  --set image.tag=1.0.0
  │
  │  Helm renders templates/deployment.yaml with these values
  │  Produces real Kubernetes YAML
  │
  ▼
kubectl apply (Helm does this internally)
  │
  │  Kubernetes API creates Deployment + Service
  │  k3s pulls the locally imported image
  │
  ▼
Pod: name-service running inside Colima VM
  │
  │  Service: name-service DNS = 10.43.xxx.xxx (ClusterIP)
  │
  ▼
greeting-service Pod calls http://name-service:8081/api/name
  │
  │  Kubernetes DNS resolves "name-service" to the ClusterIP
  │
  ▼
curl http://localhost:30080/api/greet
→ { "message": "Hello, Alice!" }
```

---

## Step 7 — Map Everything Back to the Real Boost Platform

| What you just did | What dev-tools does in Boost |
|---|---|
| Read `demo-manifest.json` | Read `boost/9.0/9.0.4/boost-manifest.json` from GitHub |
| Filter components by name | Filter by `--include userpod,messagingpod,...` flag |
| Run `helm install` from `./charts/` | Pull charts from Boost's Helm repository (AWS ECR / Harbor) |
| Image tag `name-service:1.0.0` | Image pulled from `boost/images/userpod:2.35.1` in registry |
| Import via `docker save \| k3s ctr import` | Kubernetes pulls from AWS ECR using credentials |
| Colima (your laptop) | AWS EKS cluster in the cloud |
| 2 services | 40+ services |
| 80-line bash script | Multi-thousand-line Python CLI (`ex-dev-tools` repo) |

The pattern is identical. The scale and robustness are different.

---

## Step 8 — Understand the Floating Manifests

In the real `boost-manifests` repository, you saw these folders:
- `boost-dev-latest/` — whatever is currently on the dev environment
- `boost-release-stable/` — last version where all system tests passed

These are just `boost-manifest.json` files that get **overwritten** by CI/CD after each
successful deployment. Instead of a specific version (`9.0.4`), `dev-tools` can say:

```bash
dev-tools deploy manifest -m dev-stable
```

And it reads the `boost-dev-stable/boost-manifest.json` file — whichever version is pinned there.

In our demo, this would be equivalent to having a `manifests/stable/demo-manifest.json`
that always points to the last tested version. The `deploy.sh` would just read that file instead.

---

## Clean Up

```bash
helm uninstall name-service greeting-service
kubectl get all  # Should be empty (except kubernetes service)
helm list        # Should be empty
```

---

## Wait — Is This Just Automation of What I'd Do Manually?

Yes. Exactly. And that is the right question to ask at this moment.

Here is what a developer would type **by hand** to deploy 2 Spring Boot services
to local Colima with no tooling at all:

```bash
# Build and import images
docker build -t name-service:1.0.0 .          # in name-service/
docker build -t greeting-service:1.0.0 .      # in greeting-service/
docker save name-service:1.0.0    | colima ssh -- sudo k3s ctr images import -
docker save greeting-service:1.0.0 | colima ssh -- sudo k3s ctr images import -

# Deploy to Kubernetes
kubectl apply -f name-service-deployment.yaml
kubectl apply -f name-service-service.yaml
kubectl apply -f greeting-service-deployment.yaml
kubectl apply -f greeting-service-service.yaml
```

That is 8 commands after writing the code. For only 2 services.

**Each phase of this learning path removes some of those manual steps:**

| Phase | What the developer types | What got better |
|---|---|---|
| Phase 1 | `mvn spring-boot:run` × 2 | No Docker, no Kubernetes — just run it |
| Phase 2 | `docker build` × 2 + `k3s import` × 2 | Images exist; networking still manual |
| Phase 3 | `kubectl apply -f` × 4 | Kubernetes manages networking; 4 YAML files |
| Phase 4 | `helm install` × 2 | 4 YAML files replaced by 2 parameterised charts |
| Phase 5 | `./deploy.sh` | **One command** reads the manifest and calls Helm for each service |

`deploy.sh` automates the `kubectl/helm` steps. The image build and import are still manual in this demo.

### What is still manual in this demo vs. the real Boost platform

In this demo, you still manually run `docker build` and `docker save | k3s import`.

In the **real Boost platform**, even those steps are automated by a CI/CD pipeline:

```
Developer pushes code to GitHub
        │
        ▼
CI/CD pipeline runs automatically:
  1. mvn clean package
  2. docker build  →  boost/images/userpod:2.36.0
  3. docker push   →  AWS ECR (the registry)
  4. Updates boost-manifest.json with new version + digest
  5. Commits the updated manifest to Git
        │
        ▼
Developer runs ONE command locally:
  dev-tools deploy manifest -m 9.0.4 -i userpod
        │
        ▼
dev-tools reads manifest
→ helm upgrade --install per service
→ Kubernetes pulls image from ECR
→ Pod runs
```

The developer never runs `docker build` locally just to deploy. CI/CD handles it.
`dev-tools deploy manifest` is the last step — reading a pre-built manifest and
calling Helm. That is the step `deploy.sh` in this demo represents.

### Is all this overkill for 2 services?

**Completely yes.** For 2 services you would use `docker-compose` or just run them
with `mvn spring-boot:run`. You would never build Dockerfiles, Helm charts, a manifest
JSON, and a deploy script.

This machinery becomes **worth the cost** at scale:

| | 2 services (this demo) | 40+ services (real Boost) |
|---|---|---|
| Manual approach | Fine — use Maven or docker-compose | Unmanageable — 40 terminals, 40 commands |
| Who manages versions | You, in your head | The manifest, in Git |
| Reproducing an environment | Easy | Impossible without the manifest |
| Deploying to dev vs prod | Change one URL | Different config values, same manifest |
| Rolling back a bad release | Stop, restart | `helm rollback userpod 3` |

The demo uses 2 services so every detail is visible and understandable.
The real Boost platform uses all this machinery because those 2 services scaled to 40+
across multiple teams, multiple environments, and multiple releases per week.

---

## The Mystery of Who Actually Writes the Manifest Files

If you run `git blame` on a real manifest file in the `boost-manifests` repository:

```bash
cd /Users/kjss920/code/boost/boost-manifests
git --no-pager log --format="%an | %s" boost/9.0/9.0.4/boost-manifest.json
```

You will see the author is **`github-actions[bot]`** — not a human developer.
Nobody sat down and typed `boost-manifest.json` by hand.
A GitHub Actions workflow wrote it automatically.

### The full chain that created that file

```
Developer merges code in boost-userpod repo
          │
          │  git push to main branch
          ▼
GitHub Actions workflow fires automatically (inside boost-userpod repo)
          │
          ├─ 1. mvn clean package  (compile + test)
          ├─ 2. docker build -t boost/images/userpod:2.35.1 .
          ├─ 3. docker push → AWS ECR
          │      ECR returns: sha256:19e6aec5c1c03f4e92f630...
          │                   ↑ machine-generated, not human-typed
          │
          ├─ 4. git clone boost-manifests repo
          ├─ 5. Create boost/9.0/9.0.4/boost-manifest.json
          │      writes: "version": "2.35.1"
          │               "digest": "sha256:19e6aec5..."
          │
          ├─ 6. git commit --author="github-actions[bot]"
          └─ 7. git push → boost-manifests
                    │
                    ▼
          The commit you see in git blame.
          The SHA256 digest came directly from the registry.
          No human touched it.
```

This is why the digest can be trusted — it is not a value someone copied and pasted.
The CI/CD pipeline asked the registry "what is the exact fingerprint of the image I just pushed?"
and wrote the answer straight into the JSON.

### Is this industry standard?

**Yes — this is the core pattern of GitOps**, one of the most widely adopted practices
in modern software delivery.

The idea:

> **The Git repository is the single source of truth for what should be deployed.
> Automation keeps it updated. Humans never manually edit deployment configs.**

You see this pattern everywhere:

| Tool | What it auto-commits |
|---|---|
| **Dependabot** (GitHub) | Updates `package.json` / `pom.xml` when a library releases a new version |
| **Renovate** | Same as Dependabot — opens PRs to bump dependency versions |
| **Release Please** (Google) | Auto-creates release PRs with updated `CHANGELOG.md` and version numbers |
| **ArgoCD / FluxCD** | Watch a Git repo; when the manifest changes, auto-deploy to Kubernetes |
| **Boost's CI/CD** | Service pipeline auto-commits new image digest into `boost-manifests` |

They all follow the same principle: **automation as the committer, Git as the audit trail**.

### Why a separate repo for the manifests?

Three reasons the industry uses a separate manifest repo instead of putting it in the service repo:

1. **Clean audit trail** — the manifest repo's `git log` is a perfect history of every
   deployment: what was deployed, when, by which pipeline run. Rolling back means `git revert`.

2. **Different access controls** — not every developer should be able to directly edit what
   runs in production. The manifest repo can have stricter branch protection and approval rules.

3. **Different release cadence** — code in `boost-userpod` changes many times a day;
   the manifest only changes when a release is officially cut. Separate repos keep both histories clean.

### How this connects to your demo

In `deploy.sh`, you manually edit `demo-manifest.json` and run the script.
In the real Boost platform, that manifest file is written by a machine and you just
run `dev-tools deploy manifest`. The structure of the JSON is identical — only the
author of the file changes (you vs. `github-actions[bot]`).

---

## What You Should Take Away from Phase 5

1. A **manifest JSON** is a version registry — it pins chart version AND image tag/digest
2. `deploy.sh` is what `dev-tools` does: read manifest → call `helm upgrade --install` per component
3. `helm upgrade --install` is **idempotent** — run it many times, same result
4. The image digest in the manifest is the ultimate guarantee of reproducibility
5. `dev-tools deploy manifest -i name` is just filtering which components from the manifest to deploy
6. Floating manifests (`dev-latest`, `release-stable`) are just pointers — files that CI/CD overwrites

---

## You Have Completed the Learning Path

Go back and run this against the real codebase:

```bash
cd /Users/kjss920/code/boost/boost-manifests
cat boost/9.0/9.0.4/boost-manifest.json | python3 -m json.tool | head -60
```

Every field — `schemaversion`, `requirements`, `services`, `components`, `helm-chart`,
`image`, `digest`, `capabilities` — should now make complete sense.

And when you run:

```bash
dev-tools deploy manifest -m 9.0.4 -i userpod,messagingpod,studypod
```

You know exactly what happens:
1. dev-tools fetches `boost/9.0/9.0.4/boost-manifest.json` from GitHub
2. Filters to `userpod`, `messagingpod`, `studypod`
3. Fetches environment config from `uts-configuration`
4. For each: `helm upgrade --install <name> boost/charts/<name> --version X --set image.digest=sha256:...`
5. Helm renders templates with values and applies YAML to Kubernetes (your Colima cluster)
6. Pods appear. Platform runs.

**The mystery is solved.**

