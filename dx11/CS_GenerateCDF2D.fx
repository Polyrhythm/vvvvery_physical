#include "math.fxh"

RWStructuredBuffer<float> outBuf : BACKBUFFER;

StructuredBuffer<float4> colorBuf;

#define ThreadsX 64
#define ThreadsY 1

#define Width 256

[numthreads(ThreadsX, ThreadsY, 1)]
void CS(uint3 tid : SV_DispatchThreadID, uint3 groupTid : SV_GroupThreadID)
{
	const uint idx = tid.x * 4.0 + tid.y * Width;
	
	outBuf[idx] = 1.0;
}

technique11 Process
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CS() ) );
	}
}




