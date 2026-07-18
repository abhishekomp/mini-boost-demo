# Phase 1 — The Two Services

**No Docker. No Kubernetes. No Helm.**

Just two Spring Boot apps running on your Mac, talking to each other over HTTP.

---

## The Question This Phase Answers

> How do two microservices communicate with each other?
> What does "service A calls service B" actually mean in code?

---

## What Is Already in This Folder

```
phase1-the-services/
├── name-service/
│   ├── pom.xml
│   └── src/main/java/com/example/nameservice/
│       ├── NameServiceApplication.java    ← Spring Boot entry point
│       └── NameController.java            ← two endpoints: /api/name and /api/health
│   └── src/main/resources/
│       └── application.yml                ← sets port to 8081
│
└── greeting-service/
    ├── pom.xml
    └── src/main/java/com/example/greetingservice/
        ├── GreetingServiceApplication.java  ← Spring Boot entry point
        └── GreetingController.java          ← calls name-service, returns greeting
    └── src/main/resources/
        └── application.yml                  ← sets port to 8080, configures name-service URL
```

The code is already complete. You do not need to write anything.
Read through each file to understand what it does, then run the steps below.

---

## Step 1 — Read the Code

Open `name-service/src/main/java/com/example/nameservice/NameController.java`.

Notice:
- It has one main endpoint: `GET /api/name`
- It picks a random name from a hardcoded list and returns `{ "name": "Alice" }`
- It also has `GET /api/health` — we will use this pattern in Kubernetes later

Open `greeting-service/src/main/java/com/example/greetingservice/GreetingController.java`.

Notice this field:
```java
@Value("${name.service.url}")
private String nameServiceUrl;
```

This is **externalised configuration** — the URL of `name-service` is not hardcoded into the class.
It is read from `application.yml` (or from an environment variable). This is how the same
compiled code can point to `http://localhost:8081` on your Mac and to `http://name-service:8081`
inside a Kubernetes cluster. **The binary never changes. Only the configuration changes.**

This is one of the most important principles in the whole learning path. Keep it in mind.

Open `greeting-service/src/main/resources/application.yml`:

```yaml
name:
  service:
    url: http://localhost:8081
```

This is where `${name.service.url}` gets its value when running locally.
In Phase 3, we will override this with a Kubernetes environment variable.

---

## Step 2 — Start name-service

Open a terminal. Navigate to the `name-service` directory and start it:

```bash
cd /Users/kjss920/ideaProjects/mini-boost-demo/phase1-the-services/name-service
mvn spring-boot:run
```

> **First run only:** Maven downloads all Spring Boot dependencies from the internet.
> This takes **2–5 minutes** depending on your connection. Subsequent runs are instant
> because Maven caches them in `~/.m2/repository`. You will see hundreds of lines like
> `Downloading from central: https://repo.maven.apache.org/...` — that is normal.

Wait until you see:
```
Started NameServiceApplication in X.XXX seconds
```

Leave this terminal running.

---

## Step 3 — Test name-service Directly

Open a **second terminal** and call the endpoint:

```bash
curl http://localhost:8081/api/name
```

Expected response (name will vary — it is random):
```json
{ "name": "Alice" }
```

Call it a few more times. You should see different names:
```bash
curl http://localhost:8081/api/name
# { "name": "Bob" }

curl http://localhost:8081/api/name
# { "name": "Charlie" }
```

Also check the health endpoint:
```bash
curl http://localhost:8081/api/health
# { "status": "UP", "service": "name-service" }
```

`name-service` is working. It knows nothing about `greeting-service`. It just returns names.

---

## Step 4 — Start greeting-service

Open a **third terminal**. Navigate to the `greeting-service` directory:

```bash
cd /Users/kjss920/ideaProjects/mini-boost-demo/phase1-the-services/greeting-service
mvn spring-boot:run
```

Wait until you see:
```
Started GreetingServiceApplication in X.XXX seconds
```

---

## Step 5 — Test the Full Flow

In the second terminal, call `greeting-service`:

```bash
curl http://localhost:8080/api/greet
```

Expected response:
```json
{ "message": "Hello, Alice!" }
```

What just happened under the hood:

```
Your curl command
      │
      │ HTTP GET /api/greet
      ▼
greeting-service (port 8080)
      │
      │ HTTP GET /api/name  ← greeting-service calls name-service internally
      ▼
name-service (port 8081)
      │
      └── returns { "name": "Alice" }
      │
back to greeting-service
      │
      └── returns { "message": "Hello, Alice!" }
      │
back to your curl command
```

Call it a few times and notice the name changes — greeting-service picks up whatever name-service returns.

---

## Step 6 — Break It (Intentionally)

Stop `name-service` by pressing `Ctrl+C` in its terminal.

Now call `greeting-service` again:

```bash
curl http://localhost:8080/api/greet
```

You will see an error like:
```
{"timestamp":"...","status":500,"error":"Internal Server Error",...}
```

`greeting-service` tried to call `http://localhost:8081/api/name` and got a connection refused error,
because `name-service` is no longer running.

**This is intentional.** It demonstrates that microservices are **dependent on each other at runtime**.
If `name-service` is down, `greeting-service` breaks too. In production, this is why:
- Services have health checks (Kubernetes restarts them if they fail)
- Services have retry logic and circuit breakers
- The manifest deploys dependent services together

Restart `name-service` before moving on.

---

## Step 7 — Look at How the URL Is Configured

This is the important moment. Open `greeting-service/src/main/resources/application.yml` again:

```yaml
name:
  service:
    url: http://localhost:8081
```

Now ask yourself: **what if this service was running inside Kubernetes?**

Inside a Kubernetes cluster, `localhost:8081` means the container itself — not the other service.
The URL would need to be something like `http://name-service:8081`, where `name-service` is a
Kubernetes Service name that resolves via cluster DNS.

But we cannot change the code every time we deploy to a different environment. That is why the
URL is in `application.yml` (and can be overridden by an environment variable at runtime).

Spring Boot maps environment variables to properties automatically:
```
Environment variable:  NAME_SERVICE_URL=http://name-service:8081
Maps to property:      name.service.url=http://name-service:8081
```

In Phase 3, we will set this environment variable in the Kubernetes Deployment YAML.
In Phase 4, we will set it via a Helm chart value.
The code in `GreetingController.java` will never need to change.

---

## What You Should Take Away from Phase 1

1. Two microservices communicate over **plain HTTP** — one calls the other's REST endpoint
2. **Externalised configuration** (`@Value`) means the same compiled code runs with different
   URLs in different environments — local, dev, production
3. Spring Boot maps environment variables to properties automatically — `NAME_SERVICE_URL`
   overrides `name.service.url`
4. A service failure cascades to its dependents — this is why Kubernetes health checks matter

---

## The Problem This Phase Leaves Unsolved

Right now, to run both services, you need:
- Two open terminals
- Both `mvn spring-boot:run` commands running simultaneously
- The correct port not already in use
- Java and Maven installed on the target machine

You cannot hand these two services to someone and say "just run them" unless they have:
- Java 21 installed
- Maven installed
- Knowledge of what commands to run
- Two free ports

More importantly: imagine 40 services instead of 2. You would need 40 terminals, 40 commands,
and a precise startup order.

What if you could package each service into a single sealed file that runs identically on any
machine, without requiring anything to be pre-installed?

That is what a **Docker image** does. Move to Phase 2.

---

## Before Moving to Phase 2

Stop both services (`Ctrl+C` in each terminal).

Make sure you can answer these without looking:

- What does `@Value("${name.service.url}")` do? What does it read the value from?
- What URL does `greeting-service` use to call `name-service` when running locally?
- What will happen to `greeting-service` if `name-service` is not running?
- How would you override `name.service.url` with an environment variable?

👉 [Move to Phase 2: phase2-dockerfile/README.md](../phase2-dockerfile/README.md)

