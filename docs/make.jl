push!(LOAD_PATH, joinpath(@__DIR__, ".."))

@show LOAD_PATH

using Documenter
using TLPM

makedocs(
    sitename = "TLPM",
    format = Documenter.HTML(),
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
        "Developer Information" => "developer_information.md"
    ]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "github.com/MLackner/TLPM.jl.git"
)
