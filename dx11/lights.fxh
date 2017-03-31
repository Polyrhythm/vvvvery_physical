#ifndef __LIGHTS_FXH__
#define __LIGHTS_FXH__

#include "common.fxh"

struct Light
{
	uint type;
	float4 colour;
	float intensity;
	float4x4 transform;
};

#define lightBufferStride 22

float getAttenuation(const float3 pos, const float3 lightPos)
{
	float3 diff = pos - lightPos;
	float d2 = dot(diff, diff);
	return 1.0 / d2;
}

float getLambertianDiffuse(const float3 lightDir, const float3 n)
{
	return saturate(dot(lightDir, n));
}

// schlick
float3 getFresnel(const float LoH, const float3 f0)
{
	return f0 + (1.0 - f0) * pow(1.0 - LoH, 5.0);
}

// GGX (Trowbridge-Reitz
float getNDF(const float NoH, const float a2)
{
	float denom = PI * NoH * NoH * (a2 - 1) + 1;
	
	return a2 / (denom * denom);
}

// GGX as seen in http://graphicrants.blogspot.com/2013/08/specular-brdf-reference.html
float getGDF(const float NoV, const float a2)
{
	float denom = NoV + sqrt(a2 + (1.0 - a2) * NoV * NoV);
	
	return (2 * NoV) / denom;
}

float3 getSpecular(const float3 v, const float3 l, const float3 n,
	const float ior, const float roughness)
{
	// find the specular color
	// https://seblagarde.wordpress.com/2011/08/17/feeding-a-physical-based-lighting-mode/
	// @FIXME this probably breaks for metals which actually have an f0
	// which includes their base colour
	float iorM = ior - 1.0;
	float iorP = ior + 1.0;
	float3 f0 = (iorM * iorM) / (iorP * iorP);
	
	float3 h = l + v;
	
	float LoH = saturate(dot(l, h));
	float NoH = saturate(dot(n, h));
	float NoV = saturate(dot(n, v));
	float NoL = saturate(dot(n, l));
	
	float a2 = roughness * roughness;
	
	float3 F = getFresnel(LoH, f0);
	float D = getNDF(NoH, a2);
	float G = getGDF(NoV, a2);
	
	return (D * F * G) / (4 * NoL * NoV);
}

#endif