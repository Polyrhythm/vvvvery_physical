RWTexture2D<float2> conditionalTex : BACKBUFFER;

StructuredBuffer<float4> data;

#define ThreadsX 32
#define ThreadsY 32

#define Width 4096
#define Height 2048

int LowerBound(uint lower, uint upper, const float value)
{
	while (lower < upper)
	{
		uint mid = lower + (upper - lower) / 2;
		
		if (data[mid].y < value)
		{
			lower = mid + 1;
		}
		else
		{
			upper = mid;
		}
	}
	
	return lower;
}

[numthreads(ThreadsX, ThreadsY, 1)]
void CS(uint3 tid : SV_DispatchThreadID, uint3 groupTid : SV_GroupThreadID)
{
	const float2 q = float2(
		groupTid.x * ThreadsX + tid.x,
		groupTid.y * ThreadsY + tid.y
	);
	const uint idx = q.y * Width + q.x;
	
	const float invWidth = (float)q.x / Width;
	int col = LowerBound(q.y * Width, (q.y + 1) * Width, invWidth) - q.y * Width;
	
	conditionalTex[q] = float2(col / (float)Width, data[idx].x);
}

[numthreads(ThreadsX, ThreadsY, 1)]
void Test(uint3 tid : SV_DispatchThreadID, uint3 groupTid : SV_GroupThreadID)
{
	const float2 q = float2(
		groupTid.x * ThreadsX + tid.x,
		groupTid.y * ThreadsY + tid.y
	);
	conditionalTex[q] = float2(q.x / (float)Width, q.y / (float)Height);
}

technique11 Process
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CS() ) );
	}
}

technique11 Testing
{
	pass P0
	{
		SetComputeShader(CompileShader(cs_5_0, Test()));
	}
}




