# AWS Customer Support Agent - Workshop

## Architecture Overview

```
                    +---------------------------+
                    |   Amazon Bedrock AgentCore |
                    |       (Runtime Host)       |
                    +---------------------------+
                              |
                    +---------v---------+
                    |  CustomerSupport   |
                    |    Agent (Strands) |
                    +---------+---------+
                              |
         +--------------------+--------------------+
         |                    |                    |
   +-----v-----+      +------v------+      +-----v-----+
   |   Tools    |      |  MCP Client |      |  Memory   |
   | - Return   |      | (Exa AI    |      | (AgentCore|
   |   Policy   |      |  Web Search)|      |  Memory)  |
   | - Product  |      +-------------+      +-----------+
   |   Info     |
   +-----------+
         |
   +-----v-----+
   |   Model    |
   | (Bedrock   |
   |  Claude    |
   |  Sonnet 4) |
   +-----------+
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Framework | Strands Agents SDK (Python) |
| Model | Claude Sonnet 4 via Amazon Bedrock (`global.anthropic.claude-sonnet-4-6`) |
| Runtime | Amazon Bedrock AgentCore (CodeZip, Python 3.14) |
| Memory | AgentCore Memory (Semantic + Summarization strategies) |
| External Tools | Exa AI MCP Server (web search) |
| Infrastructure | AWS CDK (`@aws/agentcore-cdk` L3 constructs) |
| Build Type | CodeZip (Python source packaged as zip) |
| Network Mode | PUBLIC |
| Protocol | HTTP |

## Project Structure

```
CustomerSupport/
├── AGENTS.md                          # AI assistant context
├── README.md                          # AgentCore project docs
├── WORKSHOP.md                        # This file - lab documentation
├── agentcore/
│   ├── agentcore.json                 # Project config (agent, memory)
│   ├── aws-targets.json               # Deployment target (account/region)
│   ├── .env.local                     # Secrets (gitignored)
│   ├── .llm-context/                  # TypeScript type definitions
│   └── cdk/                           # CDK infrastructure
└── app/
    └── CustomerSupport/
        ├── main.py                    # Agent entrypoint + tools
        ├── model/
        │   ├── load.py                # Bedrock model config
        │   └── mantle_compat.py       # OpenAI model compatibility
        ├── mcp_client/
        │   └── client.py             # Exa AI MCP client
        ├── memory/
        │   └── session.py            # AgentCore Memory session manager
        └── skills/
            └── fetcher.py            # S3/Git skill fetcher utility
```

---

## Lab 1: Project Setup & Agent Creation

**Objective:** Initialize the AgentCore project and scaffold the base customer support agent.

**What we did:**
- Created a new AgentCore project using the CLI (`agentcore create`)
- Selected the Strands framework with Python runtime
- Configured the project structure separating infrastructure (`agentcore/`) from application code (`app/`)
- Set up AWS deployment targets (account + region) in `aws-targets.json`
- Configured CDK infrastructure using `@aws/agentcore-cdk` L3 constructs

**Key files created:**
| File | Purpose |
|------|---------|
| `agentcore/agentcore.json` | Main project configuration (agents, memories, gateways) |
| `agentcore/aws-targets.json` | AWS account and region for deployment |
| `agentcore/cdk/` | CDK infrastructure project |
| `app/CustomerSupport/main.py` | Agent application entrypoint |
| `app/CustomerSupport/pyproject.toml` | Python dependencies |

**Commands used:**
```bash
agentcore create
agentcore dev        # Run locally with hot-reload
agentcore validate   # Verify configuration
```

---

## Lab 2: Integrating Memory with Session & User Identity

**Objective:** Wire up AgentCore Memory so the agent can remember context across sessions per user.

**What we did:**
- Imported the memory session manager into the main agent module
- Added `requestHeaderAllowlist` in `agentcore.json` to pass the custom user ID header (`X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id`) to the agent at runtime
- Modified `get_or_create_agent()` to accept `session_id` and `user_id` parameters
- Updated the invoke entrypoint to extract `session_id` from context and `user_id` from request headers
- Added validation to ensure both `session_id` and `user_id` are present before invoking the agent
- Extracted the system prompt to a module-level constant for cleaner code organization
- Passed the `session_manager` (from `memory/session.py`) into the Strands `Agent` constructor

**Key changes:**
| File | Change |
|------|--------|
| `agentcore/agentcore.json` | Added `requestHeaderAllowlist` with custom user ID header |
| `app/CustomerSupport/main.py` | Integrated memory session manager, user/session extraction from context |

**How it works:**
1. The caller passes `--session-id` and `--user-id` when invoking the agent
2. The custom user ID header is allowlisted so AgentCore Runtime forwards it to the app
3. The memory session manager is initialized with the session/user IDs
4. Memory strategies (SEMANTIC + SUMMARIZATION) store and retrieve per-user facts and conversation summaries
5. The agent now remembers previous interactions and personalizes responses

**Commands used:**
```bash
agentcore invoke --prompt "What headphones do you have?" --session-id my-session --user-id user123
```

---

## Lab 3: AgentCore Gateway — Connecting to AWS Lambda Tools

**Objective:** Connect the agent to an external AWS Lambda function via AgentCore Gateway, so the agent can call services it doesn't own.

**Why this matters:**

Before this lab, all tools were Python functions hardcoded in `main.py`. That works for simple cases, but in the real world:
- Tool logic may live in separate services (maintained by other teams)
- Tools may be written in different languages
- You want to add/remove tools without redeploying the agent

AgentCore Gateway solves this by acting as a **bridge** — it exposes external services (like AWS Lambda functions) as MCP tools that the agent automatically discovers and calls.

```
Before Lab 3:
  Agent → Python functions only (get_return_policy, get_product_info)

After Lab 3:
  Agent → Python functions (get_return_policy, get_product_info)
       → Gateway → AWS Lambda function (check_warranty)
```

> **Note:** "Lambda" here refers to **AWS Lambda** (a serverless compute service that runs your code in the cloud), NOT Python's `lambda x: x+1` syntax.

**What we did:**
- Created an AgentCore Gateway (`my-gateway`) in `agentcore.json`
- Added a Lambda target (`WarrantyCheck`) pointing to a pre-deployed AWS Lambda function
- Defined the tool schema in `warranty_schema.json` so the agent knows how to call it
- Created `get_gateway_mcp_client()` in `mcp_client/client.py` to connect to the gateway
- Added the gateway MCP client to the agent's tool list
- Removed `warranty_months` from the local product catalog (warranty is now handled by the Lambda)

**Key changes:**
| File | Change |
|------|--------|
| `agentcore/agentcore.json` | Added `agentCoreGateways` with Lambda target |
| `app/CustomerSupport/tool/warranty_schema.json` | NEW — Tool schema for `check_warranty` |
| `app/CustomerSupport/mcp_client/client.py` | Added `get_gateway_mcp_client()` |
| `app/CustomerSupport/main.py` | Imported gateway client, removed warranty_months from products |

**How it works:**
1. AgentCore deploys the Gateway and sets `AGENTCORE_GATEWAY_MY_GATEWAY_URL` env var at runtime
2. The agent connects to the gateway as an MCP client
3. The gateway exposes `check_warranty` as a discoverable tool (defined by the JSON schema)
4. When a customer asks about warranty, the agent calls `check_warranty` → Gateway → AWS Lambda
5. The Lambda function returns warranty status, and the agent relays it to the customer

**Commands used:**
```bash
agentcore add gateway
agentcore deploy
agentcore invoke --prompt "Is my Smart Watch still under warranty?" --session-id s1 --user-id user123
```

---

## Lab 4: Securing the Agent with JWT Authentication (Amazon Cognito)

**Objective:** Lock down the agent so only authenticated users can access it, and user identity is cryptographically verified (not self-reported).

**What was lacking before:**

In Labs 1-3, anyone could call the agent and claim to be any user by simply passing a header:
```bash
# Anyone could pretend to be Sarah — no verification!
-H "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id: Sarah"
```
This is insecure — a malicious caller could access another user's memories, warranty info, or personal data.

**What Lab 4 adds:**

```
Before Lab 4 (insecure):
  Client → "I'm Sarah" (self-reported header) → Agent trusts blindly

After Lab 4 (secure):
  Client → authenticates with Cognito → receives JWT token
        → sends token to Agent → Agent verifies token → extracts real username from claims
```

**Think of it like this:** Before, you could walk into a bank and say "I'm John, show me his account." Now you need to show a government-issued ID (the JWT token) that the bank (AgentCore) validates against the issuer (Cognito).

**What we did:**
- Added `CUSTOM_JWT` authorizer to the agent runtime — AgentCore now rejects requests without a valid token
- Configured Cognito as the identity provider (discovery URL + allowed client IDs)
- Secured the Gateway with the same JWT authorizer — Lambda tools also require auth
- Modified `main.py` to extract `user_id` from JWT claims (`username` field) instead of a custom header
- Gateway MCP client now forwards the `Authorization` header so tool calls are also authenticated
- Added `pyjwt` dependency for token decoding
- Downgraded runtime to Python 3.13 (compatibility)

**Key changes:**
| File | Change |
|------|--------|
| `agentcore/agentcore.json` | Added JWT authorizer to runtime + gateway, Cognito config |
| `app/CustomerSupport/main.py` | JWT-based user extraction, auth header forwarding |
| `app/CustomerSupport/mcp_client/client.py` | Gateway client passes Authorization header |
| `app/CustomerSupport/pyproject.toml` | Added `pyjwt` dependency |

**How it works:**
1. User authenticates with Amazon Cognito and receives a JWT access token
2. Client sends request with `Authorization: Bearer <token>` header
3. AgentCore Runtime validates the token against Cognito's OIDC discovery endpoint
4. Agent code decodes the JWT and extracts the `username` claim as `user_id`
5. Memory and tools now operate on a verified identity — no spoofing possible
6. Gateway also validates the token before allowing Lambda tool calls

**Commands used:**
```bash
# Get a token from Cognito first, then invoke with it:
agentcore invoke "What's my warranty status?" \
  --session-id $SESSION_ID \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  --stream
```

---

## Lab 5: Evaluating Agent Quality with Online Evaluations

**Objective:** Set up continuous quality monitoring so every agent interaction is automatically scored.

**What was lacking before:**

In Labs 1-4, the agent was deployed and secured — but you had no way to know if it was giving **good** answers. Was it picking the right tools? Were customers getting their problems solved? You'd have to manually read every conversation to find out.

**What Lab 5 adds:**

AgentCore Evaluations automatically scores your agent's interactions using LLM-as-a-Judge. It samples live sessions and rates them — no manual review needed.

```
Before Lab 5:
  Customer asks question → Agent answers → ??? (hope it was good)

After Lab 5:
  Customer asks question → Agent answers → Evaluators automatically score:
    - GoalSuccessRate: Did the agent solve the customer's problem?
    - Correctness: Was the information accurate?
    - ToolSelectionAccuracy: Did it pick the right tools?
```

**What we did:**
- Added an online evaluation config (`QualityMonitor`) that monitors the CustomerSupport agent
- Configured three built-in evaluators (GoalSuccessRate, Correctness, ToolSelectionAccuracy)
- Set sampling rate to 100% (every interaction evaluated; production would use 10-20%)
- Enabled evaluation immediately on deployment (`enableOnCreate: true`)
- Deployed and generated test interactions with varied queries (product info, return policy, warranty, multi-tool)

**Key changes:**
| File | Change |
|------|--------|
| `agentcore/agentcore.json` | Added `onlineEvalConfigs` with QualityMonitor |

**Score interpretation:**
| Score | Meaning | Action |
|-------|---------|--------|
| 80-100% | Excellent | Monitor and maintain |
| 60-80% | Good but improvable | Review low-scoring sessions |
| Below 60% | Needs attention | Investigate root causes |

**Commands used:**
```bash
# Add online eval config
agentcore add online-eval \
  --name QualityMonitor \
  --runtime CustomerSupport \
  --evaluator Builtin.GoalSuccessRate Builtin.Correctness Builtin.ToolSelectionAccuracy \
  --sampling-rate 100 \
  --enable-on-create

# Deploy
agentcore deploy -y -v

# Run on-demand evaluation
agentcore run eval \
  --runtime CustomerSupport \
  --evaluator Builtin.GoalSuccessRate Builtin.Correctness \
  --days 1
```

---

## Lab 6: Web Chat Frontend (Flask)

**Objective:** Build a web chat interface so users can interact with the agent through a browser instead of the terminal.

**What was lacking before:**

In Labs 1-5, the only way to talk to the agent was via `agentcore invoke` in the terminal with a bearer token. Real customers need a proper chat UI.

**What Lab 6 adds:**

```
Before Lab 6:
  Terminal → agentcore invoke --bearer-token ... → Agent

After Lab 6:
  Browser → Flask server (authenticates with Cognito on startup)
         → Serves HTML page with token + runtime ARN injected
         → Browser calls AgentCore REST API directly
         → Streaming response displayed in chat UI
```

**How it works:**
1. Flask server starts and authenticates with Cognito (same `USER_PASSWORD_AUTH` flow from Lab 4)
2. User opens the page — Flask injects the access token and runtime ARN into the HTML
3. User types a message in the chat
4. Browser calls the AgentCore REST API directly with `Authorization: Bearer` header
5. AgentCore validates the JWT, processes the request through the agent
6. Streaming response is displayed in the chat bubble

**What we created:**
| File | Purpose |
|------|---------|
| `app/CustomerSupport/frontend/__init__.py` | Package marker |
| `app/CustomerSupport/frontend/frontend.py` | Flask server — Cognito auth, serves chat page |
| `app/CustomerSupport/frontend/templates/index.html` | Chat UI — calls AgentCore API directly from browser |

**Key design decisions:**
- **Why not boto3?** boto3's `invoke_agent_runtime` uses IAM (SigV4) auth. Our runtime uses Custom JWT auth, so we call the REST API directly with a Bearer token.
- **Why Flask and not just a static page?** Flask handles Cognito authentication server-side on startup and injects the token into the page. The browser never sees credentials.
- **Session management:** Each browser tab gets a unique `sessionId` (UUID). Clicking "New Session" generates a fresh one, resetting conversation context.

**Dependencies added:** `flask`, `boto3`, `requests`

**Commands used:**
```bash
# Install dependencies
cd app/CustomerSupport
uv add flask boto3 requests

# Create frontend structure
mkdir -p app/CustomerSupport/frontend/templates

# Run the frontend
cd app/CustomerSupport/frontend
uv run python frontend.py
# Opens on http://localhost:8501
```

**Testing the UI:**
| Action | What it tests |
|--------|--------------|
| "What products do you have?" | Product lookup (local tool) |
| "What's the return policy for electronics?" | Return policy (local tool) |
| "Check warranty for PROD-002" | Warranty check (Gateway → Lambda) |
| "Do you remember me?" | Long-term memory recall |
| Send "My name is Alex" then "What's my name?" | Session persistence |
| Click New Session → "What's my name?" | Session isolation (won't remember) |
