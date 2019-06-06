#include "noise/simplex.fxh"

RWTexture3D<float> OutputBuffer : BACKBUFFER;

cbuffer cbSettings : register(b0)
{
	uint elementCount;
}

#define ThreadsX 8
#define ThreadsY 8
#define ThreadsZ 8

#define DIM 64

[numthreads(ThreadsX, ThreadsY, ThreadsZ)]
void CS(uint3 tid : SV_DispatchThreadID)
{
	uint idx = tid.z * DIM + tid.y * DIM + tid.x;
	
	OutputBuffer[tid] = snoise(float3(tid.x, tid.y, tid.z));
}

technique11 Apply
{
	pass P0
	{
		SetComputeShader(CompileShader(cs_5_0, CS()));
	}
}




