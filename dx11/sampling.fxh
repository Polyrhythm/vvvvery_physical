#ifndef __SAMPLING_FXH__
#define __SAMPLING_FXH__

#include "random.fxh"

// http://www.rorydriscoll.com/2009/01/07/better-sampling/
float3 cosineWeightedDirection(float3 normal, float seed, float4 pos)
{
	float u = random(float3(12.9898, 78.233, 151.7182), seed, pos);
	float v = random(float3(63.7264, 10.873, 623.6736), seed, pos);
	float r = sqrt(u);
	float angle = 6.283185307179586 * v;
	
	float3 sdir, tdir;
	if (abs(normal.x) < 0.5) {
		sdir = cross(normal, float3(1,0,0));
	} else {
		sdir = cross(normal, float3(0,1,0));
	}
	
	tdir = cross(normal, sdir);
	
	return r * cos(angle) * sdir + r * sin(angle) * tdir + sqrt(1.0 - u) * normal;
}

float3 uniformlyRandomDirection(float seed, float4 pos)
{
	float u = random(float3(12.9898, 78.233, 151.7182), seed, pos);
	float v = random(float3(63.7264, 10.873, 623.6736), seed, pos);
	float z = 1.0 - 2.0 * u;
	float r = sqrt(1.0 - z * z);
	float angle = 6.283185307179586 * v;
	
	return float3(r * cos(angle), r* sin(angle), z);
}

float3 uniformlyRandomVector(float seed, float4 pos)
{
	return uniformlyRandomDirection(seed, pos) * sqrt(random(
		float3(36.7539, 50.3658, 306.2759), seed, pos));
}

#endif