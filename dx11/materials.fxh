#ifndef __MATERIALS_FXH__
#define __MATERIALS_FXH__

static const uint DIFFUSE = 0;
static const uint SPECULAR = 1;
static const uint EMISSIVE = 2;

#include "shading/fresnel.fxh"
#include "shading/ggx.fxh"

struct Material
{
	uint type;
	float ior;
	float roughness;
	float4 colour;
};

#define materialBufferStride 7

float getLambertianDiffuse(const float3 lightDir, const float3 n)
{
	return saturate(dot(lightDir, n));
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
	
	return (D * F * G) / (4.0f * NoL * NoV);
}

#endif