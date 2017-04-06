#ifndef __LIGHTS_FXH__
#define __LIGHTS_FXH__

#include "common.fxh"

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

#endif