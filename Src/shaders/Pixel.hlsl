[[vk::binding(0, 0)]]
Texture2D gTexture;

[[vk::binding(0, 1)]]
SamplerState gSampler;

struct PS_INPUT
{
	float3 fragColor : COLOR0;
};

float4 main(PS_INPUT input) : SV_Target
{
	return gTexture.Sample(gSampler, float2(0.0, 0.0));
	//return float4(input.fragColor, 1.0);
}