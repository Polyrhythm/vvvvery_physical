#ifndef __SAMPLING_FXH__
#define __SAMPLING_FXH__

#include "math.fxh"
#include "random.fxh"

// http://www.rorydriscoll.com/2009/01/07/better-sampling/
// https://pathtracing.wordpress.com/2011/03/03/cosine-weighted-hemisphere/
float3 cosineWeightedDirection( float3 normal, float2 rand )
{
	float u = rand.x;
	float v = rand.y;

	float r = sqrt(u);
	float angle = PI2 * v;

	float3 h = normal;
	if( abs(h.x) <= abs(h.y) && abs(h.x) <= abs(h.z) ){
		h.x = 1.0;
	} else if( abs(h.y) <= abs(h.x) && abs(h.y) <= abs(h.z) ){
		h.y = 1.0;
	} else {
		h.z = 1.0;
	}

	float3 sdir = normalize(cross(h,normal));
	float3 tdir = normalize(cross(sdir,normal));

	return (r * cos(angle) * sdir) + (r * sin(angle) * tdir) + (sqrt(max(0,1.0 - u)) * normal);
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