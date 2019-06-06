#ifndef __GGX_FXH__
#define __GGX_FXH__

#include "math.fxh"
#include "shading/brdf.fxh"
#include "shading/fresnel.fxh"

// relatively unoptimized
float getNDF(const float NoH, float linearRoughness)
{
	float a2 = linearRoughness * linearRoughness;
	float b = NoH * NoH * (a2 - 1.0) + 1.0;

	return a2 / (PI * (b * b));
}

float getGDF(const float NoV, const float NoL, const float linearRoughness)
{
	float a2 = linearRoughness * linearRoughness;
	float ggxV = 2.0 * NoV / (NoV + sqrt(a2 + (1.0 - a2) * (NoV * NoV)));
	float ggxL = 2.0 * NoL / (NoL + sqrt(a2 + (1.0 - a2) * (NoL * NoL)));

	return ggxV * ggxL;
}

class GGXSpecularBRDF : AbstractMicrofacetBRDF {
	float3 Fresnel(float3 H, float3 W)
	{
		float HW = saturate(dot(H, W));
		float3 f0 = (ior - 1.0) / (ior + 1.0);
		f0 *= f0;

		return fresnel_schlick(HW, f0);
	}

	float GS( float3 H, float3 Wi, float3 Wo ){
		float NoV = saturate(dot(H, Wo));
		float NoL = saturate(dot(H, Wi));

		return getGDF(NoV, NoL, this.roughness);
	}

	float NDF(float3 N, float3 H, out float pm)
	{
		float NoH = abs(dot(N, H));
		float D = getNDF(NoH, this.roughness);
		pm = D * NoH;

		return D;
	}

	float eNDF(const float NoH, float linearRoughness)
	{
		return getNDF(NoH, linearRoughness);
	}

	float eGS(const float NoV, const float NoL, const float linearRoughness)
	{
		return getGDF(NoV, NoL, linearRoughness);
	}

	float3 MicrofacetNormal(float3 macroNormal, float roughness, float2 rand)
	{
		float a2 = roughness * roughness;

		// eq. 35,36 - sample random microfacet normal
		float theta = atan((a2 * sqrt(rand.x)) / sqrt(1.0 - rand.x));
		float phi = PI2 * rand.y;

		float3 T, B;
		makeOrthonormalBasis(macroNormal, T, B);

		// microfacet normal
		float3 m = (sin(theta) * cos(phi) * T)
		         + (sin(theta) * sin(phi) * B)
		         + (cos(theta) * macroNormal);


		return m;
	}
};

class GGXSpecularBTDF : AbstractMicrofacetBTDF
{
	float3 Fresnel(float3 H, float3 W)
	{
		float HW = saturate(dot( H, W ));
		float3 f0 = (ior - 1.0) / (ior + 1.0);
		f0 *= f0;

		return fresnel_schlick(HW, f0);
	}

	float GS( float3 H, float3 Wi, float3 Wo ){
		float NoV = saturate(dot(H, Wo));
		float NoL = saturate(dot(H, Wi));

		return getGDF(NoV, NoL, this.roughness);
	}

	float NDF(float3 N, float3 H, out float pm)
	{
		float NoH = saturate(dot(N, H));
		float D = getNDF(NoH, this.roughness);
		pm = D * NoH;

		return D;
	}

	float eNDF(const float NoH, float linearRoughness)
	{
		return getNDF(NoH, linearRoughness);
	}

	float eGS(const float NoV, const float NoL, const float linearRoughness)
	{
		return getGDF(NoV, NoL, linearRoughness);
	}

	float3 MicrofacetNormal(float3 macroNormal, float roughness, float2 rand)
	{
		float a2 = roughness * roughness;

		// eq. 35,36 - sample random microfacet normal
		float theta = atan((a2 * sqrt(rand.x)) / sqrt(1.0 - rand.x));
		float phi = PI2 * rand.y;

		float3 T, B;
		makeOrthonormalBasis(macroNormal, T, B);

		// microfacet normal
		float3 m = (sin(theta) * cos(phi) * T)
		         + (sin(theta) * sin(phi) * B)
		         + (cos(theta) * macroNormal);


		return m;
	}
};

#endif