namespace TxtTv.TestUtility

open System
open System.Text
open System.Text.Json
open System.Xml
open System.Xml.Linq

/// <summary>
/// Module for formatting HTTP responses for console display.
/// </summary>
module ResponseFormatter =

    /// <summary>
    /// ANSI color codes for console output.
    /// </summary>
    module private Colors =
        let reset = "\u001b[0m"
        let green = "\u001b[32m"
        let yellow = "\u001b[33m"
        let red = "\u001b[31m"
        let cyan = "\u001b[36m"
        let gray = "\u001b[90m"
        let bold = "\u001b[1m"

    /// <summary>
    /// Gets the appropriate color for an HTTP status code.
    /// </summary>
    let private getStatusColor statusCode =
        match statusCode with
        | code when code >= 200 && code < 300 -> Colors.green
        | code when code >= 300 && code < 400 -> Colors.cyan
        | code when code >= 400 && code < 500 -> Colors.yellow
        | code when code >= 500 -> Colors.red
        | _ -> Colors.gray

    /// <summary>
    /// Attempts to pretty-print JSON with indentation.
    /// Returns the original string if parsing fails.
    /// </summary>
    let private tryFormatJson (json: string) =
        try
            let jsonDoc = JsonDocument.Parse(json)
            let options = JsonSerializerOptions(WriteIndented = true)
            JsonSerializer.Serialize(jsonDoc, options)
        with
        | _ -> json

    /// <summary>
    /// Attempts to pretty-print XML with indentation.
    /// Returns the original string if parsing fails.
    /// </summary>
    let private tryFormatXml (xml: string) =
        try
            let doc = XDocument.Parse(xml)
            doc.ToString()
        with
        | _ -> xml

    /// <summary>
    /// Detects if content is JSON based on content type or content inspection.
    /// </summary>
    let private isJson (contentType: string option) (body: string) =
        match contentType with
        | Some ct when ct.Contains("json", StringComparison.OrdinalIgnoreCase) -> true
        | _ ->
            let trimmedBody = body.TrimStart()
            trimmedBody.StartsWith("{") || trimmedBody.StartsWith("[")

    /// <summary>
    /// Detects if content is XML based on content type or content inspection.
    /// </summary>
    let private isXml (contentType: string option) (body: string) =
        match contentType with
        | Some ct when ct.Contains("xml", StringComparison.OrdinalIgnoreCase) -> true
        | _ ->
            let trimmedBody = body.TrimStart()
            trimmedBody.StartsWith("<")

    /// <summary>
    /// Formats response headers as a table.
    /// </summary>
    let private formatHeaders (headers: Map<string, string>) =
        if Map.isEmpty headers then
            $"{Colors.gray}(No headers){Colors.reset}"
        else
            let maxKeyLength = headers |> Map.toSeq |> Seq.map (fun (k, _) -> k.Length) |> Seq.max
            let sb = StringBuilder()
            
            headers
            |> Map.iter (fun key value ->
                let paddedKey = key.PadRight(maxKeyLength)
                sb.AppendLine($"  {Colors.cyan}{paddedKey}{Colors.reset}: {value}") |> ignore)
            
            sb.ToString().TrimEnd()

    /// <summary>
    /// Formats the HTTP response body with syntax highlighting if possible.
    /// </summary>
    let private formatBody (headers: Map<string, string>) (body: string) =
        if String.IsNullOrWhiteSpace(body) then
            $"{Colors.gray}(Empty body){Colors.reset}"
        else
            let contentType = headers |> Map.tryFind "Content-Type"
            
            if isJson contentType body then
                tryFormatJson body
            elif isXml contentType body then
                tryFormatXml body
            else
                body

    /// <summary>
    /// Formats an HTTP response for console display.
    /// </summary>
    let formatResponse (response: HttpClient.HttpResponse) (includeHeaders: bool) (verbose: bool) =
        let sb = StringBuilder()
        
        // Status line
        let statusColor = getStatusColor response.StatusCode
        sb.AppendLine() |> ignore
        sb.AppendLine($"{Colors.bold}═══ HTTP Response ═══{Colors.reset}") |> ignore
        sb.AppendLine() |> ignore
        
        if response.IsSuccess then
            sb.AppendLine($"{Colors.bold}Status:{Colors.reset} {statusColor}{response.StatusCode} {response.StatusDescription}{Colors.reset}") |> ignore
        else
            match response.ErrorMessage with
            | Some errorMsg ->
                sb.AppendLine($"{Colors.bold}Status:{Colors.reset} {statusColor}Error{Colors.reset}") |> ignore
                sb.AppendLine($"{Colors.bold}Error:{Colors.reset} {Colors.red}{errorMsg}{Colors.reset}") |> ignore
            | None ->
                sb.AppendLine($"{Colors.bold}Status:{Colors.reset} {statusColor}{response.StatusCode} {response.StatusDescription}{Colors.reset}") |> ignore
        
        // Timing
        if verbose then
            sb.AppendLine($"{Colors.bold}Time:{Colors.reset} {response.ElapsedMilliseconds}ms") |> ignore
        
        // Headers
        if includeHeaders && not (Map.isEmpty response.Headers) then
            sb.AppendLine() |> ignore
            sb.AppendLine($"{Colors.bold}Headers:{Colors.reset}") |> ignore
            sb.AppendLine(formatHeaders response.Headers) |> ignore
        
        // Body
        if not (String.IsNullOrWhiteSpace(response.Body)) then
            sb.AppendLine() |> ignore
            sb.AppendLine($"{Colors.bold}Body:{Colors.reset}") |> ignore
            let formattedBody = formatBody response.Headers response.Body
            
            // Indent body content
            formattedBody.Split('\n')
            |> Array.iter (fun line -> sb.AppendLine($"  {line}") |> ignore)
        elif response.IsSuccess then
            sb.AppendLine() |> ignore
            sb.AppendLine($"{Colors.gray}(No response body){Colors.reset}") |> ignore
        
        sb.AppendLine() |> ignore
        sb.AppendLine($"{Colors.bold}═══════════════════{Colors.reset}") |> ignore
        
        sb.ToString()

    /// <summary>
    /// Formats a response summary (one-liner) for bulk operations.
    /// </summary>
    let formatResponseSummary (url: string) (response: HttpClient.HttpResponse) =
        let statusColor = getStatusColor response.StatusCode
        let statusIcon = if response.IsSuccess then "✓" else "✗"
        let timeStr = $"{response.ElapsedMilliseconds}ms"
        
        match response.ErrorMessage with
        | Some errorMsg ->
            $"{Colors.red}{statusIcon}{Colors.reset} {url} - {Colors.red}Error: {errorMsg}{Colors.reset}"
        | None ->
            $"{statusColor}{statusIcon}{Colors.reset} {url} - {statusColor}{response.StatusCode} {response.StatusDescription}{Colors.reset} ({Colors.gray}{timeStr}{Colors.reset})"

    /// <summary>
    /// Formats multiple responses as a summary table.
    /// </summary>
    let formatResponseBatch (responses: (string * HttpClient.HttpResponse) list) =
        let sb = StringBuilder()
        
        sb.AppendLine() |> ignore
        sb.AppendLine($"{Colors.bold}═══ Batch Request Summary ═══{Colors.reset}") |> ignore
        sb.AppendLine() |> ignore
        
        let successCount = responses |> List.filter (fun (_, r) -> r.IsSuccess) |> List.length
        let failCount = responses.Length - successCount
        
        responses
        |> List.iter (fun (url, response) ->
            sb.AppendLine(formatResponseSummary url response) |> ignore)
        
        sb.AppendLine() |> ignore
        sb.AppendLine($"{Colors.bold}Total:{Colors.reset} {responses.Length} requests") |> ignore
        sb.AppendLine($"{Colors.green}Success:{Colors.reset} {successCount}") |> ignore
        
        if failCount > 0 then
            sb.AppendLine($"{Colors.red}Failed:{Colors.reset} {failCount}") |> ignore
        
        sb.AppendLine() |> ignore
        sb.AppendLine($"{Colors.bold}════════════════════════════{Colors.reset}") |> ignore
        
        sb.ToString()
