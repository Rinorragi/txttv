namespace TxtTv.TestUtility

open System
open System.IO
open System.Text.Json

/// <summary>
/// Module for loading and parsing request definitions from JSON files.
/// </summary>
module RequestLoader =

    /// <summary>
    /// Represents a request definition loaded from a JSON file.
    /// </summary>
    type RequestDefinition = {
        Name: string
        Description: string option
        Method: string
        Url: string
        Headers: Map<string, string>
        Body: JsonElement option
        ExpectedBlocked: bool option
        WafRule: string option
    }

    /// <summary>
    /// Loads a request definition from a JSON file.
    /// </summary>
    let loadFromFile (filePath: string) : Result<RequestDefinition, string> =
        try
            if not (File.Exists(filePath)) then
                Error $"File not found: {filePath}"
            else
                let json = File.ReadAllText(filePath)
                let doc = JsonDocument.Parse(json)
                let root = doc.RootElement
                
                // Parse headers
                let headers =
                    let mutable headersElement = Unchecked.defaultof<JsonElement>
                    if root.TryGetProperty("headers", &headersElement) then
                        headersElement.EnumerateObject()
                        |> Seq.map (fun prop -> prop.Name, prop.Value.GetString())
                        |> Map.ofSeq
                    else
                        Map.empty
                
                // Parse body
                let body =
                    let mutable bodyElement = Unchecked.defaultof<JsonElement>
                    if root.TryGetProperty("body", &bodyElement) then
                        if bodyElement.ValueKind = JsonValueKind.Null then
                            None
                        else
                            Some bodyElement
                    else
                        None
                
                // Validate and parse required fields
                let nameResult =
                    let mutable nameElement = Unchecked.defaultof<JsonElement>
                    if root.TryGetProperty("name", &nameElement) then
                        let nameValue = nameElement.GetString()
                        if String.IsNullOrWhiteSpace(nameValue) then
                            Error "Required field 'name' is empty or null"
                        else
                            Ok nameValue
                    else
                        Error "Required field 'name' is missing"
                
                let methodResult =
                    let mutable methodElement = Unchecked.defaultof<JsonElement>
                    if root.TryGetProperty("method", &methodElement) then
                        let methodValue = methodElement.GetString()
                        if String.IsNullOrWhiteSpace(methodValue) then
                            Error "Required field 'method' is empty or null"
                        else
                            Ok methodValue
                    else
                        Error "Required field 'method' is missing"
                
                let urlResult =
                    let mutable urlElement = Unchecked.defaultof<JsonElement>
                    if root.TryGetProperty("url", &urlElement) then
                        let urlValue = urlElement.GetString()
                        if String.IsNullOrWhiteSpace(urlValue) then
                            Error "Required field 'url' is empty or null"
                        else
                            Ok urlValue
                    else
                        Error "Required field 'url' is missing"
                
                // Check for validation errors
                match nameResult, methodResult, urlResult with
                | Error e, _, _ -> Error e
                | _, Error e, _ -> Error e
                | _, _, Error e -> Error e
                | Ok name, Ok method, Ok url ->
                    let request = {
                        Name = name
                        Description =
                            let mutable descElement = Unchecked.defaultof<JsonElement>
                            if root.TryGetProperty("description", &descElement) then
                                let descValue = descElement.GetString()
                                if String.IsNullOrWhiteSpace(descValue) then None else Some descValue
                            else
                                None
                        Method = method
                        Url = url
                        Headers = headers
                        Body = body
                        ExpectedBlocked =
                            let mutable blockedElement = Unchecked.defaultof<JsonElement>
                            if root.TryGetProperty("expectedBlocked", &blockedElement) then
                                Some (blockedElement.GetBoolean())
                            else
                                None
                        WafRule =
                            let mutable ruleElement = Unchecked.defaultof<JsonElement>
                            if root.TryGetProperty("wafRule", &ruleElement) then
                                let ruleValue = ruleElement.GetString()
                                if String.IsNullOrWhiteSpace(ruleValue) then None else Some ruleValue
                            else
                                None
                    }
                    
                    Ok request
        with
        | ex -> Error $"Failed to load request file: {ex.Message}"

    /// <summary>
    /// Loads multiple request definitions from a directory.
    /// </summary>
    let loadFromDirectory (dirPath: string) (pattern: string) (recursive: bool) : Result<RequestDefinition list, string> =
        try
            if not (Directory.Exists(dirPath)) then
                Error $"Directory not found: {dirPath}"
            else
                let searchOption =
                    if recursive then
                        SearchOption.AllDirectories
                    else
                        SearchOption.TopDirectoryOnly
                
                let files = Directory.GetFiles(dirPath, pattern, searchOption)
                
                let results =
                    files
                    |> Array.map loadFromFile
                    |> Array.toList
                
                // Check for errors
                let errors =
                    results
                    |> List.choose (fun r ->
                        match r with
                        | Error e -> Some e
                        | Ok _ -> None)
                
                if errors.Length > 0 then
                    Error (String.concat "; " errors)
                else
                    let requests =
                        results
                        |> List.choose (fun r ->
                            match r with
                            | Ok req -> Some req
                            | Error _ -> None)
                    Ok requests
        with
        | ex -> Error $"Failed to load requests from directory: {ex.Message}"

    /// <summary>
    /// Converts a RequestDefinition body to a string.
    /// </summary>
    let bodyToString (body: JsonElement option) : string option =
        match body with
        | None -> None
        | Some element ->
            match element.ValueKind with
            | JsonValueKind.String -> Some (element.GetString())
            | JsonValueKind.Object | JsonValueKind.Array ->
                let options = JsonSerializerOptions(WriteIndented = false)
                Some (JsonSerializer.Serialize(element, options))
            | _ -> Some (element.ToString())
