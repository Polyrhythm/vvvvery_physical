#ifndef __SAMPLING_FXH__
#define __SAMPLING_FXH__

#include "math.fxh"
#include "random.fxh"

interface ISampler {
	uint   SampleInt( uint p );
	float  SampleFloat();
	float2 SampleFloat2();
};

static class NullSamplerClass : ISampler {
	uint SampleInt( uint p ){
		return 0;
	}
	float SampleFloat(){
		return 0;
	}
	float2 SampleFloat2(){
		return 0;
	}
} NullSampler;

class RandomSampler : ISampler{
	LCG lcg;

	void Init( uint seed ){
		lcg.seed = seed;
	}

	static RandomSampler New( uint seed ){
		RandomSampler self;
		self.Init( seed );
		return self;
	}

	uint SampleInt( uint p ){
		return lcg.GetUInt() % p;
	}
	float SampleFloat(){
		return lcg.GetFloat();
	}
	float2 SampleFloat2(){
		return lcg.GetFloat2();
	}
};

// http://www.rorydriscoll.com/2009/01/07/better-sampling/
// https://pathtracing.wordpress.com/2011/03/03/cosine-weighted-hemisphere/
float3 sampleCosineWeightedHemisphere( float3 N, float2 rand, out float pdf ){
	float u = rand.x;
	float v = rand.y;

	float cosTheta = sqrt(1.0-u);
	float sinTheta = sqrt(u);
	float phi = PI2 * v;

	pdf = cosTheta * INV_PI;

	float3 T, B;
	makeOrthonormalBasis( N, T, B );

	return (sinTheta * cos(phi) * T)
	     + (sinTheta * sin(phi) * B)
	     + (cosTheta * N);
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