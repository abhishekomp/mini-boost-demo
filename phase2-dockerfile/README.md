# Phase 2 — The Dockerfile

**No Kubernetes. No Helm.**

Just Docker. We take the two Spring Boot services from Phase 1 and package each one
into a Docker image.

---

## The Question This Phase Answers

> How does a Spring Boot JAR become a Docker image?
> What is inside the image? What are layers?
> What is the SHA256 digest and why does `boost-manifest.json` store it?

---

## Prerequisites for This Phase

Make sure Colima is running:

```bash
colima start
```

Verify Docker is available:

```bash
docker ps
# Should show a table (even if empty) — not an error
```

If you see `Cannot connect to the Docker daemon`, Colima is not running.

---

## What Is Already in This Folder

```
phase2-dockerfile/
├── name-service/
│   ├── pom.xml          ← identical to Phase 1
│   ├── src/...          ← identical to Phase 1
│   └── Dockerfile       ← NEW: the packaging recipe
│
└── greeting-service/
    ├── pom.xml          ← identical to Phase 1
    ├── src/...          ← identical to Phase 1
    └── Dockerfile       ← NEW: the packaging recipe
```

The only new files are the two `Dockerfile`s. The application code is unchanged.

---

## Step 1 — Read the Dockerfile

Open `name-service/Dockerfile` and read it carefully. The comments explain every line.

Key things to notice:

**Multi-stage build:**
```dockerfile
FROM maven:3.9-eclipse-temurin-21-alpine AS build   ← Stage 1: compile and package
...
FROM eclipse-temurin:21-jre-alpine                  ← Stage 2: runtime only
COPY --from=build /app/target/*.jar app.jar
```

Stage 1 uses a large Maven image to compile. Stage 2 starts fresh with only the Java runtime
and copies just the JAR. The Maven tooling, source code, and intermediate files are all discarded.

Result: the final image is ~200MB instead of ~500MB. This matters at scale — you push and pull
this image constantly in production.

**ENTRYPOINT:**
```dockerfile
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

This is the command that runs every time a container starts from this image.
It is the equivalent of you typing `java -jar app.jar` in a terminal — except it runs
automatically inside the container.

---

## Step 2 — Build the name-service Image

```bash
cd /Users/kjss920/ideaProjects/mini-boost-demo/phase2-dockerfile/name-service
docker build -t name-service:1.0.0 .
```

Breaking down the command:
- `docker build` — build an image
- `-t name-service:1.0.0` — tag the image with name `name-service` and version `1.0.0`
- `.` — the build context is the current directory (Docker will look for `Dockerfile` here)

> **What is `.dockerignore`?**
> Notice the `.dockerignore` file in this directory. Before building, Docker sends all files
> in the build context (`.`) to the Docker daemon. Without `.dockerignore`, it would send
> the `target/` folder (hundreds of MB of compiled artifacts) unnecessarily.
> `.dockerignore` tells Docker to skip those files — exactly like `.gitignore` for Git.

> **First build:** Docker downloads the Maven and Java base images. This takes **3–8 minutes**
> on first run. Subsequent builds are much faster because layers are cached.

You will see output like:
```
[+] Building 45.3s (14/14) FINISHED
 => [build 1/5] FROM maven:3.9-eclipse-temurin-21-alpine   ← pulling base image
 => [build 2/5] WORKDIR /app
 => [build 3/5] COPY pom.xml .
 => [build 4/5] RUN mvn dependency:go-offline              ← downloading dependencies
 => [build 5/5] COPY src ./src
 => [build 6/5] RUN mvn clean package                      ← compiling and packaging
 => [stage-2 1/3] FROM eclipse-temurin:21-jre-alpine
 => [stage-2 2/3] COPY --from=build /app/target/*.jar app.jar
 => exporting to image
```

The first build takes longer (downloading Maven, dependencies). Subsequent builds are
faster because Docker caches layers.

---

## Step 3 — See the Image and Its Digest

List your local images:

```bash
docker images name-service
```

```
REPOSITORY     TAG       IMAGE ID       CREATED          SIZE
name-service   1.0.0     a8f3c91d2b7e   10 seconds ago   218MB
```

Now get the image's SHA256 identifier:

```bash
docker inspect name-service:1.0.0 --format='{{.Id}}'
```

You will see something like:
```
sha256:a8f3c91d2b7e4f1a9c3e8b7d2f6c4e5a1b9d3f7c2e8a4b6d9f1c3e7a2b5d8f4
```

> **Why not `RepoDigests`?**
> You may see tutorials use `docker inspect ... | grep RepoDigests`. That field is only
> populated **after** an image is pushed to a registry. For a locally-built image it is
> always empty. The `.Id` field above is the SHA256 hash of the image content — the same
> thing the registry would record as the digest when you push.

This SHA256 is the image's **immutable fingerprint**. This is **exactly the digest you see
in `boost-manifest.json`**:

```json
"image": {
  "name": "boost/images/userpod",
  "tag": "2.35.1",
  "digest": "sha256:19e6aec5c1c03f4e92f630cdc071e86e4d7b435d7a189db468319502b50c2b18"
}
```

If a single byte changes in the application code or its dependencies, the digest changes
completely. This makes it an **immutable fingerprint** — a guarantee that you are always
deploying exactly the same image.

---

## Step 4 — See the Layers

```bash
docker history name-service:1.0.0
```

```
IMAGE          CREATED         CREATED BY                                      SIZE
a8f3c91d2b7e   1 minute ago    ENTRYPOINT ["java" "-jar" "/app/app.jar"]       0B
<missing>      1 minute ago    COPY /app/target/*.jar app.jar                  28MB   ← your JAR
<missing>      1 minute ago    WORKDIR /app                                    0B
<missing>      1 minute ago    FROM eclipse-temurin:21-jre-alpine              190MB  ← Java runtime
```

Each line is a layer. The bottom layers (Java runtime, Alpine OS) are large but shared across
many images on the same machine. The top layer (your JAR) is unique to your service.

When you push a new version of `name-service` to a registry, only the changed layers are
uploaded — not the entire image. The Java runtime layer is already on the server.

---

## Step 5 — Run name-service as a Container

```bash
docker run --rm -p 8081:8081 --name name-service-container name-service:1.0.0
```

Breaking down the command:
- `--rm` — automatically remove the container when it stops
- `-p 8081:8081` — map port 8081 on your Mac to port 8081 inside the container
  Format: `-p HOST_PORT:CONTAINER_PORT`
- `--name name-service-container` — give the container a name
- `name-service:1.0.0` — the image to run

Wait for `Started NameServiceApplication` in the output.

In another terminal:
```bash
curl http://localhost:8081/api/name
# { "name": "Bob" }
```

It works — a Spring Boot app running inside a container on your Mac, called via HTTP.

Stop it with `Ctrl+C`.

---

## Step 6 — Build greeting-service

```bash
cd /Users/kjss920/ideaProjects/mini-boost-demo/phase2-dockerfile/greeting-service
docker build -t greeting-service:1.0.0 .
```

This will be faster because the Maven and Java base images are already cached.

---

## Step 7 — Try Running greeting-service (It Will Partially Fail)

Start name-service in the background:

```bash
docker run -d --rm -p 8081:8081 --name name-service-container name-service:1.0.0
```

(`-d` = detached mode, runs in background)

Now start greeting-service:

```bash
docker run --rm -p 8080:8080 --name greeting-service-container greeting-service:1.0.0
```

Wait for `Started GreetingServiceApplication` in the output. **The service starts successfully.**
Spring Boot reads `application.yml`, sets `name.service.url=http://localhost:8081`, and
considers itself ready. It does NOT try to connect to name-service at startup — it only
connects when you actually make a request.

Now call it from another terminal:

```bash
curl http://localhost:8080/api/greet
```

You will get an error. Check the greeting-service logs — you will see something like:
```
Connection refused: localhost/127.0.0.1:8081
```

**Why does the service start fine but fail at request time?**

Inside the `greeting-service` container, `localhost` means the container itself — not your Mac,
and not the `name-service` container. When greeting-service tries to call
`http://localhost:8081/api/name`, it is looking on port 8081 of its own container. There is
nothing there. The containers are isolated from each other.

The fix would require `--network` flags and using container names instead of `localhost`.
But that manual wiring is exactly what Kubernetes handles automatically — and cleanly.

Stop both containers:
```bash
docker stop name-service-container greeting-service-container
```

---

## Step 8 — Why Images Need to Be Imported into Kubernetes (Read This Carefully)

This step answers a question you are probably asking right now:

> "I just built the image with `docker build`. It is on my Mac. Why can't Kubernetes just use it?"

The answer is one of the most important things in this entire learning path.

### The Two Separate Image Stores Inside Colima

When Colima is running, you have a Linux VM on your Mac. Inside that VM, there are
**two separate image stores** — like two different filing cabinets in the same room:

```
Your Mac
└── Colima VM (a Linux virtual machine)
    │
    ├── Cabinet A: Docker image store
    │   Used by: docker build, docker run, docker images
    │   After "docker build": name-service:1.0.0 ✅
    │
    └── Cabinet B: k3s (Kubernetes) image store
        Used by: Kubernetes when starting Pods
        After "docker build": name-service:1.0.0 ❌  (not here!)
```

When you run `docker build`, the image goes into **Cabinet A** (Docker's store).
When Kubernetes tries to start a Pod, it looks in **Cabinet B** (k3s's store).
They are isolated from each other even though they live in the same VM.

This means: even though `docker images` shows your image, Kubernetes cannot find it.
It will fail with `ImagePullBackOff` or `ErrImageNeverPull`.

### How the Real Boost Platform Solves This

In production, the two cabinets are in completely different buildings — your Mac vs a cloud server.
The solution is a **container registry** — a shared server that both sides can talk to:

```
CI/CD pipeline                 Registry                Kubernetes cluster
(builds the image)             (stores it)             (runs it)
      │                            │                         │
docker build                  docker push              kubectl → k3s pulls
      │                            ▼                         │
      └──────────────────►  localhost:5000/name-service ◄───┘
                               sha256:abc123
```

A **local registry** is just that server running as a container on your machine.
You start it with one command: `docker run -d -p 5000:5000 registry:2`
Then push to it: `docker push localhost:5000/name-service:1.0.0`
And Kubernetes pulls from it: `image: localhost:5000/name-service:1.0.0`

This is the production-faithful approach used in the real Boost platform (with ECR/Harbor instead of `localhost:5000`).

### What We Do in This Demo (Direct Import)

For simplicity, we skip the registry and copy the image directly from Cabinet A to Cabinet B.
Think of it as physically carrying the image from one filing cabinet to the other:

```
Cabinet A ──(docker save | k3s ctr import)──► Cabinet B
```

It is less faithful to production but has no setup overhead and works reliably.
The concept is identical: the image must exist in Kubernetes's store before a Pod can use it.

```bash
# Make sure Colima is running with Kubernetes
colima start --kubernetes

# Import name-service image from Cabinet A (Docker) to Cabinet B (k3s)
docker save name-service:1.0.0 | colima ssh -- sudo k3s ctr images import -

# Import greeting-service
docker save greeting-service:1.0.0 | colima ssh -- sudo k3s ctr images import -
```

Verify both images are now in Cabinet B:
```bash
colima ssh -- sudo k3s ctr images list | grep -E "name-service|greeting-service"
```

You should see both. They are now in Kubernetes's image store and ready for Phase 3.

---

## What You Should Take Away from Phase 2

1. A `Dockerfile` is a recipe — a sequence of instructions that builds an image layer by layer
2. A **multi-stage build** uses one image to compile and a smaller image to run — keeps images lean
3. The **SHA256 digest** is the image's immutable fingerprint — the real pin in `boost-manifest.json`
4. `docker build -t name:tag .` builds the image; `docker run -p HOST:CONTAINER image:tag` runs it
5. Containers are isolated — they cannot reach each other on `localhost`
6. Images must be in k3s's image store before Kubernetes can use them

---

## The Problem This Phase Leaves Unsolved

You have two Docker images. You can run each one individually. But they cannot talk to each other.

To fix the networking manually with Docker would require:
```bash
docker network create demo-network
docker run -d --network demo-network --name name-service-container name-service:1.0.0
docker run -d --network demo-network \
  -e NAME_SERVICE_URL=http://name-service-container:8081 \
  --name greeting-service-container \
  greeting-service:1.0.0
```

This works for two services. For forty services it is unmanageable. There is also no:
- Automatic restart if a container crashes
- Health checking
- Graceful rollout of new versions
- Resource limits

You need something that manages all of this for you. That something is **Kubernetes**. Move to Phase 3.

---

## Before Moving to Phase 3

Make sure you can answer these without looking:

- What does `FROM ... AS build` do? Why are there two `FROM` lines?
- What does `-p 8081:8081` mean? What is the left side? What is the right side?
- What is the difference between an image tag and an image digest?
- Why couldn't `greeting-service` reach `name-service` when both were running as containers?
- What command imports a Docker image into k3s?

👉 [Move to Phase 3: phase3-kubernetes-raw/README.md](../phase3-kubernetes-raw/README.md)

