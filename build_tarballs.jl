# build_tarballs.jl
# BinaryBuilder.jl recipe for Tigre_jll (libtigre_julia)

using BinaryBuilder, Pkg

name = "Tigre"
version = v"2.7.0"

# Sources: CERN/TIGRE upstream archive and bundled Julia shims/overlays
sources = [
    ArchiveSource(
        "https://github.com/CERN/TIGRE/archive/81b6be2cc12ee630d36cba941e111ba14ba34c7c.tar.gz",
        "8e757c629982285a77d01e136f688ec3f659adb54bbfce91f48dc39f633fdc4a",
    ),
    DirectorySource("./bundled"),
]

# Bash script for building inside the BinaryBuilder container
script = raw"""
cd ${WORKSPACE}/srcdir

# 1. Locate TIGRE source root
TIGRE_DIR=$(find . -maxdepth 2 -name "TIGRE-*" -type d | head -n 1)
if [ -z "${TIGRE_DIR}" ]; then
    echo "ERROR: TIGRE source directory not found!"
    exit 1
fi
COMMON_DIR="${TIGRE_DIR}/Common/CUDA"

# 2. Apply overlay files to Common/CUDA
if [ -d "overlay" ]; then
    echo "Applying overlays to ${COMMON_DIR}..."
    cp -fv overlay/TIGRE_common.hpp "${COMMON_DIR}/"
    cp -fv overlay/TIGRE_common.cpp "${COMMON_DIR}/"
fi

# 3. Collect source files
UPSTREAM_SOURCES=(
    "${COMMON_DIR}/projection.cpp"
    "${COMMON_DIR}/TIGRE_common.cpp"
    "${COMMON_DIR}/GpuIds.cpp"
    "${COMMON_DIR}/gpuUtils.cu"
    "${COMMON_DIR}/Siddon_projection.cu"
    "${COMMON_DIR}/Siddon_projection_parallel.cu"
    "${COMMON_DIR}/ray_interpolated_projection.cu"
    "${COMMON_DIR}/ray_interpolated_projection_parallel.cu"
    "${COMMON_DIR}/voxel_backprojection.cu"
    "${COMMON_DIR}/voxel_backprojection2.cu"
    "${COMMON_DIR}/voxel_backprojection_parallel.cu"
    "${COMMON_DIR}/GD_TV.cu"
    "${COMMON_DIR}/GD_AwTV.cu"
    "${COMMON_DIR}/tv_proximal.cu"
    "${COMMON_DIR}/PICCS.cu"
)

WRAPPER_SOURCES=(
    "wrapper/src/tigre_julia_runtime.cpp"
    "wrapper/src/tigre_julia_shim.cpp"
)

# 4. Compiler setup and flags
NVCC="nvcc"
ARCH_FLAGS=(
    "-gencode=arch=compute_70,code=sm_70"
    "-gencode=arch=compute_75,code=sm_75"
    "-gencode=arch=compute_80,code=sm_80"
    "-gencode=arch=compute_86,code=sm_86"
    "-gencode=arch=compute_89,code=sm_89"
    "-gencode=arch=compute_90,code=sm_90"
    "-gencode=arch=compute_86,code=compute_86"
)

INCLUDE_FLAGS=(
    "-I${COMMON_DIR}"
    "-Iwrapper/include"
    "-I${prefix}/cuda/include"
    "-I${prefix}/include"
)

LIB_FLAGS=(
    "-L${prefix}/cuda/lib64"
    "-L${libdir}"
    "-lcudart"
)

mkdir -p "${libdir}"

# 5. Compile shared library
echo "Compiling libtigre_julia..."
${NVCC} --shared -O3 --std=c++14 \
    --expt-relaxed-constexpr \
    -Xcompiler=-fPIC \
    -Xlinker=--allow-multiple-definition \
    -DIS_FOR_JULIA_TIGRE \
    "${INCLUDE_FLAGS[@]}" \
    "${ARCH_FLAGS[@]}" \
    "${UPSTREAM_SOURCES[@]}" \
    "${WRAPPER_SOURCES[@]}" \
    "${LIB_FLAGS[@]}" \
    -o "${libdir}/libtigre_julia.${dlext}"

# 6. Install license files
install_license "${TIGRE_DIR}/LICENSE.txt"
"""

# Supported platforms: Linux x86_64 glibc
platforms = [
    Platform("x86_64", "linux"),
]
platforms = expand_cxx_dual_abi(platforms)

# Products
products = [
    LibraryProduct("libtigre_julia", :libtigre_julia),
]

# Dependencies: CUDA_SDK_jll at build time, CUDA_Runtime_jll at runtime
dependencies = [
    BuildDependency(PackageSpec(name="CUDA_SDK_jll")),
    Dependency(PackageSpec(name="CUDA_Runtime_jll")),
]

# Build execution
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
               julia_compat="1.6", preferred_gcc_version=v"10")
