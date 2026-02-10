#ifdef VK_MODE
cbuffer Params : register(b0, space0)
#else
cbuffer Params : register(b0)
#endif
{
    int _SrcWidth;
    int _SrcHeight;
    int _DstWidth;
    int _DstHeight;
};

#ifdef VK_MODE
[[vk::binding(1, 0)]]
#endif
Texture2D<float4> InputTexture : register(t0);

#ifdef VK_MODE
[[vk::binding(2, 0)]]
#endif
RWTexture2D<float4> OutputTexture : register(u0);

#ifdef VK_MODE
[[vk::binding(3, 0)]]
#endif
SamplerState LinearClampSampler : register(s0);

// Magic Kernel m(x), support [-1.5, +1.5]
static float MagicKernel(float x)
{
    float ax = abs(x);
    if (ax >= 1.5f)
        return 0.0f;

    if (x <= -0.5f)
    {
        float t = x + 1.5f;
        return 0.5f * t * t;
    }
    else if (x < 0.5f)
    {
        return 0.75f - x * x;
    }
    else
    {
        float t = x - 1.5f;
        return 0.5f * t * t;
    }
}

[numthreads(8, 8, 1)]
void CSMain(uint3 id : SV_DispatchThreadID)
{
    uint ox = id.x;
    uint oy = id.y;
    if (ox >= (uint) _DstWidth || oy >= (uint) _DstHeight)
        return;

    // Scale from dst -> src (texel space, center aligned)
    float2 dst = float2((float) ox + 0.5f, (float) oy + 0.5f);
    float2 scale = float2((float) _SrcWidth / (float) _DstWidth,
                          (float) _SrcHeight / (float) _DstHeight);

    // srcPos in texel space where texel centers are at i+0.5
    float2 srcPos = dst * scale - 0.5f;

    // We’ll sample a small fixed 3x3 grid around srcPos using bilinear sampling.
    // Choose offsets in texel space. This covers roughly [-1, 0, +1] around srcPos.
    // Magic support is ±1.5, so 3x3 is a reasonable fast approximation.
    static const float offs[3] = { -1.0f, 0.0f, 1.0f };

    float2 invSrc = 1.0f / float2((float) _SrcWidth, (float) _SrcHeight);

    float3 acc = 0.0f;
    float wsum = 0.0f;

    [unroll]
    for (int j = 0; j < 3; ++j)
    {
        float dy = offs[j];
        float wy = MagicKernel(dy); // approximate: weight based on integer offset

        [unroll]
        for (int i = 0; i < 3; ++i)
        {
            float dx = offs[i];
            float wx = MagicKernel(dx);
            float w = wx * wy;

            float2 p = srcPos + float2(dx, dy);
            float2 uv = (p + 0.5f) * invSrc;

            float3 s = InputTexture.SampleLevel(LinearClampSampler, uv, 0.0f).rgb;

            acc += s * w;
            wsum += w;
        }
    }

    float invW = (wsum > 0.0f) ? (1.0f / wsum) : 0.0f;
    float3 outRgb = acc * invW;

    OutputTexture[uint2(ox, oy)] = float4(outRgb, 1.0f);
}