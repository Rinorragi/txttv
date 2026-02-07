# txttv

TXT TV done with APIM to showcase WAF capabilities in AppGW

## Architecture

```mermaid
flowchart TB
    subgraph Internet
        User[👤 User Browser]
    end

    subgraph Azure["☁️ Azure"]
        subgraph Frontend["Public Entry Point"]
            PIP[Public IP]
            AppGW[Application Gateway<br/>WAF_v2]
            WAF[WAF Policy<br/>OWASP CRS 3.2]
        end

        subgraph APILayer["API Management"]
            APIM[Azure APIM<br/>Developer Tier]
            subgraph Policies["Policy Fragments"]
                GlobalPolicy[Global Policy<br/>CORS, Headers]
                PageRouting[Page Routing<br/>Policy]
                Fragments[Page Fragments<br/>100-110]
            end
        end

        subgraph Backend["Backend Services"]
            Functions[Azure Functions<br/>F# .NET 10]
            MazeFunc[MazeMessage<br/>Function]
        end

        subgraph Storage["Storage"]
            Blob[Azure Blob Storage<br/>Content Files]
        end

        subgraph Monitoring["Monitoring"]
            AppInsights[Application<br/>Insights]
        end
    end

    User -->|HTTPS| PIP
    PIP --> AppGW
    WAF -.->|Protects| AppGW
    AppGW -->|Backend Pool| APIM
    APIM --> GlobalPolicy
    GlobalPolicy --> PageRouting
    PageRouting --> Fragments
    APIM -->|/backend-test| Functions
    Functions --> MazeFunc
    Blob -.->|Source Content| Fragments
    APIM -.->|Logs| AppInsights
    AppGW -.->|Logs| AppInsights

    style AppGW fill:#0078d4,color:#fff
    style WAF fill:#e74c3c,color:#fff
    style APIM fill:#68217a,color:#fff
    style Functions fill:#0062ad,color:#fff
    style Blob fill:#0078d4,color:#fff
```

## Components

| Component | SKU/Tier | Purpose |
|-----------|----------|---------|
| **Application Gateway** | WAF_v2 | Public entry point with WAF protection |
| **WAF Policy** | OWASP CRS 3.2 | SQL injection, XSS, rate limiting (100 req/min) |
| **API Management** | Developer | Policy-based HTML rendering (primary logic) |
| **Azure Functions** | Consumption (Y1) | Minimal F# backend for demo |
| **Blob Storage** | Standard_LRS | Content source files |
| **Application Insights** | - | Monitoring and diagnostics |

## Request Flow

1. **User** requests `/page/100` via browser
2. **Application Gateway** receives request, WAF validates against OWASP rules
3. **APIM** routes request through global policy → page routing policy
4. **Policy Fragment** (page-100.xml) returns pre-rendered HTML with HTMX
5. **Browser** renders teletext-style page with navigation controls

## Quick Start

```powershell
# Convert content to policy fragments
.\infrastructure\scripts\convert-txt-to-fragment.ps1

# Deploy infrastructure using deployment stack
az stack group create \
  --name txttv-dev-stack \
  --resource-group txttv-dev-rg \
  --template-file infrastructure/environments/dev/main.bicep \
  --parameters @infrastructure/environments/dev/parameters.json
```
