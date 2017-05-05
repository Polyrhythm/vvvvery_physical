#ifndef __GGX_FXH__
#define __GGX_FXH__

#include "math.fxh"
#include "shading/brdf.fxh"
#include "shading/fresnel.fxh"

// GGX (Trowbridge-Reitz
float getNDF(const float NoH, float a2)
{
	float denom = NoH * NoH * (a2 - 1) + 1;
	
	return a2 / (PI * denom * denom);
}

// GGX as seen in http://graphicrants.blogspot.com/2013/08/specular-brdf-reference.html
float getGDF(const float NoV, const float a2)
{
	float denom = NoV + sqrt(a2 + (1.0 - a2) * NoV * NoV);
	
	return (2 * NoV) / denom;
}

class GGXSpecularBRDF : AbstractMicrofacetBRDF {
	static GGXSpecularBRDF New( float roughness, float3 ior ){
		GGXSpecularBRDF brdf;
		brdf.Init( roughness, ior );
		return brdf;
	}

	float3 Fresnel( float3 H, float3 W ){
		float HW = saturate(dot( H, W ));
		float3 f0 = (ior - 1.0) / (ior + 1.0);
		f0 *= f0;

		return fresnel_schlick( HW, f0 );
	}

	float GS1( float3 H ,float3 W ){
		float HW = saturate(dot( H, W ));
		return getGDF( HW, pow(roughness,2) );
	}

	float GS( float3 H, float3 Wi, float3 Wr ){
		return GS1( H, Wi ) * GS1( H, Wr );
	}

	float NDF( float3 N, float3 H, out float pm ){
		float NH = saturate(dot( N, H ));
		float D = getNDF( NH, pow(roughness,2) );
		pm = D * NH;
		return D;

	}
};

#endif