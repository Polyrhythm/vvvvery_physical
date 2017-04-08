#ifndef __BRDF_FXH__
#define __BRDF_FXH__

#include "math.fxh"
#include "sampling.fxh"

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

	float3 SampleDirect( float3 N, float3 Wr, float3 Wi, out float pdf ){
		float NWi_PI = max( 0, dot( N, Wi )) * INV_PI;
		pdf = NWi_PI;
		return this.albedo * NWi_PI;
	}
	float3 SampleIndirect( float3 N, float3 Wr, float2 rand, out float3 Wi, out float pdf ){
		Wi = sampleCosineWeightedHemisphere( N, rand, pdf );
		return this.albedo * pdf;
	}
};

interface IMicrofacetBRDF {
	float3 Fresnel( float3 H, float3 W );
	float GS( float3 H, float3 Wr, float3 Wi );
	float NDF( float3 N, float3 H, out float pm );
};

// http://www.cs.cornell.edu/~srm/publications/EGSR07-btdf.pdf
class AbstractMicrofacetBRDF : IMicrofacetBRDF, AbstractBRDF {
	float  roughness;
	float3 ior;

	void Init( float roughness, float3 ior ){
		this.roughness = max(roughness,1e-4); // keep roughness above zero
		this.ior = ior;
	}

	float3 Fresnel( float3 H, float3 W );
	float GS( float3 H, float3 Wr, float3 Wi );
	float NDF( float3 N, float3 H, out float pm );

	float3 SampleDirect( float3 N, float3 Wr, float3 Wi, out float pdf ){
		float pm;
		float3 H = normalize( Wi + Wr );
		float D = NDF( N, H, pm );
		float G = GS( H, Wr, Wi );

		// eq. 38 - but see also:
		// eq. 17 in http://www.graphics.cornell.edu/~bjw/wardnotes.pdf
		pdf = pm * 0.25 / max(0,dot( H, Wr ));

		// Exclude fresnel term here, gets factored in later.
		return (D * G * 0.25) / (max(0,dot( N, Wi ))*max(0,dot( N, Wr )));
	}

	float3 SampleIndirect( float3 N, float3 Wr, float2 rand, out float3 Wi, out float pdf ){
		float a2 = pow(roughness,2);

		// eq. 35,36 - sample random microfacet normal
		float theta = atan(a2 * sqrt(rand.x) * (1.0 - rand.x * rand.x));
		float phi = PI2 * rand.y;

		float3 T, B;
		makeOrthonormalBasis( N, T, B );

		// microfacet normal
		float3 m = (sin(theta) * cos(phi) * T)
		         + (sin(theta) * sin(phi) * B)
		         + (cos(theta) * N);

		// eq. 39 - get incident ray for m
		Wi = 2.0 * dot(m,Wr) * m - Wr;

		float3 f = (float3)0;
		if( roughness <= 1e-4 ){
			pdf = 1e6;
			f = (float3)1e6;
		}
		else
		{
			float pm;
			float D = NDF( N, m, pm );
			float G = GS( m, Wr, Wi );

			// eq. 38 - but see also:
			// eq. 17 in http://www.graphics.cornell.edu/~bjw/wardnotes.pdf
			pdf = pm * 0.25 / max(0,dot( m, Wr ));
			// Exclude fresnel term here, gets factored in later.
			f = (D * G * 0.25) / (max(0,dot( N, Wi ))*max(0,dot( N, Wr )));
		}

		return f;
	}
};

#endif