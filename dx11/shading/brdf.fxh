#ifndef __BRDF_FXH__
#define __BRDF_FXH__

#include "math.fxh"
#include "physical_constants.fxh"
#include "sampling.fxh"

// BSDF types
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

interface IBSDF {
	// =========================================================================
	// Evaluate( surface, Wo, Wi )
	// =========================================================================
	// Computes the value for this BRDF and corresponding probability density
	// for the given surface normal and incident and reflected directions.
	BSDFSample Evaluate( // return : Sampled BRDF value
		Surface surf,      // Macro-Surface normal
		float3 Wo,     // Reflected ray direction
		float3 Wi     // Incident ray direction
	);

	// =========================================================================
	// Sample( surface, Wo, rand, out Wi )
	// =========================================================================
	// Similar to the `SampleDirect` function except that instead of the
	// incident ray direction being given as an argument, an appropriate
	// direction will be selected from some distribution. It then proceeds to
	// computes the value for this BRDF and corresponding probability density
	// for the given surface normal and incident and reflected directions.
	BSDFSample Sample( // return : Sampled BRDF value
		Surface surf,    // Macro-Surface normal
		float3 Wo,   // Reflected ray direction
		out float3 Wi // Sampled incident ray direction
	);
};

class AbstractBSDF : IBSDF {
	BSDFSample Evaluate(Surface surf, float3 Wo, float3 Wi);
	BSDFSample Sample(Surface surf, float3 Wo, out float3 Wi);
};

class OrenNayarBRDF : AbstractBSDF
{
	float3 albedo;
	float sigma;
	float2 randXY;
	
	void Init(float3 albedo, float sigma, float2 randXY)
	{
		this.albedo = albedo;
		this.sigma = sigma;
		this.randXY = randXY;
	}
	
	static OrenNayarBRDF New(float3 albedo, float sigma, float2 randXY)
	{
		OrenNayarBRDF brdf;
		
		brdf.Init(albedo, sigma, randXY);
		return brdf;
	}
	
	BSDFSample Evaluate(Surface surf, float3 Wo, float3 Wi)
	{
		BSDFSample res = (BSDFSample)0;
		
		float VdotN = saturate(dot(surf.nor, Wi));
		float LdotN = saturate(dot(surf.nor, Wo));
		float thetaR = acos(VdotN);
		float sigma2 = (this.sigma * PIOVER180) * (this.sigma * PIOVER180);
		
		float cosPhiDiff = dot(normalize(Wi - surf.nor * VdotN), normalize(Wo - surf.nor * LdotN));
		float thetaI = acos(LdotN);
		float alpha = max(thetaI, thetaR);
		float beta = min(thetaI, thetaR);
		if (alpha > PI / 2.0)
		{
			res.type = NULL_BSDF_TYPE;
			return res;
		}
		
		float C1 = 1 - 0.5 * sigma2 / (sigma2 + 0.33);
		float C2 = 0.45 * sigma2 / (sigma2 + 0.09);
		if (cosPhiDiff >= 0)
		{
			C2 *= sin(alpha);
		}
		else
		{
			float beta3 = (2 * beta / PI) * (2 * beta / PI) * (2 * beta / PI);
			C2 *= (sin(alpha) - beta3);
		}
		float denom = (4 * alpha * beta) / (PI * PI);
		float C3 = 0.125 * sigma2 / (sigma2 + 0.09) * denom * denom;
	}
	BSDFSample Sample(Surface surf, float3 Wo, out float3 Wi)
	{
		float unused;
		Wi = sampleCosineWeightedHemisphere(surf.nor, randXY, unused);
		return Evaluate(surf, Wo, Wi);
	}
};

class LambertianBRDF : AbstractBSDF {
	float3 albedo;
	float2 randXY;

	void Init(float3 albedo, float2 randXY){
		this.albedo = albedo;
		this.randXY = randXY;
	}

	static LambertianBRDF New(float3 albedo, float2 randXY){
		LambertianBRDF brdf;
		brdf.Init(albedo, randXY);
		return brdf;
	}

	BSDFSample Evaluate(Surface surf, float3 Wo, float3 Wi){
		BSDFSample res;

		float NWi_PI = max( 0, dot( surf.nor, Wi )) * INV_PI;
		res.value = this.albedo * NWi_PI;
		res.pdf = NWi_PI;
		res.type = BRDF_TYPE;
		if(dot(surf.nor, Wi) < 0) res.type = NULL_BSDF_TYPE;

		return res;
	}
	BSDFSample Sample(Surface surf, float3 Wo, out float3 Wi)
	{
		float unused;
		Wi = sampleCosineWeightedHemisphere(surf.nor, this.randXY, unused);
		return Evaluate(surf, Wo, Wi);
	}
};

interface IMicrofacetBSDF {
	float3 Fresnel(float3 Wh, float3 W);
	float GS(float3 Wh, float3 Wo, float3 Wi);
	float NDF(float3 N, float3 Wh, out float pm);
	float3 MicrofacetNormal(float3 macroNormal, float roughness, float2 rand);
};

class AbstractMicrofacetBTDF : IMicrofacetBSDF, AbstractBSDF
{
	float roughness;
	float3 ior;
	float3 randXYZ;

	void Init(float roughness, float3 ior, float3 randXYZ)
	{
		this.roughness = max(roughness, 1e-4);
		this.ior = ior;
		this.randXYZ = randXYZ;
	}

	float3 Fresnel(float3 Wh, float3 W);
	float GS(float3 Wh, float3 Wo, float3 Wi);
	float NDF(float3 N, float3 Wh, out float pm);
	float3 MicrofacetNormal(float3 macroNormal, float roughness, float2 rand);

	BSDFSample Evaluate(Surface surf, float3 Wo, float3 Wi)
	{
		BSDFSample res = (BSDFSample)0;

		// Calculate Wh
		float eta = dot(surf.nor, Wo) > 0 ? this.ior.x : (1.0 / this.ior.x);
		float3 Wh = -1.0 * normalize(Wo * AIR_IOR + Wi * this.ior.x);
		Wh *= signum(dot(surf.nor, Wh));	

		float pm = 0.0;
		float F = this.Fresnel(Wh, Wo).x;
		float D = NDF(surf.nor, Wh, pm);
		float G = GS(surf.nor, Wo, Wi);

		float VoH = max(0, dot(Wo, Wh));
		float LoH = max(0, dot(Wi, Wh));
		float a = (VoH * LoH) / (max(0, dot(Wo, surf.nor)) * max(0, dot(Wi, surf.nor)));
		float b1 = eta * eta * (1.0 - F) * G * D;
		float b2 = AIR_IOR * LoH + eta * VoH;

		res.value = a * (b1 / b2);
		//res.value *= NWi; ?? needed?

		res.pdf = pm / (4.0 * abs(dot(Wh, Wo)));

		res.type = BTDF_TYPE;

		return res;
	}

	BSDFSample Sample(Surface surf, float3 Wo, out float3 Wi)
	{
		BSDFSample res = (BSDFSample)0;

		float3 m = MicrofacetNormal(surf.nor, roughness, this.randXYZ.xy);
		float IoM = max(0.0, dot(Wo, m));

		if (IoM == 0.0)
		{
			// Light is not incident on microsurface normal
			return res;
		}

		// Calculate Wi
		float3 Wo_i = -1.0 * Wo;
		float eta = AIR_IOR / this.ior.x; // assuming air for incident side
		float c = dot(Wo_i, m);

		//eq. 40 - calculate transmitted ray direction
		float a = eta * c - signum(dot(Wo_i, surf.nor)) * sqrt(1.0 + eta * (c * c - 1.0));
		Wi = a * m - eta * Wo_i;
		Wi = Wo_i;
		Wi = Wo;

		float pm;
		NDF(surf.nor, m, pm);

		// eq. 38
		// Eq. 17 in http://www.graphics.cornell.edu/~bjw/wardnotes.pdf
		res.pdf = pm / (4.0 * abs(dot(m, Wo)));

		return res;
	}
};

// http://www.cs.cornell.edu/~srm/publications/EGSR07-btdf.pdf
class AbstractMicrofacetBRDF : IMicrofacetBSDF, AbstractBSDF {
	float  roughness;
	float3 ior;
	float3 randXYZ;

	void Init(float roughness, float3 ior, float3 randXYZ)
	{
		this.roughness = max(roughness,1e-4); // keep roughness above zero
		this.ior = ior;
		this.randXYZ = randXYZ;
	}

	float3 Fresnel(float3 Wh, float3 W);
	float GS(float3 Wh, float3 Wo, float3 Wi);
	float NDF(float3 N, float3 Wh, out float pm);
	float3 MicrofacetNormal(float3 macroNormal, float roughness, float2 rand);

	BSDFSample Evaluate(Surface surf, float3 Wo, float3 Wi){
		BSDFSample res = (BSDFSample)0;
		res.type = NULL_BSDF_TYPE;

		float NWi = max(0, dot(surf.nor, Wi));
		if (NWi > 0.0)
		{
			if (roughness <= 1e-4)
			{
				res.value = (float3)0;
				res.pdf = 0;
			} else {
				float3 Wh = normalize(Wi + Wo);

				float F = this.Fresnel(Wh, Wo).x;
				float pm;
				float D = NDF(surf.nor, Wh, pm);
				float G = GS(surf.nor, Wo, Wi);

				// Exclude fresnel term here, gets factored in later.
				res.value = D * G;
				res.value *= NWi;

				//res.pdf = pm / (4.0 * abs(dot(Wh, Wo)));
				res.pdf = (pm * 0.25) / max(0, dot(Wh, Wi)) * max(0, dot(Wh, Wo));
				res.pdf *= NWi;

				res.type = BRDF_TYPE;
			}
		}

		return res;
	}

	BSDFSample Sample(Surface surf, float3 Wo, out float3 Wi){
		BSDFSample res;
		res.value = (float3)0;
		res.pdf = 0;
		res.type = NULL_BSDF_TYPE;
		Wi = surf.nor;

		float3 m = MicrofacetNormal(surf.nor, roughness, this.randXYZ.xy);

		// is microfacet visible?
		float IoM = max(0, dot(m, Wo));
		if (IoM > 0)
		{
			// eq. 39 - get incident ray for m
			Wi = reflect(-Wo, m);

			float NWi = max(0, dot(surf.nor, Wi));
			// is incident direction within hemisphere?
			if (NWi > 0 || false)
			{
				if (roughness <= 1e-4){
					res.value = (float3)1e6;
					res.pdf = 1e6;
				}
				else
				{
					// Eq. 24 - probability of m
					float pm;
					NDF(surf.nor, m, pm);

					// eq. 38
					// Eq. 17 in http://www.graphics.cornell.edu/~bjw/wardnotes.pdf
					res.pdf = pm / (4.0 * abs(dot(m, Wo)));
				}
			}
		}

		return res;
	}
};

#endif