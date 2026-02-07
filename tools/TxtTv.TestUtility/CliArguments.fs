namespace TxtTv.TestUtility

open Argu

/// <summary>
/// Command-line arguments for the TxtTV Test Utility.
/// Defines three main commands: send, load, and list.
/// </summary>
module CliArguments =

    /// <summary>
    /// Arguments for the 'send' command to send a single HTTP request.
    /// </summary>
    type SendArgs =
        | [<Mandatory; AltCommandLine("-u")>] Url of url:string
        | [<AltCommandLine("-m")>] Method of method:string
        | [<AltCommandLine("-b")>] Body of body:string
        | [<AltCommandLine("-h")>] Header of header:string
        | [<AltCommandLine("-k")>] SignatureKey of key:string
        | [<AltCommandLine("-s")>] SignatureHeader of header:string
        | [<AltCommandLine("-v")>] Verbose

        interface IArgParserTemplate with
            member this.Usage =
                match this with
                | Url _ -> "Target URL to send the request to."
                | Method _ -> "HTTP method (GET, POST, PUT, DELETE). Default: GET"
                | Body _ -> "Request body content (for POST/PUT)."
                | Header _ -> "Additional HTTP header in 'Name: Value' format. Can be specified multiple times."
                | SignatureKey _ -> "Secret key for HMAC-SHA256 signature generation."
                | SignatureHeader _ -> "Header name for the signature. Default: X-TxtTV-Signature"
                | Verbose -> "Enable verbose output with detailed request/response information."

    /// <summary>
    /// Arguments for the 'load' command to load and execute request definitions from JSON files.
    /// </summary>
    type LoadArgs =
        | [<Mandatory; AltCommandLine("-f")>] File of file:string
        | [<AltCommandLine("-k")>] SignatureKey of key:string
        | [<AltCommandLine("-s")>] SignatureHeader of header:string
        | [<AltCommandLine("-v")>] Verbose
        | [<AltCommandLine("-c")>] ContinueOnError

        interface IArgParserTemplate with
            member this.Usage =
                match this with
                | File _ -> "Path to JSON file containing request definition(s)."
                | SignatureKey _ -> "Secret key for HMAC-SHA256 signature generation."
                | SignatureHeader _ -> "Header name for the signature. Default: X-TxtTV-Signature"
                | Verbose -> "Enable verbose output with detailed request/response information."
                | ContinueOnError -> "Continue executing remaining requests even if one fails."

    /// <summary>
    /// Arguments for the 'list' command to list available example request files.
    /// </summary>
    type ListArgs =
        | [<AltCommandLine("-d")>] Directory of directory:string
        | [<AltCommandLine("-p")>] Pattern of pattern:string
        | [<AltCommandLine("-r")>] Recursive

        interface IArgParserTemplate with
            member this.Usage =
                match this with
                | Directory _ -> "Directory to search for request files. Default: examples/requests/"
                | Pattern _ -> "File name pattern to match (e.g., '*.json'). Default: *.json"
                | Recursive -> "Search directories recursively."

    /// <summary>
    /// Top-level command structure for the CLI.
    /// Supports three main commands: send, load, and list.
    /// </summary>
    [<CliPrefix(CliPrefix.None)>]
    type CliCommand =
        | [<CliPrefix(CliPrefix.None)>] Send of ParseResults<SendArgs>
        | [<CliPrefix(CliPrefix.None)>] Load of ParseResults<LoadArgs>
        | [<CliPrefix(CliPrefix.None)>] List of ParseResults<ListArgs>
        | [<AltCommandLine("-V")>] Version

        interface IArgParserTemplate with
            member this.Usage =
                match this with
                | Send _ -> "Send a single HTTP request with optional signature."
                | Load _ -> "Load and execute request(s) from a JSON file."
                | List _ -> "List available example request files."
                | Version -> "Display version information."

    /// <summary>
    /// Creates and configures the Argu argument parser.
    /// </summary>
    let createParser() =
        ArgumentParser.Create<CliCommand>(
            programName = "txttv-test",
            helpTextMessage = "TxtTV Test Utility - Send HTTP requests with HMAC signatures",
            errorHandler = ProcessExiter())

    /// <summary>
    /// Parses command-line arguments and returns the parsed results.
    /// </summary>
    let parseArguments (args: string array) =
        let parser = createParser()
        parser.ParseCommandLine(args)
