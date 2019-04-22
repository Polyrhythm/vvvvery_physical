#include "math.fxh"

RWStructuredBuffer<float3> outBuf : BACKBUFFER;

StructuredBuffer<float4> colorBuf;

#define ThreadsX 1
#define ThreadsY 64

#define Width 256

float getLuminance(const float3 color)
{
	return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b; 
}

[numthreads(ThreadsX, ThreadsY, 1)]
void CS(uint3 tid : SV_DispatchThreadID, uint3 groupTid : SV_GroupThreadID)
{
	const float2 q = float2(
		groupTid.x * ThreadsX + tid.x,
		groupTid.y * ThreadsY + tid.y
	);
	const uint idx = tid.x + tid.y * Width;
	
	float rowWeightSum = 0.0;
	const float sinTheta = sin(PI * float(q.y + 0.5) / float(Width));
	for (uint i = 0; i < Width; i++)
	{
		float luminance = getLuminance(colorBuf[idx + i].rgb);
		rowWeightSum += luminance;
		float rowWeight = rowWeightSum;
		
		outBuf[idx + i] = float3(luminance, rowWeight, 0.0);
	}
	
	for (uint j = 0; j < Width; j++)
	{
		outBuf[idx + j] = float3(
			outBuf[idx + j].x,
			outBuf[idx + j].y / rowWeightSum,
			(j == Width - 1) ? rowWeightSum : 0.0
		);
	}
}

technique11 Process
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CS() ) );
	}
}




