#ifndef __RANDOM_FXH__
#define __RANDOM_FXH__

// LCGs Suck! Just not now.
class LCG {
	uint seed;

	static LCG New( uint seed ){
		LCG rand;
		rand.seed = seed;
		return rand;
	}

	/* Returns uint over interval [0,4294967296) */
	uint GetUInt(){
		return seed = (seed * 1664525 + 1013904223) % 0xFFFFFFFF;
	}

	/* Returns float over interval [0.0,1.0) */
	float GetFloat(){
		return GetUInt()/float(0xFFFFFFFF);
	}

	float2 GetFloat2(){
		return uint2(GetUInt(),GetUInt())/float(0xFFFFFFFF);
	}

	float3 GetFloat3(){
		return uint3(GetUInt(),GetUInt(),GetUInt())/float(0xFFFFFFFF);
	}
};

// Special variant jenkins hash for use in Cycles.
uint jenkins_hash(uint3 k)
{
// define some handy macros
#define rot(x,k) (((x)<<(k)) | ((x)>>(32-(k))))
#define final(a,b,c) \
{ \
	c ^= b; c -= rot(b,14); \
	a ^= c; a -= rot(c,11); \
	b ^= a; b -= rot(a,25); \
	c ^= b; c -= rot(b,16); \
	a ^= c; a -= rot(c,4);  \
	b ^= a; b -= rot(a,14); \
	c ^= b; c -= rot(b,24); \
}

	// now hash the data!
	uint len = 3;
	uint3 r = k + 0xdeadbeef + (len << 2) + 13;
	final(k.x, k.y, k.z);
	return k.z;

#undef rot
#undef final
}

float random(float3 scale, float seed, float4 pos)
{
	return frac(sin(dot(pos.xyz + seed, scale)) * 43758.5453 + seed);
}

#endif