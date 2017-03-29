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
	return 1 / sqrt(length(pos - lightPos));
}

float getLambertianDiffuse(const float3 lightDir, const float3 n)
{
	return saturate(dot(lightDir, n));
}

#endif