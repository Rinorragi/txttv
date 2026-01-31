module MazeMessage

open Microsoft.Azure.Functions.Worker
open Microsoft.Azure.Functions.Worker.Http
open System.Net

[<Function("MazeMessage")>]
let run ([<HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "backend-test")>] req: HttpRequestData) =
    let response = req.CreateResponse(HttpStatusCode.OK)
    response.Headers.Add("Content-Type", "text/plain; charset=utf-8")
    response.WriteString("you found through the maze")
    response
