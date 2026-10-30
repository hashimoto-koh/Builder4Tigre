# test/smoke.jl
# Smoke test for libtigre_julia: dlopen and safe query APIs.

using Libdl
using Test

function find_test_library()
    if haskey(ENV, "LIBTIGRE_PATH") && isfile(ENV["LIBTIGRE_PATH"])
        return ENV["LIBTIGRE_PATH"]
    end
    extracted = normpath(joinpath(@__DIR__, "..", "products", "extracted", "lib", "libtigre_julia.$(Libdl.dlext)"))
    if isfile(extracted)
        return extracted
    end
    local_prod = normpath(joinpath(@__DIR__, "..", "products", "libtigre_julia.$(Libdl.dlext)"))
    if isfile(local_prod)
        return local_prod
    end
    candidate = "/home/jov/git/prj/Tigre.jl/deps/usr/lib/libtigre_julia.$(Libdl.dlext)"
    if isfile(candidate)
        return candidate
    end
    return nothing
end

function test_smoke(libpath::String)
    println("Smoke testing library: $libpath")
    handle = Libdl.dlopen(libpath)
    try
        @testset "Basic C ABI Invocations" begin
            # 1. Error string query
            fn_err_str = Libdl.dlsym(handle, :tigre_julia_error_string)
            str_ptr = ccall(fn_err_str, Ptr{Cchar}, (Cint,), 0)
            @test str_ptr != C_NULL
            msg = unsafe_string(str_ptr)
            println("   Status 0 string: '$msg'")
            @test occursin("success", lowercase(msg))

            # 2. Clear last error
            fn_clear_err = Libdl.dlsym(handle, :tigre_julia_clear_last_error)
            ccall(fn_clear_err, Cvoid, ())

            # 3. Last error message (should be empty after clear)
            fn_last_err = Libdl.dlsym(handle, :tigre_julia_last_error_message)
            err_ptr = ccall(fn_last_err, Ptr{Cchar}, ())
            last_msg = err_ptr != C_NULL ? unsafe_string(err_ptr) : ""
            @test isempty(last_msg)

            # 4. GPU query
            fn_gpu_count = Libdl.dlsym(handle, :tigre_julia_get_gpu_count)
            gpu_cnt = ccall(fn_gpu_count, Cint, ())
            println("   Detected GPU count: $gpu_cnt")
            @test gpu_cnt >= 0

            if gpu_cnt > 0
                fn_gpu_name = Libdl.dlsym(handle, :tigre_julia_get_gpu_name)
                buf = zeros(UInt8, 256)
                status = ccall(fn_gpu_name, Cint, (Cint, Ptr{UInt8}, Csize_t), 0, buf, length(buf))
                @test status == 0
                name = unsafe_string(pointer(buf))
                println("   GPU 0 Name: $name")
                @test !isempty(name)
            end
        end
    finally
        Libdl.dlclose(handle)
    end
end

function main()
    libpath = find_test_library()
    if libpath === nothing
        println("⚠️ No libtigre_julia shared library found for smoke test.")
        println("   Skipping smoke test.")
        return
    end

    test_smoke(libpath)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
