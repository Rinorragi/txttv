open System
open System.Net.Http
open Argu
open TxtTv.TestUtility.CliArguments
open TxtTv.TestUtility.SignatureGenerator
open TxtTv.TestUtility.RequestLoader
open TxtTv.TestUtility.HttpClient
open TxtTv.TestUtility.ResponseFormatter

/// <summary>
/// Handles the 'send' command to send a single HTTP request.
/// </summary>
let handleSendCommand (args: ParseResults<SendArgs>) =
    async {
        // Extract arguments
        let url = args.GetResult(SendArgs.Url)
        let method = args.GetResult(SendArgs.Method, defaultValue = "GET").ToUpperInvariant()
        let body = args.TryGetResult(SendArgs.Body)
        let signatureKey = args.TryGetResult(SendArgs.SignatureKey)
        let signatureHeader = args.GetResult(SendArgs.SignatureHeader, defaultValue = "X-TxtTV-Signature")
        let verbose = args.Contains(SendArgs.Verbose)
        
        // Parse headers from command line
        let mutable headers =
            args.GetResults(SendArgs.Header)
            |> List.fold (fun (acc: Map<string, string>) headerStr ->
                match headerStr.Split(':', 2) with
                | [| key; value |] -> Map.add (key.Trim()) (value.Trim()) acc
                | _ ->
                    eprintfn $"Warning: Invalid header format: {headerStr}"
                    acc
            ) Map.empty
        
        // Add signature if key provided
        match signatureKey with
        | Some key ->
            let timestamp = getCurrentTimestamp()
            let signature = generateSignatureWithSortedQuery key method url body timestamp
            headers <- addSignatureHeaders headers signature timestamp signatureHeader
            
            if verbose then
                printfn $"Added signature: {signature}"
                printfn $"Timestamp: {timestamp}"
        | None -> ()
        
        if verbose then
            printfn $"Sending {method} request to: {url}"
        
        // Create HTTP method
        let httpMethod = new HttpMethod(method)
        
        // Send request based on method
        let! response =
            match method with
            | "GET" ->
                sendGetRequest url headers 30 |> Async.AwaitTask
            | "POST" | "PUT" | "PATCH" ->
                let requestBody = body |> Option.defaultValue ""
                let contentType =
                    if requestBody.TrimStart().StartsWith("<") then
                        "application/xml"
                    else
                        "application/json"
                
                sendRequestWithBody httpMethod url headers requestBody contentType 30 |> Async.AwaitTask
            | _ ->
                eprintfn $"Error: Unsupported HTTP method: {method}"
                exit 1
        
        // Format and display response
        let formatted = formatResponse response true verbose
        printfn "%s" formatted
        
        // Return appropriate exit code
        return if response.IsSuccess then 0 else 1
    }

/// <summary>
/// Handles the 'list' command to list available example request files.
/// </summary>
let handleListCommand (args: ParseResults<ListArgs>) =
    async {
        let directory = args.GetResult(ListArgs.Directory, defaultValue = "examples/requests")
        let pattern = args.GetResult(ListArgs.Pattern, defaultValue = "*.json")
        let recursive = args.Contains(ListArgs.Recursive)
        
        printfn "\n=== Available Request Files ===\n"
        
        try
            let searchOption =
                if recursive then
                    IO.SearchOption.AllDirectories
                else
                    IO.SearchOption.TopDirectoryOnly
            
            let files = IO.Directory.GetFiles(directory, pattern, searchOption)
            
            if files.Length = 0 then
                printfn $"No files found matching '{pattern}' in '{directory}'"
                return 1
            else
                files
                |> Array.iter (fun file ->
                    let relativePath = IO.Path.GetRelativePath(directory, file)
                    printfn $"  • {relativePath}")
                
                printfn $"\nTotal files: {files.Length}"
                return 0
        with
        | ex ->
            eprintfn $"Error listing files: {ex.Message}"
            return 1
    }

/// <summary>
/// Handles the 'load' command to load and execute requests from JSON files.
/// </summary>
let handleLoadCommand (args: ParseResults<LoadArgs>) =
    async {
        let filePath = args.GetResult(LoadArgs.File)
        let signatureKey = args.TryGetResult(LoadArgs.SignatureKey)
        let signatureHeader = args.GetResult(LoadArgs.SignatureHeader, defaultValue = "X-TxtTV-Signature")
        let verbose = args.Contains(LoadArgs.Verbose)
        let continueOnError = args.Contains(LoadArgs.ContinueOnError)
        
        if verbose then
            printfn $"Loading request from: {filePath}"
        
        // Check if path is a file or directory
        let isDirectory = IO.Directory.Exists(filePath)
        let isFile = IO.File.Exists(filePath)
        
        let requestsResult =
            if isDirectory then
                loadFromDirectory filePath "*.json" false
            elif isFile then
                match loadFromFile filePath with
                | Ok req -> Ok [req]
                | Error e -> Error e
            else
                Error $"Path not found: {filePath}"
        
        match requestsResult with
        | Error err ->
            eprintfn $"Error loading requests: {err}"
            return 1
        | Ok requests ->
            printfn $"\nLoaded {requests.Length} request(s)\n"
            
            let mutable responses = []
            let mutable failCount = 0
            let mutable shouldStop = false
            
            for request in requests do
                if not shouldStop then
                    printfn $"Executing: {request.Name}"
                    if verbose && request.Description.IsSome then
                        printfn $"  {request.Description.Value}"
                    
                    try
                        // Build headers
                        let mutable headers = request.Headers
                        
                        // Add signature if key provided
                        match signatureKey with
                        | Some key ->
                            let timestamp = getCurrentTimestamp()
                            let bodyStr = bodyToString request.Body
                            let signature = generateSignatureWithSortedQuery key request.Method request.Url bodyStr timestamp
                            headers <- addSignatureHeaders headers signature timestamp signatureHeader
                        | None -> ()
                        
                        // Execute request
                        let! response =
                            match request.Method.ToUpperInvariant() with
                            | "GET" ->
                                sendGetRequest request.Url headers 30 |> Async.AwaitTask
                            | "POST" | "PUT" | "PATCH" ->
                                let bodyStr = bodyToString request.Body |> Option.defaultValue ""
                                let contentType =
                                    match headers.TryFind "Content-Type" with
                                    | Some ct -> ct
                                    | None ->
                                        if bodyStr.TrimStart().StartsWith("<") then
                                            "application/xml"
                                        else
                                            "application/json"
                                
                                let requestMethod = new HttpMethod(request.Method)
                                sendRequestWithBody requestMethod request.Url headers bodyStr contentType 30 |> Async.AwaitTask
                            | method ->
                                eprintfn $"Error: Unsupported HTTP method: {method}"
                                exit 1
                        
                        responses <- (request.Url, response) :: responses
                        
                        // Check if WAF test
                        match request.ExpectedBlocked, request.WafRule with
                        | Some true, Some rule ->
                            if response.StatusCode = 403 || response.StatusCode = 429 then
                                printfn $"  ✓ WAF blocked as expected ({rule})"
                            else
                                printfn $"  ⚠ WARNING: Expected WAF to block this request ({rule})"
                                failCount <- failCount + 1
                        | _ ->
                            if response.IsSuccess then
                                printfn $"  ✓ {response.StatusCode} {response.StatusDescription} ({response.ElapsedMilliseconds}ms)"
                            else
                                printfn $"  ✗ {response.StatusCode} {response.StatusDescription}"
                                failCount <- failCount + 1
                                if not continueOnError then
                                    printfn "\nStopping execution due to error. Use --continue-on-error to continue."
                                    shouldStop <- true
                        
                        if verbose then
                            let formatted = formatResponse response true true
                            printfn "%s" formatted
                        
                    with ex ->
                        eprintfn $"  ✗ Error: {ex.Message}"
                        failCount <- failCount + 1
                        if not continueOnError then
                            shouldStop <- true
            
            // Print summary
            let formatted = formatResponseBatch (List.rev responses)
            printfn "%s" formatted
            
            return if failCount = 0 then 0 else 1
    }

[<EntryPoint>]
let main argv =
    try
        let parser = createParser()
        let results = parser.ParseCommandLine(argv)
        
        let exitCode =
            match results.GetSubCommand() with
            | Send sendArgs ->
                handleSendCommand sendArgs |> Async.RunSynchronously
            | List listArgs ->
                handleListCommand listArgs |> Async.RunSynchronously
            | Load loadArgs ->
                handleLoadCommand loadArgs |> Async.RunSynchronously
            | Version ->
                printfn "TxtTV Test Utility v1.0.0"
                printfn ".NET 10 / F# 9"
                0
        
        exitCode
    with
    | :? ArguParseException as ex ->
        eprintfn "%s" ex.Message
        1
    | ex ->
        eprintfn $"Error: {ex.Message}"
        if Environment.GetEnvironmentVariable("VERBOSE") = "1" then
            eprintfn $"Stack trace:\n{ex.StackTrace}"
        1

