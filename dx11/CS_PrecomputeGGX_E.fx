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

[numthreads(ThreadsX, ThreadsY,1)]
void CS(uint3 tid : SV_DispatchThreadID)
{
	const uint idx = tid.x + tid.y * Width;

	const float roughness = (float)tid.y / (float)Width;
	GGXSpecularBRDF Fs = GGXSpecularBRDF::New(roughness, 1.3, false); // TODO FIX THIS 
	Surface surf;
	surf.nor = float3(1.0, 0.0, 0.0);
	BSDFSample res = (BSDFSample)0;
	
	const float thetaWi = (float)tid.x / (float)Width * PIOVER2;
	const float phi = 0.0;
	
	const float3 Wi = float3(
		sin(thetaWi) * cos(phi), sin(thetaWi) * sin(phi),
		cos(thetaWi)
	);
	
	float evalSum = 0.0;
	const float interval = 0.01;
	for (float thetaWr = 0.0; thetaWr < PIOVER2; thetaWr += interval)
	{
		const float3 Wr = float3(
			sin(thetaWr) * cos(phi), sin(thetaWr) * sin(phi),
			cos(thetaWr)
		);
		
		float cosTheta = dot(Wr, surf.nor);
		res = Fs.Evaluate(surf, Wr, Wi);
		float3 H = normalize(Wr + Wi);
		float3 f = Fs.Fresnel(H, Wi);
		//res.value *= f; // fresnel
		evalSum += res.value.x * cosTheta * interval;
	}

	// multiply by PI2 because this is integrating over the hemisphere,
	// but this is an isotropic case, we don't need to actually run that outer
	// loop
	float result = evalSum * PI2;
	//outBuf[idx] = result > 1.0 ? float3(1.0, 0.0, 0.0) : float3(0.0, result, 0.0);
	float3 Wr = reflect(surf.nor, Wi);
	res = Fs.Evaluate(surf, Wr, Wi);
	outBuf[idx] = res.value.x > 1.0 ? float3(1.0, 0.0, 0.0) : float3(0.0, res.value.x, 0.0);
}

technique11 Apply
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CS() ) );
	}
}




