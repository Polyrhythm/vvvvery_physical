#ifndef __BVH_FXH__
#define __BVH_FXH__

struct BVHNode
{
	float3 minBounds;
	float3 maxBounds;
	int isLeaf;
	int leftIndex;
	int rightIndex;
};

#endif