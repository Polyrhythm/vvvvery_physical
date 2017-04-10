#ifndef __BRDF_FXH__
#define __BRDF_FXH__

#include "math.fxh"
#include "sampling.fxh"

// BSDF types
static const int DEBUG_BSDF_TYPE = -1;
static const int  NULL_BSDF_TYPE =  0;
static const int  BRDF_TYPE = 1;
static const int  BTDF_TYPE = 2;
static const int  EMIT_TYPE = 3;
static const int  MULTI_TYPE = 4;

struct BSDFSample {
	float3 value;
	float pdf;
	int type;
};

/*interface IBSDF {
	BSDFSample Evaluate( Surface surface, float3 Wr, float3 Wi );
	BSDFSample Sample( Surface surface, float3 Wr, out float3 Wi );
};*/

interface IBSDF {
	// =========================================================================
	// Evaluate( surface, Wr, Wi )
	// =========================================================================
	// Computes the value for this BRDF and corresponding probability density
	// for the given surface normal and incident and reflected directions.
	BSDFSample Evaluate( // return : Sampled BRDF value
		Surface surf,      // Macro-Surface normal
		float3 Wr,     // Reflected ray direction
		float3 Wi     // Incident ray direction
	);

	// =========================================================================
	// Sample( surface, Wr, rand, out Wi )
	// =========================================================================
	// Similar to the `SampleDirect` function except that instead of the
	// incident ray direction being given as an argument, an appropriate
	// direction will be selected from some distribution. It then proceeds to
	// computes the value for this BRDF and corresponding probability density
	// for the given surface normal and incident and reflected directions.
	BSDFSample Sample( // return : Sampled BRDF value
		Surface surf,    // Macro-Surface normal
		ISampler samp,
		float3 Wr,   // Reflected ray direction
		out float3 Wi // Sampled incident ray direction
	);
};

class AbstractBSDF : IBSDF {
	BSDFSample Evaluate( Surface surf, float3 Wr, float3 Wi );
	BSDFSample   Sample( Surface surf, ISampler samp, float3 Wr, out float3 Wi );
};

class LambertianBRDF : AbstractBSDF {
	float3 albedo;

	void Init( float3 albedo ){
		this.albedo = albedo;
	}

	static LambertianBRDF New( float3 albedo ){
		LambertianBRDF brdf;
		brdf.Init( albedo );
		return brdf;
	}

	BSDFSample Evaluate( Surface surf, float3 Wr, float3 Wi ){
		BSDFSample res;

		float NWi_PI = max( 0, dot( surf.nor, Wi )) * INV_PI;
		res.value = this.albedo * NWi_PI;
		res.pdf = NWi_PI;
		res.type = BRDF_TYPE;
		//if( dot( surf.nor, Wi ) < 0 ) res.type = NULL_BSDF_TYPE;

		return res;
	}
	BSDFSample Sample( Surface surf, ISampler samp, float3 Wr, out float3 Wi ){
		float unused;
		Wi = sampleCosineWeightedHemisphere( surf.nor, samp.SampleFloat2(), unused );
		return Evaluate( surf, Wr, Wi );
	}
};

interface IMicrofacetBSDF {
	float3 Fresnel( float3 H, float3 W );
	float GS( float3 H, float3 Wr, float3 Wi );
	float NDF( float3 N, float3 H, out float pm );
};

// http://www.cs.cornell.edu/~srm/publications/EGSR07-btdf.pdf
class AbstractMicrofacetBRDF : IMicrofacetBSDF, AbstractBSDF {
	float  roughness;
	float3 ior;

	void Init( float roughness, float3 ior ){
		this.roughness = max(roughness,1e-4); // keep roughness above zero
		this.ior = ior;
	}

	float3 Fresnel( float3 H, float3 W );
	float GS( float3 H, float3 Wr, float3 Wi );
	float NDF( float3 N, float3 H, out float pm );

	BSDFSample Evaluate( Surface surf, float3 Wr, float3 Wi ){
		BSDFSample res;
		res.type = BRDF_TYPE;

		if( roughness <= 1e-4 ){
			res.value = (float3)0;
			res.pdf = 0;
			return res;
		}

		float pm;
		float3 H = normalize( Wi + Wr );
		float D = NDF( surf.nor, H, pm );
		float G = GS( surf.nor, Wr, Wi );

		// Exclude fresnel term here, gets factored in later.
		res.value = (D * G * 0.25) / (max(0,dot( surf.nor, Wi ))*max(0,dot( surf.nor, Wr )));

		// eq. 38 - but see also:
		// eq. 17 in http://www.graphics.cornell.edu/~bjw/wardnotes.pdf
		res.pdf = (pm * 0.25) / (max(0,dot( H, Wi ))*max(0,dot( H, Wr )));
		
		return res;
	}

	BSDFSample Sample( Surface surf, ISampler samp, float3 Wr, out float3 Wi ){
		float2 rand = samp.SampleFloat2();

		BSDFSample res;
		res.value = (float3)0;
		res.pdf = 0;
		res.type = NULL_BSDF_TYPE;
		Wi = surf.nor;

		float a2 = pow(roughness,2);

		// eq. 35,36 - sample random microfacet normal
		float theta = atan((a2 * sqrt(rand.x)) / sqrt(1.0 - rand.x));
		float phi = PI2 * rand.y;

		float3 T, B;
		makeOrthonormalBasis( surf.nor, T, B );

		// microfacet normal
		float3 m = (sin(theta) * cos(phi) * T)
		         + (sin(theta) * sin(phi) * B)
		         + (cos(theta) * surf.nor);

		// is microfacet visible?
		if( dot( m, Wr ) > 0 ){
			// eq. 39 - get incident ray for m
			Wi = 2.0 * dot(m,Wr) * m - Wr;

			// is reflected direction within hemisphere?
			if( dot( surf.nor, Wi ) > 0 ){
				if( roughness <= 1e-4 ){
					res.value = (float3)1e6;
					res.pdf = 1e6;
				}
				else
				{
					float pm;
					float D = NDF( surf.nor, m, pm );
					float G = GS( surf.nor, Wr, Wi );

					// Exclude fresnel term here, gets factored in later.
					res.value = (D * G * 0.25) / (max(0,dot( surf.nor, Wi ))*max(0,dot( surf.nor, Wr )));

					// eq. 38 - but see also:
					// eq. 17 in http://www.graphics.cornell.edu/~bjw/wardnotes.pdf
					res.pdf = (pm * 0.25) / (max(0,dot( m, Wi ))*max(0,dot( m, Wr )));
				}
				res.type = BRDF_TYPE;
			}
		}

		return res;
	}
};

#endif