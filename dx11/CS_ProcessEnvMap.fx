RWStructuredBuffer<float4> pdf2d : BACKBUFFER;

Texture2D<float4> envMap <string uiname="Environment Map";>;

#define ThreadsX 32
#define ThreadsY 32

#define Width 4096
#define Height 2048

SamplerState linearSampler : IMMUTABLE
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
};

float getLuminance(const float3 colour)
{
	return 0.299 * colour.r + 0.587 * colour.g + 0.114 * colour.b;
}

[numthreads(ThreadsX, ThreadsY, 1)]
void CS(uint3 tid : SV_DispatchThreadID, uint3 groupTid : SV_GroupThreadID)
{
	float4 col = envMap.Load(uint3(tid.xy, 0));
	pdf2d[groupTid.y * ThreadsY + tid.x] = col;
}

technique11 Process
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CS() ) );
	}
}




