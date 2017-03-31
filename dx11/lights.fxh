#ifndef __LIGHTS_FXH__
#define __LIGHTS_FXH__

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

float3 refract (const float3 i, const float3 n, const float ior)
{
	float cosi = clamp(dot(i, n), -1.0, 1.0);
	float3 nref = n;
	float NoI = dot(nref, i);
	float etai = 1, etat = ior;
	
	// check if hit is outside the surface
	if (NoI < 0) {
		NoI = -NoI;
	}
	else {
		nref = -n;
		float tmp = etai;
		etai = etat;
		etat = tmp;
	}
	
	float eta = etai / etat; // get ratio of indices of refraction
	
	float k = 1 - eta * eta * (1 - cosi * cosi);
	
	return k < 0 ? 0 : eta * i + (eta * cosi - sqrt(k)) * n;
}

float fresnel(const float3 i, const float3 n, const float ior)
{
	float cosi = clamp(dot(i, n), -1.0, 1.0);
	float etai = 1, etat = ior;
	if (cosi > 0) {
		float tmp = etai;
		etai = etat;
		etat = tmp;
	}
	
	// snell's law
	float sint = etai / etat * sqrt(max(0.0, 1.0 - cosi * cosi));
	
	if (sint >= 1) {
		return 1;
	}
	else {
		float cost = sqrt(max(0.0, 1.0 - sint * sint));
		cosi = abs(cosi);
		float Rs = ((etat * cosi) - (etai * cost)) / ((etat * cosi) + (etai * cost));
		float Rp = ((etai * cosi) - (etat * cost)) / ((etai * cosi) + (etat * cost));
		
		return (Rs * Rs + Rp * Rp) / 2.0;
	}
}

#endif