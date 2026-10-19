// Soft glow for Windows Terminal. Bright text bleeds a little light around
// itself, the rest of the screen is left untouched. Toggle with Ctrl+Shift+g.
//
// It never reads Time, so Windows Terminal only redraws when the text changes
// and the shader costs nothing while the terminal sits idle.

Texture2D shaderTexture;
SamplerState samplerState;

cbuffer PixelShaderSettings {
    float  Time;
    float  Scale;
    float2 Resolution;
    float4 Background;
};

// Knobs. Save the file and Windows Terminal reloads it.
static const float Radius    = 1.5;   // blur step in pixels, scaled with DPI
static const float Strength  = 0.35;  // how much glow is added on top
static const float Threshold = 0.25;  // luminance below this doesn't glow

float3 bright(float2 uv)
{
    float3 c = shaderTexture.Sample(samplerState, uv).rgb;
    float l = dot(c, float3(0.299, 0.587, 0.114));
    return c * smoothstep(Threshold, Threshold + 0.25, l);
}

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float4 color = shaderTexture.Sample(samplerState, tex);
    float2 step = Radius * Scale / Resolution;

    // 7x7 gaussian (sigma ~1.5) over the bright parts only.
    static const float w[4] = { 0.266, 0.213, 0.110, 0.036 };
    float3 glow = 0;
    for (int x = -3; x <= 3; x++) {
        for (int y = -3; y <= 3; y++) {
            glow += bright(tex + float2(x, y) * step) * w[abs(x)] * w[abs(y)];
        }
    }

    color.rgb += glow * Strength;
    return color;
}
