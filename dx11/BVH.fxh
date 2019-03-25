#ifndef __BVH_FXH__
#define __BVH_FXH__

static const int LEAF_SIZE = 2;

struct BVHNode
{
	float3 minBounds;
	float3 maxBounds;
	int isLeaf;
	int leftIndex;
	int rightIndex;
	int splitAxis;
	int leaves[LEAF_SIZE];
};

#endif