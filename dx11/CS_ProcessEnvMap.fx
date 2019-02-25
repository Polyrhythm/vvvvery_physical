RWStructuredBuffer<float4> data : BACKBUFFER;

Texture2D<float4> envMap <string uiname="Environment Map";>;

#define ThreadsX 1
#define ThreadsY 1

#define Width 4096
#define Height 2048

float getLuminance(const float3 colour)
{
	return 0.299 * colour.r + 0.587 * colour.g + 0.114 * colour.b;
}

[numthreads(ThreadsX, ThreadsY, 1)]
void CS(uint3 tid : SV_DispatchThreadID, uint3 groupTid : SV_GroupThreadID)
{
	float colWeightSum = 0.0f;
	
	for (uint y = 0; y < Height; y++)
	{
		float rowWeightSum = 0.0f;
		
		for (uint x = 0; x < Width; x++)
		{
			const float4 col = envMap.Load(uint3(x, y, 0));
			const float weight = getLuminance(col.rgb);
			
			rowWeightSum += weight;
			
			data[y * Width + x] = float4(weight, rowWeightSum, 0.0, 0.0);
		}
		
		for (uint x2 = 0; x2 < Width; x2++)
		{
			data[y * Width + x2].xy /= rowWeightSum;
		}
		
		colWeightSum += rowWeightSum;
		
		data[y * Width].zw = float2(rowWeightSum, colWeightSum);
	}
	
	for (uint j = 0; j < Height; j++)
	{
		data[j * Height].zw /= colWeightSum;
	}
}

technique11 Process
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CS() ) );
	}
}




