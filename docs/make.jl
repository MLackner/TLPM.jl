push!(LOAD_PATH, joinpath(@__DIR__, ".."))

using Documenter
using DocumenterMarkdown
using TLPM

makedocs(
    sitename = "TLPM",
    format = DocumenterMarkdown.Markdown(),
    modules = [TLPM],
    pages = [
        "Installation" => "installation.md",
        "Examples" => "example.md",
        "API Reference" => [
            "Index" => "api_index.md",
            "Resources" => "api_resources.md",
            "Connection" => "api_connection.md",
            "Configuration" => "api_configuration.md",
            "Power Measurement" => "api_power_measurement.md",
            "Correction" => "api_correction.md",
            "Utility Funcitons" => "api_utility_functions.md",
            "User Power Calibration" => "api_user_power_calibration.md",
        ],
        "Developer Information" => "developer_information.md",
    ]
)

@info "Deploying documentation with MkDocs"
cd(@__DIR__)
run(`python -m mkdocs build`)
run(`python -m mkdocs gh-deploy`)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
# deploydocs(
#     repo = "github.com/MLackner/TLPM.jl.git",
#     deps = Deps.pip("mkdocs", "pygments", "python-markdown-math"),
#     make = () -> run(`mkdocs build`),
#     target = "site"
# )
