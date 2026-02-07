namespace TxtTv.TestUtility

open System
open System.Net.Http
open System.Text
open System.Threading.Tasks

/// <summary>
/// HTTP client module for sending requests and handling responses.
/// </summary>
module HttpClient =

    /// <summary>
    /// Represents an HTTP request with all necessary details.
    /// </summary>
    type HttpRequest = {
        Url: string
        Method: HttpMethod
        Headers: Map<string, string>
        Body: string option
        ContentType: string option
        TimeoutSeconds: int
    }

    /// <summary>
    /// Represents an HTTP response with status, headers, and body.
    /// </summary>
    type HttpResponse = {
        StatusCode: int
        StatusDescription: string
        Headers: Map<string, string>
        Body: string
        IsSuccess: bool
        ErrorMessage: string option
        ElapsedMilliseconds: int64
    }

    /// <summary>
    /// Creates a default HTTP request with sensible defaults.
    /// </summary>
    let createDefaultRequest url method =
        {
            Url = url
            Method = method
            Headers = Map.empty
            Body = None
            ContentType = None
            TimeoutSeconds = 30
        }

    /// <summary>
    /// Creates an HttpClient with the specified timeout.
    /// </summary>
    let private createHttpClient timeoutSeconds =
        let client = new HttpClient()
        client.Timeout <- TimeSpan.FromSeconds(float timeoutSeconds)
        client

    /// <summary>
    /// Sends an HTTP GET request.
    /// </summary>
    let sendGetRequest (url: string) (headers: Map<string, string>) (timeoutSeconds: int) : Task<HttpResponse> =
        async {
            let stopwatch = System.Diagnostics.Stopwatch.StartNew()
            
            try
                use client = createHttpClient timeoutSeconds
                use request = new HttpRequestMessage(HttpMethod.Get, url)
                
                // Add custom headers
                headers
                |> Map.iter (fun key value ->
                    request.Headers.TryAddWithoutValidation(key, value) |> ignore)
                
                // Send request
                let! response = client.SendAsync(request) |> Async.AwaitTask
                let! responseBody = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                
                stopwatch.Stop()
                
                // Extract response headers
                let responseHeaders =
                    response.Headers
                    |> Seq.map (fun h -> h.Key, String.Join(", ", h.Value))
                    |> Map.ofSeq
                
                return {
                    StatusCode = int response.StatusCode
                    StatusDescription = response.ReasonPhrase
                    Headers = responseHeaders
                    Body = responseBody
                    IsSuccess = response.IsSuccessStatusCode
                    ErrorMessage = None
                    ElapsedMilliseconds = stopwatch.ElapsedMilliseconds
                }
            with
            | :? TaskCanceledException as ex ->
                stopwatch.Stop()
                return {
                    StatusCode = 0
                    StatusDescription = "Request Timeout"
                    Headers = Map.empty
                    Body = ""
                    IsSuccess = false
                    ErrorMessage = Some $"Request timed out after {timeoutSeconds} seconds"
                    ElapsedMilliseconds = stopwatch.ElapsedMilliseconds
                }
            | :? HttpRequestException as ex ->
                stopwatch.Stop()
                return {
                    StatusCode = 0
                    StatusDescription = "Network Error"
                    Headers = Map.empty
                    Body = ""
                    IsSuccess = false
                    ErrorMessage = Some $"Network error: {ex.Message}"
                    ElapsedMilliseconds = stopwatch.ElapsedMilliseconds
                }
            | ex ->
                stopwatch.Stop()
                return {
                    StatusCode = 0
                    StatusDescription = "Error"
                    Headers = Map.empty
                    Body = ""
                    IsSuccess = false
                    ErrorMessage = Some $"Unexpected error: {ex.Message}"
                    ElapsedMilliseconds = stopwatch.ElapsedMilliseconds
                }
        } |> Async.StartAsTask

    /// <summary>
    /// Sends an HTTP request with a body (POST, PUT, PATCH, etc.).
    /// </summary>
    let sendPostRequest (method: HttpMethod) (url: string) (headers: Map<string, string>) (body: string) (contentType: string) (timeoutSeconds: int) : Task<HttpResponse> =
        async {
            let stopwatch = System.Diagnostics.Stopwatch.StartNew()
            
            try
                use client = createHttpClient timeoutSeconds
                use request = new HttpRequestMessage(method, url)
                
                // Add custom headers
                headers
                |> Map.iter (fun key value ->
                    request.Headers.TryAddWithoutValidation(key, value) |> ignore)
                
                // Set request body
                request.Content <- new StringContent(body, Encoding.UTF8, contentType)
                
                // Send request
                let! response = client.SendAsync(request) |> Async.AwaitTask
                let! responseBody = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                
                stopwatch.Stop()
                
                // Extract response headers
                let responseHeaders =
                    response.Headers
                    |> Seq.map (fun h -> h.Key, String.Join(", ", h.Value))
                    |> Map.ofSeq
                    |> Map.fold (fun acc key value ->
                        // Also include content headers
                        Map.add key value acc) Map.empty
                
                // Add content headers if present
                let allHeaders =
                    if response.Content <> null then
                        response.Content.Headers
                        |> Seq.fold (fun acc h ->
                            Map.add h.Key (String.Join(", ", h.Value)) acc) responseHeaders
                    else
                        responseHeaders
                
                return {
                    StatusCode = int response.StatusCode
                    StatusDescription = response.ReasonPhrase
                    Headers = allHeaders
                    Body = responseBody
                    IsSuccess = response.IsSuccessStatusCode
                    ErrorMessage = None
                    ElapsedMilliseconds = stopwatch.ElapsedMilliseconds
                }
            with
            | :? TaskCanceledException as ex ->
                stopwatch.Stop()
                return {
                    StatusCode = 0
                    StatusDescription = "Request Timeout"
                    Headers = Map.empty
                    Body = ""
                    IsSuccess = false
                    ErrorMessage = Some $"Request timed out after {timeoutSeconds} seconds"
                    ElapsedMilliseconds = stopwatch.ElapsedMilliseconds
                }
            | :? HttpRequestException as ex ->
                stopwatch.Stop()
                return {
                    StatusCode = 0
                    StatusDescription = "Network Error"
                    Headers = Map.empty
                    Body = ""
                    IsSuccess = false
                    ErrorMessage = Some $"Network error: {ex.Message}"
                    ElapsedMilliseconds = stopwatch.ElapsedMilliseconds
                }
            | ex ->
                stopwatch.Stop()
                return {
                    StatusCode = 0
                    StatusDescription = "Error"
                    Headers = Map.empty
                    Body = ""
                    IsSuccess = false
                    ErrorMessage = Some $"Unexpected error: {ex.Message}"
                    ElapsedMilliseconds = stopwatch.ElapsedMilliseconds
                }
        } |> Async.StartAsTask

    /// <summary>
    /// Sends an HTTP request based on the HttpRequest record.
    /// </summary>
    let sendRequest (request: HttpRequest) : Task<HttpResponse> =
        match request.Method.Method.ToUpperInvariant() with
        | "GET" ->
            sendGetRequest request.Url request.Headers request.TimeoutSeconds
        | "POST" ->
            let body = request.Body |> Option.defaultValue ""
            let contentType = request.ContentType |> Option.defaultValue "application/json"
            sendPostRequest request.Method request.Url request.Headers body contentType request.TimeoutSeconds
        | "PUT" | "DELETE" | "PATCH" ->
            // For other methods, use a generic implementation similar to POST
            async {
                let stopwatch = System.Diagnostics.Stopwatch.StartNew()
                
                try
                    use client = createHttpClient request.TimeoutSeconds
                    use httpRequest = new HttpRequestMessage(request.Method, request.Url)
                    
                    // Add headers
                    request.Headers
                    |> Map.iter (fun key value ->
                        httpRequest.Headers.TryAddWithoutValidation(key, value) |> ignore)
                    
                    // Add body if present
                    match request.Body, request.ContentType with
                    | Some body, Some contentType ->
                        httpRequest.Content <- new StringContent(body, Encoding.UTF8, contentType)
                    | Some body, None ->
                        httpRequest.Content <- new StringContent(body, Encoding.UTF8, "application/json")
                    | None, _ -> ()
                    
                    // Send request
                    let! response = client.SendAsync(httpRequest) |> Async.AwaitTask
                    let! responseBody = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                    
                    stopwatch.Stop()
                    
                    let responseHeaders =
                        response.Headers
                        |> Seq.map (fun h -> h.Key, String.Join(", ", h.Value))
                        |> Map.ofSeq
                    
                    return {
                        StatusCode = int response.StatusCode
                        StatusDescription = response.ReasonPhrase
                        Headers = responseHeaders
                        Body = responseBody
                        IsSuccess = response.IsSuccessStatusCode
                        ErrorMessage = None
                        ElapsedMilliseconds = stopwatch.ElapsedMilliseconds
                    }
                with
                | ex ->
                    stopwatch.Stop()
                    return {
                        StatusCode = 0
                        StatusDescription = "Error"
                        Headers = Map.empty
                        Body = ""
                        IsSuccess = false
                        ErrorMessage = Some ex.Message
                        ElapsedMilliseconds = stopwatch.ElapsedMilliseconds
                    }
            } |> Async.StartAsTask
        | _ ->
            Task.FromResult {
                StatusCode = 0
                StatusDescription = "Invalid Method"
                Headers = Map.empty
                Body = ""
                IsSuccess = false
                ErrorMessage = Some $"Unsupported HTTP method: {request.Method.Method}"
                ElapsedMilliseconds = 0L
            }
