#ifndef __MATERIALS_FXH__
#define __MATERIALS_FXH__

static const uint DIFFUSE = 0;
static const uint EMISSIVE = 2;

struct Material
{
	uint type;
	float ior;
	float roughness;
	float4 colour;
};

#define materialBufferStride 7

#endif