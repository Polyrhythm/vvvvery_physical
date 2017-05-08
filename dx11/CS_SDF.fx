float smin( float a, float b, float k )
{
    float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
    return lerp( b, a, h ) - k*h*(1.0-h);
}

float f(float3 p, float r)
{
	return length(p) - r;
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
	
	float d = smin(f(p, 0.25), f(p + float3(-0.1,0,-0.25), 0.15), 0.05);
	
	RWDistanceVolume[id] = d;
}

technique10 Process
{
	pass P0
	{
		SetComputeShader(CompileShader(cs_5_0, CS()));
	}
}
