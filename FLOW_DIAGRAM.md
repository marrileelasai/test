# Business Workspace Orchestration Flow

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          CLIENT (Postman/External System)                │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ POST /api/kafka-simulator/submission
                                 │ Body: { ESCAPE JSON payload }
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     KafkaConsumerRoute.java                              │
│  Route: netty-http://0.0.0.0:8084/api/kafka-simulator/submission        │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ 1. Receives POST request with JSON body                           │  │
│  │ 2. Logs incoming payload                                          │  │
│  │ 3. Passes body as-is to orchestration                            │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ .to("direct:orchestrate-business-workspace")
                                 │ Passes: ESCAPE JSON in body
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              WorkspaceOrchestrationRoute.java (Main Orchestrator)        │
│  Route: direct:orchestrate-business-workspace                            │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ Step 1: Store ESCAPE event                                        │  │
│  │         .setProperty("ESCAPE_EVENT", body())                      │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ .to("direct:authenticate-otcs")
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                   OtcsAuthenticationRoute.java                           │
│  Route: direct:authenticate-otcs                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ 1. Builds payload: username={{OTCS_USERNAME}}&password={{...}}   │  │
│  │ 2. Sets headers: Content-Type, Accept                            │  │
│  │ 3. POST to: {{OTCS_BASE_URL}}/api/v1/auth                       │  │
│  │                                                                   │  │
│  │    Request:                                                       │  │
│  │    POST https://otcs.../api/v1/auth                             │  │
│  │    Content-Type: application/x-www-form-urlencoded              │  │
│  │    Body: username=otadmin@otds.admin&password=EDMSAdmin...      │  │
│  │                                                                   │  │
│  │    Response:                                                      │  │
│  │    { "ticket": "ABC123XYZ..." }                                  │  │
│  │                                                                   │  │
│  │ 4. Extracts ticket using manual JSON parsing                     │  │
│  │ 5. Stores ticket in:                                             │  │
│  │    - Header: OTCSTicket                                          │  │
│  │    - Property: PROP_OTCS_TICKET                                  │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ Returns to orchestrator with ticket in header
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              WorkspaceOrchestrationRoute.java (continued)                │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ Step 2: Get category mapping                                      │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ .to("direct:get-category-mapping")
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              WorkspaceOrchestrationRoute.java (WebReport Call)           │
│  Route: direct:get-category-mapping                                      │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ 1. Uses ticket from header: ${header.OTCSTicket}                 │  │
│  │ 2. GET to: {{OTCS_BASE_URL}}/api/v1/webreports/...              │  │
│  │                                                                   │  │
│  │    Request:                                                       │  │
│  │    GET https://otcs.../api/v1/webreports/category_field_mapping  │  │
│  │    OTCSTicket: ABC123XYZ...                                      │  │
│  │                                                                   │  │
│  │    Response:                                                      │  │
│  │    { "data": [                                                   │  │
│  │        { "templateid": 123, "fieldname": "Account", ... },      │  │
│  │        { "templateid": 124, "fieldname": "LOB", ... }           │  │
│  │      ]                                                           │  │
│  │    }                                                             │  │
│  │                                                                   │  │
│  │ 3. Stores mapping in property: PROP_CATEGORY_MAPPING             │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ Returns to orchestrator
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              WorkspaceOrchestrationRoute.java (continued)                │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ Step 3: Map data to Business Workspace payload                    │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ .process(businessWorkspaceMapper)
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    BusinessWorkspaceMapper.java (Processor)              │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ Retrieves from exchange:                                          │  │
│  │   - ESCAPE event (property: ESCAPE_EVENT)                        │  │
│  │   - Category mapping (property: CATEGORY_MAPPING)                │  │
│  │                                                                   │  │
│  │ Transforms to Business Workspace payload:                         │  │
│  │   {                                                              │  │
│  │     "template_id": 12345,                                        │  │
│  │     "name": "Account 1580984-1 - test connection...",           │  │
│  │     "parent_id": 2000,                                           │  │
│  │     "roles": { ... },                                            │  │
│  │     "categories": {                                              │  │
│  │       "123": {  // mapped from category_field_mapping            │  │
│  │         "456": "1580984-1",  // Account Number from ESCAPE       │  │
│  │         "457": "PROP"         // LOB from ESCAPE                 │  │
│  │       }                                                          │  │
│  │     }                                                            │  │
│  │   }                                                              │  │
│  │                                                                   │  │
│  │ Sets this as new body for next step                             │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ Returns transformed payload to orchestrator
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              WorkspaceOrchestrationRoute.java (continued)                │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ Step 4: Create Business Workspace                                 │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ .to("direct:create-business-workspace")
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│         WorkspaceOrchestrationRoute.java (Workspace Creation)            │
│  Route: direct:create-business-workspace                                 │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ 1. Uses ticket from header: ${header.OTCSTicket}                 │  │
│  │ 2. POST to: {{OTCS_BASE_URL}}/api/v2/businessworkspaces         │  │
│  │                                                                   │  │
│  │    Request:                                                       │  │
│  │    POST https://otcs.../api/v2/businessworkspaces               │  │
│  │    OTCSTicket: ABC123XYZ...                                      │  │
│  │    Content-Type: application/json                                │  │
│  │    Body: { template_id: 12345, name: "...", ... }              │  │
│  │                                                                   │  │
│  │    Response (Success):                                           │  │
│  │    {                                                             │  │
│  │      "results": {                                                │  │
│  │        "data": {                                                 │  │
│  │          "properties": {                                         │  │
│  │            "id": 98765,                                          │  │
│  │            "name": "Account 1580984-1...",                      │  │
│  │            "create_date": "2026-03-03T23:45:00"                 │  │
│  │          }                                                       │  │
│  │        }                                                         │  │
│  │      }                                                           │  │
│  │    }                                                             │  │
│  │                                                                   │  │
│  │ 3. Validates response status (200/201 = success)                │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ Returns workspace creation response
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              WorkspaceOrchestrationRoute.java (Final Response)           │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ Sets HTTP 200 status                                              │  │
│  │ Returns workspace creation response to client                     │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          CLIENT receives response                        │
│  HTTP 200 OK                                                             │
│  {                                                                       │
│    "results": { "data": { "properties": { "id": 98765, ... } } }       │
│  }                                                                       │
└─────────────────────────────────────────────────────────────────────────┘
```

## Data Flow Summary

```
┌──────────────────┐
│  ESCAPE Event    │  Stored in exchange property throughout flow
│  (JSON payload)  │  Accessible via: ${exchangeProperty.ESCAPE_EVENT}
└──────────────────┘

┌──────────────────┐
│  OTCS Ticket     │  Generated once, reused for all API calls
│  (ABC123XYZ...)  │  Accessible via: ${header.OTCSTicket}
└──────────────────┘

┌──────────────────┐
│ Category Mapping │  Retrieved from WebReport, used by mapper
│  (Field IDs)     │  Accessible via: ${exchangeProperty.CATEGORY_MAPPING}
└──────────────────┘
```

## Key Components

| Component | Type | Purpose |
|-----------|------|---------|
| `KafkaConsumerRoute.java` | Entry Point | Receives POST request, forwards to orchestrator |
| `WorkspaceOrchestrationRoute.java` | Orchestrator | Coordinates 4-step workflow |
| `OtcsAuthenticationRoute.java` | **Reusable Auth** | Gets OTCS ticket (can be called from anywhere) |
| `BusinessWorkspaceMapper.java` | Processor | Maps ESCAPE data → Workspace payload |

## Reusability of Authentication

```
┌─────────────────────────────────────────────────────────────┐
│  Any Route Can Use Authentication                            │
│                                                              │
│  from("direct:my-custom-route")                             │
│      .to("direct:authenticate-otcs")  ← Reusable!          │
│      .log("Ticket: ${header.OTCSTicket}")                  │
│      .to("direct:call-any-otcs-api");                      │
└─────────────────────────────────────────────────────────────┘
```

## Error Handling

```
All routes handle errors gracefully:
├── Authentication fails (401) → Throws exception
├── WebReport fails (4xx/5xx) → Throws exception  
├── Workspace creation fails → Throws exception with specific error codes
└── Global exception handler returns JSON error response to client
```
