float f(float3 p, float4 c)
{
	float4 z = float4(p, 0.0);
	float md2 = 1.0;
	float mz2 = dot(z, z);
	
	float4 trap = float4(abs(z.xyz), dot(z, z));
	
	for (int i = 0; i < 11; i++) {
		// |dz|^2 -> 4 * |dz|^2
		md2 *= 4.0 * mz2;
		
		// z-> z2 * c
		z = float4(z.x * z.x - dot(z.yzw, z.yzw),
				   2.0 * z.x * z.yzw) + c;
		
		trap = min(trap, float4(abs(z.xyz), dot(z, z)));
		
		mz2 = dot(z, z);
		if (mz2 > 4.0) break;
	}
	
	return 0.2 * sqrt(mz2 / md2) * log(mz2);
}

RWTexture3D<float> RWDistanceVolume : BACKBUFFER;

float3 InvVolumeSize : INVTARGETSIZE;

float time;

[numthreads(8, 8, 8)]
void CS(uint3 id : SV_DispatchThreadID)
{
	float3 p = id;
	p *= InvVolumeSize;
	p -= 0.5f;
	
	float4 c = 0.4 * cos(float4(time * 0.1, 3.9, 1.4, 1.1)
		+ float4(1.2, 1.7, 1.3, 2.5))
		- float4(0.3, 0.0, 0.0, 0.0);
	
	float d = f(p * 2.35, c);
	
	RWDistanceVolume[id] = d;
}

technique10 Process
{
	pass P0
	{
		SetComputeShader(CompileShader(cs_5_0, CS()));
	}
}
