package com.example.greetingservice;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

@RestController
@RequestMapping("/api")
public class GreetingController {

    // The URL of name-service.
    //
    // Phase 1 (local):      http://localhost:8081  (set in application.yml)
    // Phase 3 (Kubernetes): http://name-service:8081  (set via env var in the Deployment YAML)
    // Phase 4 (Helm):       http://name-service:8081  (set via Helm values)
    //
    // Notice: the code never changes between phases.
    // Only the VALUE of this property changes. This is the key principle of
    // externalised configuration — the same binary runs everywhere.
    @Value("${name.service.url}")
    private String nameServiceUrl;

    // RestTemplate is a Spring HTTP client.
    // Modern Spring projects prefer RestClient (Spring 6.1+), but RestTemplate
    // is simpler to read and understand for learning purposes.
    private final RestTemplate restTemplate = new RestTemplate();

    /**
     * Calls name-service to get a name, then builds a greeting.
     * Example response: { "message": "Hello, Alice!" }
     */
    @GetMapping("/greet")
    public Map<String, String> greet() {
        // Step 1: call name-service at the configured URL
        @SuppressWarnings("unchecked")
        Map<String, String> nameResponse = restTemplate.getForObject(
                nameServiceUrl + "/api/name",
                Map.class
        );

        // Step 2: extract the name from the response
        String name = nameResponse != null ? nameResponse.get("name") : "stranger";

        // Step 3: build and return the greeting
        return Map.of("message", "Hello, " + name + "!");
    }

    /**
     * Health check endpoint.
     */
    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "UP", "service", "greeting-service");
    }
}

