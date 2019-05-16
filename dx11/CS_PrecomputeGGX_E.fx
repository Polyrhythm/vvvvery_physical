/*
Integration of GGX from cos(theta) 0.0 - 1.0 and roughness 0.0 - 1.0
*/

#include "common.fxh"
#include "shading/ggx.fxh"
#include "math.fxh"

RWStructuredBuffer<float3> outBuf : BACKBUFFER;

#define ThreadsX 32
#define ThreadsY 32
#define Width 32

float phong(float NoH, float roughness)
{
	return (roughness + 2.0) / (2.0 * PI) * pow(NoH, roughness);
}

[numthreads(ThreadsX, ThreadsY, 1)]
void CS(uint3 tid : SV_DispatchThreadID)
{
	const uint idx = tid.x + tid.y * Width;

	float roughness = (float)tid.y / (float)Width;
	float NoV = (float)tid.x / (float)Width;

	BSDFSample res = (BSDFSample)0;

	GGXSpecularBRDF Fs;
	
	float evalSum = 0.0;
	const float theta_i = 0.05;
	const float phi_i = 0.05;
	for (float phiWi = 0.0; phiWi < PI2; phiWi += phi_i)
	{
		for (float NoL = 0.0; NoL < 1.0; NoL += theta_i)
		{
			float nohA = 1.0 + NoL * NoV + (1.0 - NoV * NoV) * (1.0 - NoL * NoL) * cos(phiWi);
			float NoH = (NoL + NoV) / sqrt(2.0 * nohA);
			
			float D = Fs.eNDF(NoH, roughness);
			float G = Fs.eGS(NoV, NoL, roughness);
			float Fr = D * G;
			
 			evalSum +=  Fr * NoL;
		}	
	}

	outBuf[idx] = evalSum * phi_i * theta_i;
}

technique11 Apply
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CS() ) );
	}
}




