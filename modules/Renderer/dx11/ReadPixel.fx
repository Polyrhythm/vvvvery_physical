RWStructuredBuffer<float4> OutputBuffer : BACKBUFFER;

Texture2D tex <string uiname="Texture";>;

StructuredBuffer<float2> uv <string uiname="UV Buffer";>;

SamplerState linearSampler : IMMUTABLE
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
};

float getLuminance(const float3 colour)
{
	return 0.3 * colour.r + 0.59 * colour.g + 0.11 * colour.b;
}

[numthreads(64,1,1)]
void CS(uint3 tid : SV_DispatchThreadID)
{
	const float3 sample = tex.SampleLevel(linearSampler, uv[tid.x], 0).rgb;
	const float lum = getLuminance(sample);
	OutputBuffer[tid.x] = float4(sample, lum);
}

technique11 Process
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CS() ) );
	}
}




