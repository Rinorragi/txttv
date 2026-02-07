namespace TxtTv.TestUtility

open System
open System.Security.Cryptography
open System.Text

/// <summary>
/// Module for generating HMAC-SHA256 signatures for HTTP requests.
/// </summary>
module SignatureGenerator =

    /// <summary>
    /// Generates an HMAC-SHA256 signature for an HTTP request.
    /// </summary>
    /// <param name="key">Secret key for signing</param>
    /// <param name="method">HTTP method (GET, POST, etc.)</param>
    /// <param name="path">URL path including query string</param>
    /// <param name="body">Request body (optional)</param>
    /// <param name="timestamp">ISO 8601 timestamp</param>
    let generateSignature (key: string) (method: string) (path: string) (body: string option) (timestamp: string) : string =
        // Construct the string to sign
        let bodyStr = body |> Option.defaultValue ""
        let stringToSign = $"{method}\n{path}\n{timestamp}\n{bodyStr}"
        
        // Generate HMAC-SHA256 signature
        use hmac = new HMACSHA256(Encoding.UTF8.GetBytes(key))
        let hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(stringToSign))
        
        // Return Base64-encoded signature
        Convert.ToBase64String(hash)

    /// <summary>
    /// Generates a signature with query parameter sorting for consistency.
    /// </summary>
    let generateSignatureWithSortedQuery (key: string) (method: string) (url: string) (body: string option) (timestamp: string) : string =
        let uri = Uri(url)
        let path = uri.AbsolutePath
        
        // Parse and sort query parameters
        let queryParams =
            if String.IsNullOrEmpty(uri.Query) then
                ""
            else
                uri.Query.TrimStart('?').Split('&')
                |> Array.sort
                |> String.concat "&"
        
        let fullPath =
            if String.IsNullOrEmpty(queryParams) then
                path
            else
                $"{path}?{queryParams}"
        
        generateSignature key method fullPath body timestamp

    /// <summary>
    /// Gets the current timestamp in ISO 8601 format.
    /// </summary>
    let getCurrentTimestamp() : string =
        DateTime.UtcNow.ToString("o")

    /// <summary>
    /// Adds signature headers to a header map.
    /// </summary>
    let addSignatureHeaders (headers: Map<string, string>) (signature: string) (timestamp: string) (signatureHeader: string) : Map<string, string> =
        headers
        |> Map.add signatureHeader signature
        |> Map.add "X-TxtTV-Timestamp" timestamp
