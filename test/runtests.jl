# test/runtests.jl
# Master test suite for Builder4Tigre.

using Test
using TOML

println("=========================================")
println(" Running Builder4Tigre Test Suite")
println("=========================================\n")

include(joinpath(@__DIR__, "..", "sources", "verify_sources.jl"))
include(joinpath(@__DIR__, "symbols.jl"))
include(joinpath(@__DIR__, "smoke.jl"))

@testset "Builder4Tigre Tests" begin
    @testset "Source Manifest Verification" begin
        manifest = TOML.parsefile(MANIFEST_PATH)
        @test verify_bundled_files(manifest) == true
        @test verify_upstream_archive(manifest; download_if_missing = false) == true
    end

    @testset "C ABI Symbol & Smoke Tests" begin
        libpath = find_test_library()
        if libpath !== nothing
            println("Using library for tests: $libpath")
            test_symbols(libpath)
            test_smoke(libpath)
        else
            @test_skip "libtigre_julia not found on host"
        end
    end
end

println("\n=========================================")
println(" All Builder4Tigre Tests Finished")
println("=========================================")
