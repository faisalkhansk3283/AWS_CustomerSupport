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
