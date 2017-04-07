#ifndef __BRDF_FXH__
#define __BRDF_FXH__

#include "math.fxh"

interface IBRDF {
	// =========================================================================
	// SampleDirect( N, Wr, Wi, out pdf )
	// =========================================================================
	// Computes the value for this BRDF and corresponding probability density
	// for the given surface normal and incident and reflected directions.
	float3 SampleDirect( // return : Sampled BRDF value
		float3 N,      // Macro-Surface normal
		float3 Wr,     // Reflected ray direction
		float3 Wi,     // Incident ray direction
		out float pdf  // Sampled probability density
	);

	// =========================================================================
	// SampleIndirect( N, Wr, rand, out Wi, out pdf )
	// =========================================================================
	// Similar to the `SampleDirect` function except that instead of the
	// incident ray direction being given as an argument, an appropriate
	// direction will be selected from some distribution. It then proceeds to
	// computes the value for this BRDF and corresponding probability density
	// for the given surface normal and incident and reflected directions.
	float3 SampleIndirect( // return : Sampled BRDF value
		float3 N,    // Macro-Surface normal
		float3 Wr,   // Reflected ray direction
		float2 rand, // Pair of uniformly sampled values over the interval [0,1]
		out float3 Wi, // Sampled incident ray direction
		out float pdf  // Sampled probability density
	);
};

class AbstractBRDF : IBRDF {
	float3 SampleDirect( float3 N, float3 Wr, float3 Wi, out float pdf );
	float3 SampleIndirect( float3 N, float3 Wr, float2 rand, out float3 Wi, out float pdf );
};

class LambertianBRDF : AbstractBRDF {
	float3 albedo;

	void Init( float3 albedo ){
		this.albedo = albedo;
	}

	static LambertianBRDF New( float3 albedo ){
		LambertianBRDF brdf;
		brdf.Init( albedo );
		return brdf;
	}

	float3 SampleDirect( float3 N, float3 Wr, float3 Wi, out float pdf );
	float3 SampleIndirect( float3 N, float3 Wr, float2 rand, out float3 Wi, out float pdf );
};

interface IMicrofacetBRDF {
	float GS( float3 H, float3 Wi, float3 Wr );
	float NDF( float3 N, float3 H );
};

class AbstractMicrofacetBRDF : IMicrofacetBRDF, AbstractBRDF {
	float  roughness;
	float3 ior;

	void Init( float roughness, float3 ior ){
		this.roughness = roughness;
		this.ior = ior;
	}

	float GS( float3 H, float3 Wi, float3 Wr );
	float NDF( float3 N, float3 H );

	float3 SampleDirect( float3 N, float3 Wr, float3 Wi, out float pdf );
	float3 SampleIndirect( float3 N, float3 Wr, float2 rand, out float3 Wi, out float pdf );
};

#endif