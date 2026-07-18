# What Is This Project?

> Read this before anything else. It takes 5 minutes.
> It will save you hours of confusion later.

---

## This is a Miniature

The real Boost platform at Unified Trials is a healthcare/clinical trials system made of
**40+ microservices** — `userpod`, `messagingpod`, `studypod`, `devicepod`, and many more.
Each one is a Spring Boot application. Each one is independently versioned and deployed.
Deploying them is coordinated by a tool called `dev-tools` that reads a file called
`boost-manifest.json`.

If you have ever run this command:

```bash
dev-tools deploy manifest -m 9.0.4 -i userpod,messagingpod,studypod
```

…and wondered what actually happened — this project is your answer.

**This project is a miniature, hands-on version of that exact flow**, using just two simple
services instead of forty. Everything you build and run here maps directly to something real
in the Boost codebase.

---

## Is This a DevOps Thing?

**Yes.** Everything in this project — the Dockerfiles, Kubernetes, Helm, the manifest JSON,
the deploy script, the CI/CD pipeline — falls under the umbrella of **DevOps**.

DevOps is not a tool or a role. It is a set of practices that brings software **development**
(writing the code) and software **operations** (running the code reliably) closer together.

The specific practices you will encounter in this project have names:

| Practice | What it means | Where you see it in this project |
|---|---|---|
| **Containerisation** | Package an app with everything it needs to run, so it behaves identically anywhere | Phase 2 — Dockerfile |
| **Container orchestration** | Automatically manage, restart, and network many containers | Phase 3 — Kubernetes |
| **Infrastructure as Code** | Describe your infrastructure in files stored in Git, not in a web console | Phase 3 YAML, Phase 4 Helm charts |
| **GitOps** | Git is the single source of truth for deployments; automation keeps it updated | Phase 5 — manifest + deploy.sh |
| **Immutable deployments** | Never modify a running service; instead replace it with a new version | Image digest pinning in the manifest |
| **Shift-left** | Test and run the full system locally on your laptop, not just in the cloud | Colima — local Kubernetes on your Mac |

None of these are exotic. They are the standard toolkit of software delivery at most modern
technology companies.

---

## The Bigger Picture — Where This Fits

This project teaches you the **local deployment** part of a larger automated pipeline.
Here is the full picture so you know where you are:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Developer's world                                                      │
│                                                                         │
│  1. Write Java code in boost-userpod repo                               │
│  2. Push to GitHub                                                      │
└──────────────────────────┬──────────────────────────────────────────────┘
                           │  git push triggers
                           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  CI/CD Pipeline (GitHub Actions)         ← THIS IS AUTOMATED           │
│                                                                         │
│  3. Compile and test the code                                           │
│  4. Build Docker image  →  userpod:2.35.1                               │
│  5. Push to AWS ECR (container registry)                                │
│     ECR returns: sha256:19e6aec5...   ← machine-generated digest       │
│  6. Write that digest into boost-manifest.json                          │
│  7. git commit --author="github-actions[bot]"                           │
│  8. git push to boost-manifests repo                                    │
└──────────────────────────┬──────────────────────────────────────────────┘
                           │  manifest updated
                           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Developer deploys locally              ← THIS IS WHAT THIS PROJECT    │
│                                            TEACHES YOU                  │
│  dev-tools deploy manifest -m 9.0.4 -i userpod                         │
│     reads boost-manifest.json                                           │
│     calls helm upgrade --install                                        │
│     Kubernetes pulls image from ECR                                     │
│     Pod runs in Colima (your Mac)                                       │
└─────────────────────────────────────────────────────────────────────────┘
```

**The key insight:** Nobody on the team manually writes `boost-manifest.json`.
If you run `git blame` on a manifest file in the real repository, you will see
`github-actions[bot]` as the author — a machine committed it.
The SHA256 digest came directly from the container registry, written by the pipeline.
That is GitOps: automation as the committer, Git as the audit trail.

**This project teaches the bottom box** — the developer's local deployment.
The top two boxes (CI/CD) are automated infrastructure that runs in GitHub's cloud.
Once you understand the bottom box deeply, the top boxes will make immediate sense.

---

## The Two Services in This Project

Instead of `userpod` and `messagingpod`, we have two toy services:

**`name-service`** — returns a random name:
```
GET http://localhost:8081/api/name
→ { "name": "Alice" }
```

**`greeting-service`** — calls `name-service` and builds a greeting:
```
GET http://localhost:8080/api/greet
→ { "message": "Hello, Alice!" }
```

The services themselves are trivial. **That is deliberate.** The moment your attention goes
to the business logic, you stop learning about deployment. Keep the app boring; learn the pipeline.

---

## What You Will Build, Step by Step

```
Phase 1        Phase 2        Phase 3        Phase 4        Phase 5
─────────────────────────────────────────────────────────────────────
Two Spring     Package        Deploy to      Replace raw    The Manifest
Boot apps      as Docker      Kubernetes     YAML with      + deploy.sh
talking to     images         with raw       a Helm         (mini dev-tools)
each other     (Dockerfiles)  YAML           chart
               │                                            │
               │                                            │
               This is how "userpod" becomes a              This is what
               Docker image in the real Boost pipeline      dev-tools does
```

---

## How This Maps to the Real Boost Platform

| This project | Real Boost platform |
|---|---|
| `name-service` | `userpod`, `messagingpod`, any pod |
| `greeting-service` calls `name-service` | `userpod` calls `mongodb-test-proxy` |
| `Dockerfile` | The Dockerfile in `boost-userpod` repo |
| Docker image digest | `"digest": "sha256:19e6..."` in `boost-manifest.json` |
| Raw k8s YAML (Phase 3) | What Helm generates automatically in the real flow |
| Helm chart (Phase 4) | `boost/charts/userpod` in the Boost Helm repository |
| `demo-manifest.json` (Phase 5) | `boost/9.0/9.0.4/boost-manifest.json` |
| `deploy.sh` (Phase 5) | `dev-tools deploy manifest` command |
| You editing `demo-manifest.json` | `github-actions[bot]` auto-committing it |
| Colima (your local k8s) | AWS EKS cluster in the cloud |

---

## There Is Also a Conceptual Companion

This project is hands-on — you build and run everything yourself.
But before (or alongside) building, it helps to understand the concepts deeply:
what a Docker image really is, what Kubernetes is doing under the hood, what a Helm
chart contains, and why `boost-manifest.json` is written by a robot.

There is a companion reading path that explains all of this using the **real Boost
platform** as the example — the actual `boost-manifest.json`, the actual `userpod`,
the actual `dev-tools` flow:

👉 **`/Users/kjss920/ideaProjects/helm-k8s-explained/`**

Start there with `WHAT_THIS_IS.md`, then `THE_SIMPLE_STORY.md`.

| This project (`mini-boost-demo`) | The companion (`helm-k8s-explained`) |
|---|---|
| Hands-on — you build a miniature | Conceptual — explains the real platform |
| Two toy services you run yourself | Uses `userpod`, the real manifest as examples |
| You feel it by doing | You understand it by reading |
| Build it | Then read the real thing and it all clicks |

**Recommended:** Read `THE_SIMPLE_STORY.md` in the companion first (5 minutes),
then come here and work through the five phases. The concepts will land much faster.

---

## Prerequisites

You need these installed before Phase 2 onwards:

| Tool | Check | Install |
|---|---|---|
| Java 21+ | `java -version` | `brew install openjdk@21` |
| Maven | `mvn -version` | `brew install maven` |
| Docker (via Colima) | `docker ps` | already installed |
| Colima with Kubernetes | `colima status` then `colima start --kubernetes` | `brew install colima` |
| kubectl | `kubectl version --client` | `brew install kubectl` |
| Helm | `helm version` | `brew install helm` |

Phase 1 needs only Java and Maven. Everything else is introduced one phase at a time.

---

## One Rule

> **Do not skip phases.** Each one answers a question that the previous one deliberately left open.
> If Phase 4 feels confusing, go back to Phase 3. The confusion is always in the concept
> that was not fully absorbed earlier — never in the new concept itself.

👉 [Start the learning path → LEARNING_PATH.md](./LEARNING_PATH.md)
