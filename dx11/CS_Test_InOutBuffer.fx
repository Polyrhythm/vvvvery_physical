RWStructuredBuffer<float> OutputBuffer : BACKBUFFER;

StructuredBuffer<float> InBuffer;

[numthreads(32,1,1)]
void CS(uint3 tid : SV_DispatchThreadID)
{
	uint count, stride;
	InBuffer.GetDimensions(count, stride);
	
	if (tid.x > count) return;
	
	OutputBuffer[tid.x] = InBuffer[tid.x];
}

technique11 Apply
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CS() ) );
	}
}




