RWStructuredBuffer<float> outputBuf : BACKBUFFER;

StructuredBuffer<float> cdf2d;

#define ThreadsX 64
#define ThreadsY 1

#define WIDTH 256

[numthreads(ThreadsX,ThreadsY,1)]
void CS(uint3 tid : SV_DispatchThreadID)
{
	const uint idx = tid.x * 4.0 + tid.y * WIDTH;
	
	outputBuf[idx] = tid.x;
}

technique11 Apply
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CS() ) );
	}
}




