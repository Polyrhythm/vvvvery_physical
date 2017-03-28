#ifndef __MATERIALS_FXH__
#define __MATERIALS_FXH__

struct Material
{
	uint type;
	float ior;
	float roughness;
	float4 colour;
};

#define materialBufferStride 7

#endif