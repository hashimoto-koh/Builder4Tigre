# C ABI 契約仕様書 (docs/abi-contract.md)

本仕様書は、Julia パッケージ `Tigre.jl` とネイティブ共有ライブラリ `libtigre_julia` の間の C ABI 契約を規定する。

---

## 1. 基本原則

1. **純粋な C ABI (`extern "C"`)**:
   - すべての公開関数は `extern "C"` で宣言され、C++ 名前マングリングを行わない。
   - 呼び出し規約はターゲットプラットフォームの標準 C 呼び出し規約（Linux x86_64 では System V AMD64 ABI）に従う。

2. **例外境界の完全保護**:
   - C++ 例外（`std::exception`、CUDA ランタイム例外、内部 throw）はいかなる場合も C ABI 境界を越えてはならない。
   - すべての shim 関数は最上位で `try ... catch` を行い、エラー発生時は整数ステータスコードを返し、エラーメッセージを内部スレッドローカルバッファに退避する。

3. **メモリ所有権**:
   - ボリューム配列（`volume`）および投影データ配列（`projections`）のメモリ確保・解放は Julia ランタイム側が全責任を負う。
   - ネイティブ側は渡されたポインタ経由でデータの読み込みおよび書き込みを行う。

---

## 2. データ構造体とメモリ配置

### 2.1 幾何構造体 `TigreJuliaGeometry`
Julia の `Tigre.CGeometry` と 1:1 に対応する 28 メンバー構造体:

```c
typedef struct TigreJuliaGeometry {
    int nVoxelX;               // +0   (int32, 4 bytes)
    int nVoxelY;               // +4   (int32, 4 bytes)
    int nVoxelZ;               // +8   (int32, 4 bytes)
    float sVoxelX;             // +12  (float32, 4 bytes)
    float sVoxelY;             // +16  (float32, 4 bytes)
    float sVoxelZ;             // +20  (float32, 4 bytes)
    float dVoxelX;             // +24  (float32, 4 bytes)
    float dVoxelY;             // +28  (float32, 4 bytes)
    float dVoxelZ;             // +32  (float32, 4 bytes)
    int nDetecU;               // +36  (int32, 4 bytes)
    int nDetecV;               // +40  (int32, 4 bytes)
    float sDetecU;             // +44  (float32, 4 bytes)
    float sDetecV;             // +48  (float32, 4 bytes)
    float dDetecU;             // +52  (float32, 4 bytes)
    float dDetecV;             // +56  (float32, 4 bytes)
    // 64-bit プラットフォームではポインタのアライメント境界 (8 bytes) に入る
    const float* offOrigX;     // +64  (pointer, 8 bytes)
    const float* offOrigY;     // +72  (pointer, 8 bytes)
    const float* offOrigZ;     // +80  (pointer, 8 bytes)
    const float* DSO;          // +88  (pointer, 8 bytes)
    const float* offDetecU;    // +96  (pointer, 8 bytes)
    const float* offDetecV;    // +104 (pointer, 8 bytes)
    const float* DSD;          // +112 (pointer, 8 bytes)
    const float* dRoll;        // +120 (pointer, 8 bytes)
    const float* dPitch;       // +128 (pointer, 8 bytes)
    const float* dYaw;         // +136 (pointer, 8 bytes)
    const float* COR;          // +144 (pointer, 8 bytes)
    float accuracy;            // +152 (float32, 4 bytes)
    int mode;                  // +156 (int32, 4 bytes) - 0: cone, 1: parallel
} TigreJuliaGeometry;
```

### 2.2 配列データの並び順 (Strided Layout)
Julia 側の多次元配列（列優先 / Fortran order）をそのまま連続ポインタとして渡す:
- **Volume**: `volume[x, y, z]` (3D: X が最速変化軸、Z が最遅変化軸)
- **Projections**: `projections[u, v, angle]` (3D: U が最速変化軸、angle が最遅変化軸)

---

## 3. エクスポート関数一覧 (12 シンボル)

### 3.1 順投影・逆投影
```c
int tigre_julia_ax(
    const float* volume,
    const TigreJuliaGeometry* geometry,
    const float* angles,
    int nangles,
    int projection_type,      // 0: siddon, 1: interpolated
    const int* gpu_ids,
    int gpu_count,
    float* projections_out);

int tigre_julia_atb(
    const float* projections,
    const TigreJuliaGeometry* geometry,
    const float* angles,
    int nangles,
    int backprojection_type,  // 0: fdk, 1: matched
    const int* gpu_ids,
    int gpu_count,
    float* volume_out);
```

### 3.2 全変動 (TV) 正則化およびノイズ除去
```c
int tigre_julia_min_tv(
    const float* volume,
    int nVoxelX, int nVoxelY, int nVoxelZ,
    float alpha, int maxiter,
    const int* gpu_ids, int gpu_count,
    float* volume_out);

int tigre_julia_awmin_tv(
    const float* volume,
    int nVoxelX, int nVoxelY, int nVoxelZ,
    float alpha, int maxiter, float delta,
    const int* gpu_ids, int gpu_count,
    float* volume_out);

int tigre_julia_tvdenoise(
    const float* volume,
    int nVoxelX, int nVoxelY, int nVoxelZ,
    float lambda, const float* spacing_xyz, int maxiter,
    const int* gpu_ids, int gpu_count,
    float* volume_out);

int tigre_julia_piccs_tv(
    const float* volume, const float* prior,
    int nVoxelX, int nVoxelY, int nVoxelZ,
    float alpha, float ratio, int maxiter,
    const int* gpu_ids, int gpu_count,
    float* volume_out);
```

### 3.3 GPU 照会
```c
int tigre_julia_get_gpu_count(void);
int tigre_julia_get_gpu_name(int device_id, char* name, size_t name_len);
```

### 3.4 エラーハンドリング
```c
void tigre_julia_clear_last_error(void) noexcept;
const char* tigre_julia_last_error_message(void) noexcept;
const char* tigre_julia_last_error_tag(void) noexcept;
const char* tigre_julia_error_string(int status);
```

### 3.5 ステータスコード
| 定数 | 値 | 説明 |
|---|---|---|
| `TIGRE_JULIA_STATUS_SUCCESS` | `0` | 正常終了 |
| `TIGRE_JULIA_STATUS_INVALID_ARGUMENT` | `64` | 不正な幾何引数や null ポインタ |
| `TIGRE_JULIA_STATUS_RUNTIME_ERROR` | `65` | CUDA ランタイムエラーまたは内部例外 |
