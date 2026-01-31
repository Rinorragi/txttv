module Program

open Microsoft.Azure.Functions.Worker
open Microsoft.Extensions.Hosting
open Microsoft.Extensions.DependencyInjection

[<EntryPoint>]
let main args =
    let host =
        HostBuilder()
            .ConfigureFunctionsWebApplication()
            .ConfigureServices(fun services ->
                services.AddApplicationInsightsTelemetryWorkerService() |> ignore
                services.ConfigureFunctionsApplicationInsights() |> ignore
            )
            .Build()
    
    host.Run()
    0
