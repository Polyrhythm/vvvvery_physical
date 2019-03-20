float smin( float a, float b, float k )
{
    float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
    return lerp( b, a, h ) - k*h*(1.0-h);
}

float f(float3 p, float r)
{
	return length(p) - r;
}

float sphere(float3 p, float r)
{
	return length(p) - r;
}

RWTexture3D<float> RWDistanceVolume : BACKBUFFER;

float time;

[numthreads(8, 8, 8)]
void CS(uint3 id : SV_DispatchThreadID, uint3 gid : SV_GroupID)
{
	float3 p = float3(gid.x * 8 + id.x, gid.y * 8 + id.y, gid.z * 8 + id.z);
	p *= (1.0 / 256.0);
	//p -= 0.5f;
	
	float d = smin(f(p, 0.25), f(p + float3(-0.1,0,-0.25), 0.15), 0.05);
	float dist = 1.0;
	
	RWDistanceVolume[id] = sphere(p, 0.5);
}

technique10 Process
{
	pass P0
	{
		SetComputeShader(CompileShader(cs_5_0, CS()));
	}
}
