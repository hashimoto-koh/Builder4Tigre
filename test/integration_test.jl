# test/integration_test.jl
# Full numerical regression test verifying Tigre.jl algorithms with Tigre_jll artifact on RTX 3090.

using Test
using Libdl

# Push Tigre.jl and Tigre_jll to LOAD_PATH without modifying Tigre.jl
pushfirst!(LOAD_PATH, "/home/jov/git/prj/Tigre.jl")
pushfirst!(LOAD_PATH, "/home/jov/.julia/dev/Tigre_jll")

using Tigre
import Tigre_jll

println("=======================================================")
println(" Tigre.jl + Tigre_jll Numerical Integration Tests")
println("=======================================================\n")

# Verify Tigre_jll is available
@test Tigre_jll.is_available() == true
artifact_lib = Tigre_jll.libtigre_julia_path
println("Artifact library: $artifact_lib")
@test isfile(artifact_lib)

# Point Tigre's internal handle directly to the Tigre_jll artifact
# This tests the artifact with 0 modifications to Tigre.jl repository!
Tigre._NATIVE_HANDLE[] = Libdl.dlopen(artifact_lib)
println("Configured Tigre._NATIVE_HANDLE to use Tigre_jll artifact.\n")

# Include regression reference fixtures from Tigre.jl
include("/home/jov/git/prj/Tigre.jl/test/regression_fixtures.jl")

# Helper functions identical to Tigre.jl/test/runtests.jl
import LinearAlgebra: norm

function volume_signature(x::AbstractArray{Float32, 3})
    return (
        sum = Float32(sum(x)),
        norm = Float32(norm(vec(x))),
        min = Float32(minimum(x)),
        max = Float32(maximum(x)),
        samples = Float32[
            x[1, 1, 1],
            x[2, 2, 2],
            x[3, 2, 1],
            x[1, 4, 3],
            x[4, 4, 4],
            x[2, 3, 4],
        ],
    )
end

function projection_signature(x::AbstractArray{Float32, 3})
    return (
        sum = Float32(sum(x)),
        norm = Float32(norm(vec(x))),
        min = Float32(minimum(x)),
        max = Float32(maximum(x)),
        samples = Float32[
            x[1, 1, 1],
            x[2, 3, 1],
            x[4, 2, 2],
            x[8, 6, 2],
            x[3, 5, 4],
            x[7, 1, 4],
        ],
    )
end

function assert_signature_matches(actual, expected; atol::Float32 = 1.0f-5, rtol::Float32 = 1.0f-5)
    @test isapprox(actual.sum, expected.sum; atol = atol, rtol = rtol)
    @test isapprox(actual.norm, expected.norm; atol = atol, rtol = rtol)
    @test isapprox(actual.min, expected.min; atol = atol, rtol = rtol)
    @test isapprox(actual.max, expected.max; atol = atol, rtol = rtol)
    for (a, e) in zip(actual.samples, expected.samples)
        @test isapprox(a, e; atol = atol, rtol = rtol)
    end
end

@testset "Tigre_jll Numerical Regression Suite" begin
    # Geometry configurations
    reg_geo = Geometry(
        angles = Float32[0, 0.35, 0.9, 1.4],
        nVoxel = (4, 4, 4),
        sVoxel = (40f0, 40f0, 40f0),
        nDetector = (8, 6),
        sDetector = (80f0, 60f0),
        DSO = 1000f0,
        DSD = 1200f0,
    )

    wang_geo = Geometry(
        mode = :cone,
        angles = Float32[0, 0.35, 0.9, 1.4],
        nVoxel = (4, 4, 4),
        sVoxel = (40f0, 40f0, 40f0),
        nDetector = (8, 6),
        sDetector = (80f0, 60f0),
        DSO = 1000f0,
        DSD = 1200f0,
        offDetector = [10f0, 0f0],
    )

    par_geo = Geometry(
        mode = :parallel,
        angles = Float32[0, 0.35, 0.9, 1.4],
        nVoxel = (4, 4, 4),
        sVoxel = (40f0, 40f0, 40f0),
        nDetector = (8, 6),
        sDetector = (80f0, 60f0),
        DSO = 1000f0,
        DSD = 1200f0,
    )

    phantom = zeros(Float32, volume_size(reg_geo)...)
    phantom[2, 2, 2] = 1f0
    phantom[3, 2, 1] = 0.5f0
    phantom[1, 4, 3] = 0.25f0
    phantom[2, 3, 4] = 0.75f0
    prior = fill(0.125f0, volume_size(reg_geo)...)

    par_phantom = zeros(Float32, volume_size(par_geo)...)
    par_phantom[2, 2, 2] = 1f0
    par_phantom[3, 2, 1] = 0.5f0
    par_phantom[1, 4, 3] = 0.25f0
    par_phantom[2, 3, 4] = 0.75f0

    @testset "Ax (Forward Projection)" begin
        proj = Ax(phantom, reg_geo)
        assert_signature_matches(projection_signature(proj), REGRESSION_REFERENCE.ax)
        println("✅ Ax signature matches REGRESSION_REFERENCE.ax")
    end

    @testset "Atb (Backprojection)" begin
        proj = Ax(phantom, reg_geo)
        back = Atb(proj, reg_geo)
        assert_signature_matches(volume_signature(back), REGRESSION_REFERENCE.atb)
        println("✅ Atb signature matches REGRESSION_REFERENCE.atb")
    end

    @testset "FDK Reconstruction" begin
        fdk_proj = Ax(phantom, wang_geo)
        fdk_vol = fdk(fdk_proj, wang_geo; filter = :hann)
        assert_signature_matches(volume_signature(fdk_vol), REGRESSION_REFERENCE.fdk_hann_wang)
        println("✅ FDK signature matches REGRESSION_REFERENCE.fdk_hann_wang")
    end

    @testset "SART Reconstruction" begin
        proj = Ax(phantom, reg_geo)
        sart_vol = sart(proj, reg_geo, 1)
        assert_signature_matches(volume_signature(sart_vol), REGRESSION_REFERENCE.sart)
        println("✅ SART signature matches REGRESSION_REFERENCE.sart")
    end

    @testset "FISTA Reconstruction (with TV)" begin
        proj = Ax(phantom, reg_geo)
        fista_vol = fista(proj, reg_geo, 1; tviter = 1)
        assert_signature_matches(volume_signature(fista_vol), REGRESSION_REFERENCE.fista)
        println("✅ FISTA signature matches REGRESSION_REFERENCE.fista")
    end

    @testset "LSMR Reconstruction" begin
        proj = Ax(phantom, reg_geo)
        lsmr_vol = lsmr(proj, reg_geo, 1)
        assert_signature_matches(volume_signature(lsmr_vol), REGRESSION_REFERENCE.lsmr)
        println("✅ LSMR signature matches REGRESSION_REFERENCE.lsmr")
    end

    @testset "Hybrid FLSQR TV Reconstruction" begin
        proj = Ax(phantom, reg_geo)
        hybrid_tv_vol = hybrid_flsqr_tv(proj, reg_geo, 1; lambda = 0.1f0, precond_steps = 2)
        assert_signature_matches(volume_signature(hybrid_tv_vol), REGRESSION_REFERENCE.hybrid_flsqr_tv)
        println("✅ Hybrid FLSQR TV signature matches REGRESSION_REFERENCE.hybrid_flsqr_tv")
    end

    @testset "PICCS Reconstruction" begin
        proj = Ax(phantom, reg_geo)
        piccs_vol = piccs(proj, reg_geo, prior, 1; tviter = 1, prior_ratio = 0.5f0)
        assert_signature_matches(volume_signature(piccs_vol), REGRESSION_REFERENCE.piccs)
        println("✅ PICCS signature matches REGRESSION_REFERENCE.piccs")
    end

    @testset "Parallel FBP Reconstruction" begin
        par_proj = Ax(par_phantom, par_geo)
        fbp_vol = fbp(par_proj, par_geo; filter = :hann)
        assert_signature_matches(volume_signature(fbp_vol), REGRESSION_REFERENCE.fbp_hann)
        println("✅ Parallel FBP signature matches REGRESSION_REFERENCE.fbp_hann")
    end

    @testset "MLEM Reconstruction" begin
        proj = Ax(phantom, reg_geo)
        mlem_vol = mlem(proj, reg_geo, 1)
        assert_signature_matches(volume_signature(mlem_vol), REGRESSION_REFERENCE.mlem)
        println("✅ MLEM signature matches REGRESSION_REFERENCE.mlem")
    end

    @testset "PCSD Reconstruction" begin
        proj = Ax(phantom, reg_geo)
        pcsd_vol = pcsd(proj, reg_geo, 1; tviter = 1)
        assert_signature_matches(volume_signature(pcsd_vol), REGRESSION_REFERENCE.pcsd; atol = 2f-4)
        println("✅ PCSD signature matches REGRESSION_REFERENCE.pcsd")
    end

    @testset "AwPCSD Reconstruction" begin
        proj = Ax(phantom, reg_geo)
        aw_pcsd_vol = aw_pcsd(proj, reg_geo, 1; tviter = 1)
        assert_signature_matches(volume_signature(aw_pcsd_vol), REGRESSION_REFERENCE.aw_pcsd; atol = 2f-4)
        println("✅ AwPCSD signature matches REGRESSION_REFERENCE.aw_pcsd")
    end
end

println("\n=======================================================")
println(" All Tigre.jl + Tigre_jll Numerical Tests PASSED!")
println("=======================================================")
