# TxtTV Test Utility

F# console application for testing TxtTV HTTP endpoints with HMAC signature support.

## Installation

### Prerequisites
- .NET 10 SDK or later
- PowerShell 7+ (for running example scripts)

### Build from Source

```bash
cd tools/TxtTv.TestUtility
dotnet build --configuration Release
```

### Run Without Installing

```bash
dotnet run -- send -u "https://example.com" -m GET
```

### Install as Global Tool (Optional)

```bash
dotnet pack
dotnet tool install --global --add-source ./bin/Release TxtTv.TestUtility
```

Then use anywhere:

```bash
txttv-test send -u "https://example.com" -m GET
```

## Usage Examples

### Basic GET Request

```bash
dotnet run -- send \
  -u "https://your-apim.azure-api.net/pages/100" \
  -m GET \
  -v
```

### POST with JSON Body

```bash
dotnet run -- send \
  -u "https://your-apim.azure-api.net/backend-test" \
  -m POST \
  -b '{"message":"Hello","timestamp":"2026-02-07T10:00:00Z"}' \
  -v
```

### Request with HMAC Signature

```bash
dotnet run -- send \
  -u "https://your-apim.azure-api.net/backend-test" \
  -m POST \
  -b '{"data":"sensitive"}' \
  -k "your-secret-key" \
  -v
```

### Custom Headers

```bash
dotnet run -- send \
  -u "https://example.com/api" \
  -m GET \
  -h "Authorization: Bearer token123" \
  -h "X-Custom-Header: value" \
  -v
```

### Load Request from File

```bash
dotnet run -- load \
  -f "../../examples/requests/legitimate/get-page-100.json" \
  -k "your-secret-key" \
  -v
```

### Execute Batch of Requests

```bash
dotnet run -- load \
  -f "../../examples/requests/legitimate" \
  -k "your-secret-key" \
  -c
```

### Run WAF Tests

```bash
dotnet run -- load \
  -f "../../examples/requests/waf-tests" \
  -k "your-secret-key" \
  -c \
  -v
```

### List Available Request Files

```bash
dotnet run -- list -d "../../examples/requests" -r
```

## Command Reference

### Global Options

- `--help` - Show help information
- `--version` - Display version information

### `send` Command

Send a single HTTP request.

**Required:**
- `-u, --url <URL>` - Target URL

**Optional:**
- `-m, --method <METHOD>` - HTTP method (default: GET)
- `-b, --body <BODY>` - Request body content
- `-h, --header <HEADER>` - Custom header (repeatable)
- `-k, --signature-key <KEY>` - Secret key for HMAC-SHA256 signature
- `-s, --signature-header <NAME>` - Signature header name (default: X-TxtTV-Signature)
- `-v, --verbose` - Enable verbose output

**Examples:**
```bash
# Simple GET
dotnet run -- send -u "https://api.example.com/data" -m GET

# POST with signature
dotnet run -- send -u "https://api.example.com/data" -m POST -b '{"key":"value"}' -k "secret"

# Custom headers
dotnet run -- send -u "https://api.example.com/data" -h "Authorization: Bearer token" -h "X-API-Key: key"
```

### `load` Command

Load and execute request(s) from JSON file(s).

**Required:**
- `-f, --file <PATH>` - JSON file or directory path

**Optional:**
- `-k, --signature-key <KEY>` - Secret key for signing requests
- `-s, --signature-header <NAME>` - Signature header name (default: X-TxtTV-Signature)
- `-c, --continue-on-error` - Continue executing remaining requests on error
- `-v, --verbose` - Enable verbose output with full request/response details

**Examples:**
```bash
# Load single file
dotnet run -- load -f "request.json" -k "secret"

# Load all files from directory
dotnet run -- load -f "examples/requests/legitimate" -k "secret"

# Continue on error with verbose output
dotnet run -- load -f "examples/requests/waf-tests" -k "secret" -c -v
```

### `list` Command

List available request definition files.

**Optional:**
- `-d, --directory <PATH>` - Directory to search (default: examples/requests)
- `-p, --pattern <PATTERN>` - File pattern to match (default: *.json)
- `-r, --recursive` - Search subdirectories recursively

**Examples:**
```bash
# List all JSON files in default directory
dotnet run -- list

# List recursively
dotnet run -- list -r

# Search specific directory
dotnet run -- list -d "my-requests" -p "*.json" -r
```

## Request File Format

Request definition files are JSON documents with the following structure:

```json
{
  "name": "Request Name",
  "description": "Optional description",
  "method": "GET|POST|PUT|PATCH",
  "url": "https://example.com/api/endpoint",
  "headers": {
    "Header-Name": "Header-Value"
  },
  "body": "string body or JSON object",
  "expectedBlocked": false,
  "wafRule": "Optional WAF rule name"
}
```

**Field Descriptions:**

- `name` (required): Human-readable request name
- `description` (optional): Detailed description
- `method` (required): HTTP method (GET, POST, PUT, PATCH)
- `url` (required): Full target URL including query parameters
- `headers` (optional): Object containing custom HTTP headers
- `body` (optional): Request body - can be string or JSON object
- `expectedBlocked` (optional): For WAF tests - expect 403/429 response
- `wafRule` (optional): Name of WAF rule being tested

### Example: Simple GET Request

```json
{
  "name": "Get Page 100",
  "method": "GET",
  "url": "https://your-apim.azure-api.net/pages/100"
}
```

### Example: POST with JSON Body

```json
{
  "name": "Create Resource",
  "method": "POST",
  "url": "https://api.example.com/resources",
  "headers": {
    "Content-Type": "application/json"
  },
  "body": {
    "name": "Test Resource",
    "value": 42
  }
}
```

### Example: WAF Test

```json
{
  "name": "SQL Injection Test",
  "description": "Test SQL injection protection",
  "method": "GET",
  "url": "https://api.example.com/search?q=' OR '1'='1",
  "expectedBlocked": true,
  "wafRule": "SQL Injection Protection"
}
```

## HMAC Signature Generation

When a signature key is provided (`-k` option), the utility generates an HMAC-SHA256 signature and adds two headers:

1. `X-TxtTV-Signature` (or custom name via `-s`): Base64-encoded HMAC-SHA256 signature
2. `X-TxtTV-Timestamp`: ISO 8601 timestamp

**Signature Algorithm:**

```
string_to_sign = METHOD + "\n" + PATH + "\n" + TIMESTAMP + "\n" + BODY
signature = Base64(HMAC-SHA256(secret_key, string_to_sign))
```

Where:
- `METHOD`: Uppercase HTTP method (GET, POST, etc.)
- `PATH`: URL path with sorted query parameters
- `TIMESTAMP`: ISO 8601 UTC timestamp
- `BODY`: Request body (empty string for GET requests)

## Output Formatting

The utility provides color-coded, formatted output:

### Response Status Colors

- 🟢 **Green** (2xx): Successful responses
- 🔵 **Cyan** (3xx): Redirects
- 🟡 **Yellow** (4xx): Client errors
- 🔴 **Red** (5xx): Server errors

### JSON/XML Formatting

- **JSON**: Pretty-printed with indentation
- **XML**: Formatted with proper indentation
- **Plain text**: Displayed as-is

### Batch Summary

When loading multiple requests, a summary table shows:
- ✓ Successful requests (green)
- ✗ Failed requests (red)
- Response times
- Total counts

## Exit Codes

- `0`: Success - all requests completed successfully
- `1`: Error - one or more requests failed or error occurred

Use in scripts:

```bash
if dotnet run -- send -u "https://example.com" -m GET; then
    echo "Request succeeded"
else
    echo "Request failed"
fi
```

## Troubleshooting

### Build Errors

**Error: Cannot find .NET SDK**
```bash
# Install .NET 10 SDK from https://dot.net
dotnet --version
```

**Error: Missing dependencies**
```bash
cd tools/TxtTv.TestUtility
dotnet restore
dotnet build
```

### Runtime Errors

**Connection timeout**
- Check network connectivity
- Verify URL is correct
- Try increasing timeout (modify source)

**Signature verification failed**
- Ensure secret key matches server configuration
- Verify request body hasn't been modified
- Check server time synchronization

**Invalid JSON in request file**
- Validate JSON syntax: `jq . request.json`
- Check for trailing commas
- Ensure proper quote escaping

### Common Issues

**405 Method Not Allowed**
- Verify HTTP method is supported by endpoint
- Check API documentation

**403 Forbidden**
- May indicate WAF blocked request (expected for WAF tests)
- Check authentication/authorization
- Verify signature if required

**429 Too Many Requests**
- Rate limiting active
- Reduce request frequency
- Expected for rate limiting tests

## Development

### Project Structure

```
TxtTv.TestUtility/
├── CliArguments.fs          # Argu CLI argument parsing
├── SignatureGenerator.fs    # HMAC-SHA256 signature generation
├── RequestLoader.fs         # JSON request file loading
├── HttpClient.fs            # HTTP request execution
├── ResponseFormatter.fs     # Console output formatting
├── Program.fs               # Main entry point
└── TxtTv.TestUtility.fsproj # Project file
```

### Adding New Features

1. Define new types in appropriate module
2. Add functions following existing patterns
3. Update CLI arguments if needed
4. Add tests (see tests/utility/)
5. Update documentation

### Running Tests

```bash
cd tests/utility
dotnet test
```

## Dependencies

- **Argu 6.2.5**: Command-line argument parsing
- **FSharp.Data 6.6.0**: HTTP operations and data handling
- **System.Text.Json 10.0.2**: JSON parsing and serialization

## License

See LICENSE file in root directory.
