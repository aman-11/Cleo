# mem0 Service Architecture

## SOLID Principles Implementation

This service follows SOLID principles for maintainability and testability:

### Directory Structure

```
services/mem0/
├── src/
│   ├── config/          # Configuration management
│   │   └── mem0_config.py
│   ├── models/          # Data transfer objects (Pydantic models)
│   │   └── memory.py
│   ├── repositories/    # Data access layer
│   │   └── memory_repository.py
│   ├── services/        # Business logic layer
│   │   └── memory_service.py
│   ├── routes/          # HTTP route definitions
│   │   └── memory_routes.py
│   ├── middleware/      # Cross-cutting concerns
│   │   └── auth.py
│   ├── utils/           # Shared utilities
│   │   └── logging_config.py
│   └── main.py          # Application entry point (Composition Root)
├── Dockerfile
└── requirements.txt
```

### SOLID Principles Applied

#### Single Responsibility Principle (SRP)
- **config/**: Only handles configuration building from environment
- **models/**: Only defines data structures
- **repositories/**: Only interacts with mem0 SDK
- **services/**: Only implements business logic
- **routes/**: Only defines HTTP endpoints
- **middleware/**: Only handles authentication

#### Open/Closed Principle (OCP)
- New memory operations can be added by extending `MemoryService` without modifying `MemoryRepository`
- New validation rules can be added to service layer without touching routes or repository

#### Liskov Substitution Principle (LSP)
- `MemoryRepository` could be swapped with a mock/fake implementation for testing
- All dependencies are injected via constructors

#### Interface Segregation Principle (ISP)
- Each module has focused, minimal interfaces
- Routes don't know about repository internals
- Services don't know about HTTP details

#### Dependency Inversion Principle (DIP)
- High-level modules (services, routes) depend on abstractions (repository interface)
- Dependencies flow inward: routes → services → repositories → mem0 client
- All dependencies are injected at the **Composition Root** (main.py)

### Dependency Injection Flow

```
main.py (Composition Root)
  ↓
  Creates mem0 client
  ↓
  Injects into MemoryRepository
  ↓
  Injects MemoryRepository into MemoryService
  ↓
  Injects MemoryService into create_memory_router()
  ↓
  Routes use service for all operations
```

### Benefits

1. **Testability**: Each layer can be tested in isolation with mocks
2. **Maintainability**: Changes to one layer don't cascade to others
3. **Readability**: Clear separation of concerns
4. **Extensibility**: Easy to add new features or swap implementations

### Running the Service

```bash
# Development (from services/mem0/)
uvicorn src.main:app --reload --port 8080

# Production (Docker)
docker build -t cleo-mem0 .
docker run -p 8080:8080 cleo-mem0
```

### API Endpoints

- `GET /` - Service info
- `GET /health` - Health check
- `POST /memories` - Add memory
- `GET /memories?query=...` - Search memories
- `GET /memories/all` - Get all memories
- `PUT /memories/{id}` - Update memory
- `DELETE /memories/{id}` - Delete memory

All endpoints (except health and root) require `X-API-Key` header if `MEM0_API_KEY` environment variable is set.
