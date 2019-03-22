#ifndef __COMMON_FXH__
#define __COMMON_FXH__

struct Options
{
	float fov;
};

struct Ray
{	
	float3 dir;
	float3 origin;
};

struct Surface {
	int matIdx;
	int texIdx;
	float3 pos;
	float3 nor;
	float2 uv;
};

struct Intersection {
	float U, V, T;
};

#endif