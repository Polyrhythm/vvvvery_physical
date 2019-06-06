#ifndef __MATERIALS_FXH__
#define __MATERIALS_FXH__

static const int DIFFUSEDIELECTRIC = 0;
static const int METALLIC = 1;
static const int EMISSIVE = 2;
static const int DIELECTRIC = 3;
static const int PARTICIPATINGMEDIA = 4;

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
		Fs.Init(roughness, 1.3294, this.randXYZ);
	}

	static DiffuseDielectricMaterial New(float3 albedo, float roughness, ISampler samp){
		DiffuseDielectricMaterial brdf;
		brdf.Init(albedo, roughness, samp);
		return brdf;
	}

	BSDFSample Evaluate(Surface surf, float3 Wo, float3 Wi){
		BSDFSample res = (BSDFSample)0;

		if(dot(surf.nor, Wi) > 0)
		{
			res.type = BRDF_TYPE;

			float3 Wh = normalize(Wo + Wi);
			float f = Fs.Fresnel(Wh, Wi).x;

			BSDFSample d = Fd.Evaluate(surf, Wo, Wi);
			BSDFSample s = Fs.Evaluate(surf, Wo, Wi);

			res.value = d.value * (1.0 - f) + s.value * f;
			res.pdf   = d.pdf * (1.0 - f) + s.pdf * f;
		}

		return res;
	}

	BSDFSample Sample( Surface surf, float3 Wo, out float3 Wi ){
		float f = Fs.Fresnel( surf.nor, Wo ).x;

		BSDFSample res;
		if (this.randXYZ.z < f)
		{
			res = Fs.Sample(surf, Wo, Wi);
		} else {
			res = Fd.Sample(surf, Wo, Wi);
		}

		if (res.pdf != 0)
		{
			BSDFSample eval = Evaluate(surf, Wo, Wi);
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
		Fs.Init(roughness, ior, this.randXYZ);
	}

	static MetallicMaterial New(float3 f0, float roughness, ISampler samp){
		MetallicMaterial brdf;
		brdf.Init(f0, roughness, samp);
		return brdf;
	}

	BSDFSample Evaluate(Surface surf, float3 Wo, float3 Wi){
		return Fs.Evaluate(surf, Wo, Wi);
	}

	BSDFSample Sample(Surface surf, float3 Wo, out float3 Wi){
		BSDFSample res;
		res = Fs.Sample( surf, Wo, Wi );

		if (res.pdf > 0.0)
		{
			float3 Wh = normalize(Wo + Wi);
			float3 F = Fs.Fresnel(Wh, Wi);

			BSDFSample eval = Evaluate(surf, Wo, Wi);
			
			eval.value *= F;

			res.value = eval.value;
			res.type = eval.type;
		}

		return res;
	}
};

class DielectricMaterial : AbstractBSDF {
	GGXSpecularBRDF Fr;
	GGXSpecularBTDF Ft;
	float roughness;
	float3 randXYZ;

	void Init(float roughness, float ior, ISampler samp)
	{
		this.roughness = roughness;
		this.randXYZ = float3(samp.SampleFloat2(), samp.SampleFloat());
		Fr.Init(roughness, float3(ior, ior, ior), this.randXYZ);
		Ft.Init(roughness, float3(ior, ior, ior), this.randXYZ);
	}
	
	static DielectricMaterial New(float roughness, float ior, ISampler samp){
		DielectricMaterial bsdf;
		bsdf.Init(roughness, ior, samp);
		return bsdf;
	}

	BSDFSample Evaluate(Surface surf, float3 Wo, float3 Wi)
	{
		BSDFSample res = (BSDFSample)0;

		float3 Wh = normalize(Wo + Wi);
		float f = Fr.Fresnel(Wh, Wi).x;

		BSDFSample r = Fr.Evaluate(surf, Wo, Wi);
		BSDFSample t = Ft.Evaluate(surf, Wo, Wi);

		res.value = t.value * (1.0 - f) + r.value * f + 1.0;
		res.pdf = t.pdf * (1.0 - f) + r.pdf * f + 1.0;

		return res;
	}

	BSDFSample Sample(Surface surf, float3 Wo, out float3 Wi)
	{
		BSDFSample res;

		float3 m = Ft.MicrofacetNormal(surf.nor, this.roughness, randXYZ.xy);
		float f = Ft.Fresnel(m, Wo).x;

		if (this.randXYZ.z < f)
		{
			res = Fr.Sample(surf, Wo, Wi);
			res.type = BRDF_TYPE;
		}
		else
		{
			res = Ft.Sample(surf, Wo, Wi);
			res.type = BTDF_TYPE;
		}

		if (res.pdf != 0)
		{
			BSDFSample eval = Evaluate(surf, Wo, Wi);
			res.value = eval.value;
			res.pdf = eval.pdf;
		}

		return res;
	}
};

class ParticipatingMediaMaterial : AbstractBSDF
{
	ParticipatingMediaBTDF Ft;

	void Init(float2 bounds, float density)
	{
		Ft.Init(density, bounds);
	}

	static ParticipatingMediaMaterial New(float density, float2 bounds)
	{
		ParticipatingMediaMaterial bsdf;
		bsdf.Init(bounds, density);

		return bsdf;
	}

	BSDFSample Evaluate(Surface surf, float3 Wo, float3 Wi)
	{
		BSDFSample res = Ft.Evaluate(surf, Wo, Wi);

		return res;
	}

	BSDFSample Sample(Surface surf, float3 Wo, out float3 Wi)
	{
		BSDFSample res = Ft.Sample(surf, Wo, Wi);

		return res;
	}
};

interface IMaterialModel {
	BSDFSample Evaluate(Material mat, Surface surf, float2 bounds, ISampler samp, float3 Wo, float3 Wi);
	BSDFSample Sample(Material mat, Surface surf, float2 bounds, ISampler samp, float3 Wo, out float3 Wi);
};

class PrimitiveMaterialModel : IMaterialModel {
	BSDFSample Evaluate(Material mat, Surface surf, float2 bounds, ISampler samp, float3 Wo, float3 Wi)
	{
		return Eval(mat, surf, bounds, Wo, Wi, true, samp);
	}

	BSDFSample Sample(Material mat, Surface surf, float2 bounds, ISampler samp, float3 Wo, out float3 Wi)
	{
		return Eval(mat, surf, bounds, Wo, Wi, false, samp);
	}

	BSDFSample Eval(Material mat, Surface surf, float2 bounds, float3 Wo, inout float3 Wi, bool brdfOnly, ISampler samp){
		BSDFSample bsamp = (BSDFSample)0;
		bsamp.type = NULL_BSDF_TYPE;
		if (!brdfOnly) Wi = (float3)0;

		switch (mat.type)
		{
			case DIFFUSEDIELECTRIC:{
				DiffuseDielectricMaterial brdf = DiffuseDielectricMaterial::New(mat.colour.rgb, mat.roughness, samp);
				if (brdfOnly) {
					bsamp = brdf.Evaluate(surf, Wo, Wi);
				} else {
					bsamp = brdf.Sample(surf, Wo, Wi);
				}
				break;}
			case METALLIC:{
				MetallicMaterial brdf = MetallicMaterial::New(mat.colour.rgb, mat.roughness, samp);
				if (brdfOnly) {
					bsamp = brdf.Evaluate(surf, Wo, Wi);
				} else {
					bsamp = brdf.Sample(surf, Wo, Wi);
				}
				break;}
			case EMISSIVE:
				break;
			case DIELECTRIC:{
				DielectricMaterial brdf = DielectricMaterial::New(mat.roughness, mat.ior, samp);
				if (brdfOnly) {
					bsamp = brdf.Evaluate(surf, Wo, Wi);
				} else {
					bsamp = brdf.Sample(surf, Wo, Wi);
				}
				break;}
			case PARTICIPATINGMEDIA:{
				ParticipatingMediaMaterial bsdf = ParticipatingMediaMaterial::New(mat.roughness, bounds);
				if (brdfOnly) {
					bsamp = bsdf.Evaluate(surf, Wo, Wi);
				} else {
					bsamp = bsdf.Sample(surf, Wo, Wi);
				}
				break;}
			default:
				break;
		}

		return bsamp;
	}
};


#endif