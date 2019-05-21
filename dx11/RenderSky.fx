// This is an implementation of Nishika, et al, sky model, as shown here:
// http://www.scratchapixel.com/lessons/procedural-generation-virtual-worlds/simulating-sky

#include "math.fxh"
#include "common.fxh"
#include "primitives.fxh"

#define ThreadsX 64
#define ThreadsY 1

#define WIDTH 256

// sky model levers
#define SCALE_HEIGHT 8000 // 8km
#define SCALE_HEIGHT_MIE 1200 // 1.2km
#define EARTH_RADIUS 6360000 // m
#define ATMO_RADIUS 6420000 // m

RWStructuredBuffer<float4> Buf : BACKBUFFER;

float3 SunDir = float3(0.0, 1.0, 0.0);

float mie_phase(const float mu)
{
	const float g = 0.76; // controls anisotropy of the medium, magic number
	float g2 = g * g;
	float mu2 = mu * mu;
	float firstTerm = 3.0 / (8.0 * PI);
	float numerator = (1.0 - g2) * (1.0 + mu2);
	float denom = (2.0 + g2) * pow(abs(1.0 + g2 - 2.0 * g * mu), 3.0 / 2.0);
	
	return firstTerm * (numerator / denom);
}

float rayleigh_phase(float mu)
{
	float mu2 = mu * mu;
	return (3.0 / (16.0 * PI)) * (1.0 + mu2);
}

float3 computeIncidentLight(Ray ray, float tMin, float tMax)
{
	const float Hr = 7994.0;
	const float Hm = 1200.0;
	
	const float3 BetaR = float3(3.8e-6, 13.5e-6, 33.1e-6);
	const float3 BetaM = 21e-6;
	
	float t0, t1;
	if (!intersectSphere(true, 0.0, ATMO_RADIUS, ray, t0, t1) || t1 < 0.0)
	{
		return 0.0;
	}
	
	if (t0 > tMin && t0 > 0.0)
	{
		//tMin = t0;
		tMin = 1.0; // hack to properly set tMin for now
	}
	
	if (t1 < tMax)
	{
		tMax = t1;
	}
	
	const uint numSamples = 16;
	const uint numSamplesLight = 8;
	const float segmentLength = (tMax - tMin) / (float)numSamples;
	float tCurrent = tMin;
	
	float3 sumR = 0.0;
	float3 sumM = 0.0;
	float opticalDepthR = 0.0;
	float opticalDepthM = 0.0;
	
	const float mu = dot(ray.dir, SunDir);
	const float phaseR = rayleigh_phase(mu);
	const float phaseM = mie_phase(mu);
	
	for (uint i = 0; i < numSamples; i++)
	{
		float3 samplePos = ray.origin + (tCurrent + segmentLength * 0.5) * ray.dir;
		float height = length(samplePos) - EARTH_RADIUS;
		
		float hr = exp(-height / Hr) * segmentLength;
		float hm = exp(-height / Hm) * segmentLength;
		opticalDepthR += hr;
		opticalDepthM += hm;
		
		float t0Light, t1Light;
		Ray lightRay;
		lightRay.origin = samplePos;
		lightRay.dir = SunDir;
		intersectSphere(true, 0.0, ATMO_RADIUS, lightRay, t0Light, t1Light);
		float segmentLengthLight = t1Light / (float)numSamplesLight;
		float tCurrentLight = 0.0;
		
		float opticalDepthLightR = 0.0;
		float opticalDepthLightM = 0.0;
		
		uint j;
		for (j = 0; j < numSamplesLight; j++)
		{
			float3 samplePosLight = samplePos + (tCurrentLight + segmentLength * 0.5) * SunDir;
			float heightLight = length(samplePosLight) - EARTH_RADIUS;
			if (heightLight < 0.0) break;
			opticalDepthLightR += exp(-heightLight / Hr) * segmentLengthLight;
			opticalDepthLightM += exp(-heightLight / Hm) * segmentLengthLight;
			tCurrentLight += segmentLengthLight;
		}
		
		if (j == numSamplesLight)
		{
			float3 tau = BetaR * (opticalDepthR + opticalDepthLightR) +
				BetaM * 1.1 * (opticalDepthM + opticalDepthLightM);
			
			float3 attenuation = float3(exp(-tau.x), exp(-tau.y), exp(-tau.z));
			sumR += attenuation * hr;
			sumM += attenuation * hm;
		}
		tCurrent += segmentLength;
	}
	
	float3 output = (sumR * BetaR * phaseR + sumM * BetaM * phaseM) * 20.0;
	
	return output;
}

[numthreads(ThreadsX,ThreadsY,1)]
void CS_Polar(uint3 tid : SV_DispatchThreadID, uint3 id : SV_GroupThreadID, uint3 gid: SV_GroupID)
{
	const uint idx = tid.x + tid.y * WIDTH;
	uint2 q = uint2(
		gid.x * ThreadsX + id.x,
		gid.y * ThreadsY + id.y
	);
	float y = 2.0 * (q.y + 0.5) / float(WIDTH - 1.0) - 1.0;
	float x = 2.0 * (q.x + 0.5) / float(WIDTH - 1.0) - 1.0;
	float z2 = x * x + y * y;
	
	float phi = 0.0;
	float theta = 0.0;
	float3 output = 0.0;
	if (z2 <= 1.0)
	{
		phi = atan2(y, x);
		theta = acos(1.0 - z2);
	
		Ray ray;
		ray.origin = float3(0.0, EARTH_RADIUS + 1.0, 0.0);
		ray.dir = float3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi));
	
		output = computeIncidentLight(ray, 0.0, 9e9);
	}
	
	Buf[idx] = float4(output, 1.0);
}

[numthreads(ThreadsX,ThreadsY,1)]
void CS_Equirect(uint3 tid : SV_DispatchThreadID, uint3 id : SV_GroupThreadID, uint3 gid: SV_GroupID)
{
	const uint idx = tid.x + tid.y * WIDTH;
	uint2 q = uint2(
		gid.x * ThreadsX + id.x,
		gid.y * ThreadsY + id.y
	);

	float3 output = 0.0;
	
	// radians
	const float xInterval = float(PI2) / float(WIDTH);
	const float yInterval = float(PI) / float(WIDTH);
	
	const float phi = xInterval * q.x;
	const float theta = yInterval * q.y;
	
	Ray ray;
	ray.origin = float3(0.0, EARTH_RADIUS + 1.0, 0.0);
	ray.dir = float3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi));
	
	output = computeIncidentLight(ray, 0.0, 9e9);
	
	Buf[idx] = float4(output, 1.0);
}

technique11 Polar
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CS_Polar() ) );
	}
}

technique11 Equirect
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CS_Equirect() ) );
	}
}
