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

float3 uniformRandomDirection( float2 rand )
{
	float u = rand.x;
	float v = rand.y;
	float z = 1.0 - 2.0 * u;
	float r = sqrt(1.0 - z * z);
	float angle = PI2 * v;
	
	return float3(r * cos(angle), r* sin(angle), z);
}

float3 uniformHemisphereDirection( float3 normal, float2 rand ){
	float3 dir = uniformRandomDirection( rand );
	return dot(dir,normal) < 0 ? -dir : dir;
}

#endif