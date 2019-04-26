#ifndef __MATERIALS_FXH__
#define __MATERIALS_FXH__

static const int DIFFUSEDIELECTRIC = 0;
static const int METALLIC = 1;
static const int EMISSIVE = 2;
static const int DIELECTRIC = 3;

#include "shading/fresnel.fxh"
#include "shading/ggx.fxh"

struct Material
{
	int type;
	float ior;
	float roughness;
	float4 colour;
	float intensity;
	int albedoTexIdx;
	int roughnessTexIdx;
	int metallicTexIdx;
	int normalTexIdx;
	float2 uvScale;
	float padding;
};

class DiffuseDielectricMaterial : AbstractBSDF {
	LambertianBRDF  Fd;
	GGXSpecularBRDF Fs;
	float3 randXYZ;

	void Init(float3 albedo, float roughness, ISampler samp){
		float2 rand2 = samp.SampleFloat2();
		float rand = samp.SampleFloat();
		this.randXYZ = float3(rand2, rand);
		Fd.Init(albedo, rand2);
		Fs.Init(roughness, 1.3294, false, this.randXYZ);
	}

	static DiffuseDielectricMaterial New(float3 albedo, float roughness, ISampler samp){
		DiffuseDielectricMaterial brdf;
		brdf.Init(albedo, roughness, samp);
		return brdf;
	}

	BSDFSample Evaluate(Surface surf, float3 Wr, float3 Wi){
		BSDFSample res = (BSDFSample)0;

		if( dot(surf.nor, Wi) > 0 ){
			res.type = BRDF_TYPE;

			float3 H = normalize(Wr + Wi);
			float f = Fs.Fresnel(H, Wi).x;

			BSDFSample d = Fd.Evaluate(surf, Wr, Wi);
			BSDFSample s = Fs.Evaluate(surf, Wr, Wi);

			res.value = d.value * (1.0-f) + s.value * f;
			res.pdf   = d.pdf * (1.0-f) + s.pdf * f;
		}

		return res;
	}

	BSDFSample Sample( Surface surf, float3 Wr, out float3 Wi ){
		float f = Fs.Fresnel( surf.nor, Wr ).x;

		BSDFSample res;
		if (this.randXYZ.z < f)
		{
			res = Fs.Sample(surf, Wr, Wi);
		} else {
			res = Fd.Sample(surf, Wr, Wi);
		}

		if (res.pdf != 0)
		{
			BSDFSample eval = Evaluate(surf, Wr, Wi);
			res.value = eval.value;
			res.pdf = eval.pdf;
			res.type = eval.type;
		}

		return res;
	}
};

class MetallicMaterial : AbstractBSDF {
	GGXSpecularBRDF Fs;
	float3 randXYZ;

	void Init(float3 f0, float roughness, ISampler samp){
		f0 = sqrt(clamp(f0,0.0,0.9999));
		float3 ior = (1.0+f0) / (1.0-f0);
		this.randXYZ = float3(samp.SampleFloat2(), samp.SampleFloat());
		Fs.Init(roughness, ior, false, this.randXYZ);
	}

	static MetallicMaterial New(float3 f0, float roughness, ISampler samp){
		MetallicMaterial brdf;
		brdf.Init(f0, roughness, samp);
		return brdf;
	}

	BSDFSample Evaluate(Surface surf, float3 Wr, float3 Wi){
		return Fs.Evaluate(surf, Wr, Wi);
	}

	BSDFSample Sample(Surface surf, float3 Wr, out float3 Wi){
		BSDFSample res;
		res = Fs.Sample( surf, Wr, Wi );

		if (res.pdf != 0)
		{
			float3 H = normalize( Wr + Wi );
			float3 f = Fs.Fresnel( H, Wi );
			float f2 = (f.x + f.y + f.z)/3.0;
			res.pdf *= f2;
			res.pdf += (1.0 - f2) * max(0, dot(surf.nor, Wi)) * INV_PI;

			BSDFSample eval = Evaluate(surf, Wr, Wi);
			
			eval.value *= f;

			res.value = eval.value;
			res.type = eval.type;
		}

		return res;
	}
};

class DielectricMaterial : AbstractBSDF {
	GGXSpecularBRDF Fs;
	bool transmitting;
	float3 randXYZ;

	void Init(float roughness, float ior, ISampler samp)
	{
		this.randXYZ = float3(samp.SampleFloat2(), samp.SampleFloat());
		Fs.Init(roughness, float3(ior, ior, ior), true, this.randXYZ);
	}
	
	static DielectricMaterial New(float roughness, float ior, ISampler samp){
		DielectricMaterial bsdf;
		bsdf.Init(roughness, ior, samp);
		return bsdf;
	}

	BSDFSample Evaluate(Surface surf, float3 Wr, float3 Wi)
	{
		BSDFSample res = (BSDFSample)0;

		if (dot(surf.nor, Wi) > 0)
		{
			float3 H = normalize(Wr + Wi);
			float F = Fs.Fresnel(H, Wi).x;

			res = Fs.Evaluate(surf, Wr, Wi);

			float multiplier = this.randXYZ.z > F ? 1.0 - F : F;

			res.value *= multiplier;
			res.pdf *= multiplier;
		}

		return res;
	}

	BSDFSample Sample(Surface surf, float3 Wr, out float3 Wi)
	{
		BSDFSample res;
		res = Fs.Sample(surf, Wr, Wi);

		if (res.pdf != 0){
			BSDFSample eval = Evaluate(surf, Wr, Wi);
			res.value = eval.value;
			res.pdf = eval.pdf;
			res.type = eval.type;
		}

		return res;
	}
};

interface IMaterialModel {
	BSDFSample Evaluate(Material mat, Surface surf, ISampler samp, float3 Wr, float3 Wi);
	BSDFSample Sample(Material mat, Surface surf, ISampler samp, float3 Wr, out float3 Wi);
};

class PrimitiveMaterialModel : IMaterialModel {
	BSDFSample Evaluate(Material mat, Surface surf, ISampler samp, float3 Wr, float3 Wi)
	{
		return Eval(mat, surf, Wr, Wi, true, samp);
	}

	BSDFSample Sample(Material mat, Surface surf, ISampler samp, float3 Wr, out float3 Wi)
	{
		return Eval(mat, surf, Wr, Wi, false, samp);
	}

	BSDFSample Eval(Material mat, Surface surf, float3 Wr, inout float3 Wi, bool brdfOnly, ISampler samp){
		BSDFSample bsamp = (BSDFSample)0;
		bsamp.type = NULL_BSDF_TYPE;
		if (!brdfOnly) Wi = (float3)0;

		switch (mat.type)
		{
			case DIFFUSEDIELECTRIC:{
				DiffuseDielectricMaterial brdf = DiffuseDielectricMaterial::New(mat.colour.rgb, mat.roughness, samp);
				if (brdfOnly) {
					bsamp = brdf.Evaluate( surf, Wr, Wi );
				} else {
					bsamp = brdf.Sample( surf, Wr, Wi );
				}
				break;}
			case METALLIC:{
				MetallicMaterial brdf = MetallicMaterial::New(mat.colour.rgb, mat.roughness, samp);
				if (brdfOnly) {
					bsamp = brdf.Evaluate( surf, Wr, Wi );
				} else {
					bsamp = brdf.Sample( surf, Wr, Wi );
				}
				break;}
			case EMISSIVE:
				break;
			case DIELECTRIC:{
				DielectricMaterial brdf = DielectricMaterial::New(mat.roughness, mat.ior, samp);
				if (brdfOnly) {
					bsamp = brdf.Evaluate(surf, Wr, Wi);
				} else {
					bsamp = brdf.Sample(surf, Wr, Wi);
				}
				break;}
			default:
				break;
		}

		return bsamp;
	}
};


#endif