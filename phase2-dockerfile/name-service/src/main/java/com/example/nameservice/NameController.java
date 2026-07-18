package com.example.nameservice;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.Random;

@RestController
@RequestMapping("/api")
public class NameController {

    // A fixed list of names the service randomly picks from.
    // In a real service this would come from a database.
    private static final List<String> NAMES = List.of(
            "Alice", "Bob", "Charlie", "Diana", "Eve", "Frank"
    );

    private final Random random = new Random();

    /**
     * Returns a randomly chosen name.
     * Example response: { "name": "Alice" }
     */
    @GetMapping("/name")
    public Map<String, String> getName() {
        String name = NAMES.get(random.nextInt(NAMES.size()));
        return Map.of("name", name);
    }

    /**
     * Health check endpoint.
     * Kubernetes will use a similar endpoint to decide if the Pod is healthy.
     */
    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "UP", "service", "name-service");
    }
}

