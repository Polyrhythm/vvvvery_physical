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

#endif