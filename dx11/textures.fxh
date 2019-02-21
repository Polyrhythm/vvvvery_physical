#ifndef __TEXTURES_FXH__
#define __TEXTURES_FXH__

#include "math.fxh"

float2 getEquirectUV(const float3 wNor, const float flipEnvMap) {
	float phi = acos(wNor.y);
	float theta = atan2(flipEnvMap * wNor.x, wNor.z) + PI;
	return float2(theta / PI2, phi / PI);
}

float2 getEquirectUV(const float3 wNor) {
	return getEquirectUV(wNor, -1.0);
}

#endif