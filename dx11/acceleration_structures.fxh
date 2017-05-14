#define UNIFORM_GRID_RESOLUTION 4

interface IAccelerationStructure
{
	
};

class AbstractAccelerationStructure : IAccelerationStructure
{
	
};

struct Cell
{
	uint id;
	float3 boundMin, boundMax;
};

class UniformGrid : AbstractAccelerationStructure
{
	Cell cells[UNIFORM_GRID_RESOLUTION * UNIFORM_GRID_RESOLUTION];
	
	void init()
	{
		
	}
	
	static UniformGrid New()
	{
		UniformGrid grid;
		grid.init();
		
		return grid;
	}
	
	void constructCells(const float3 minBound, const float3 maxBound)
	{
		// TODO: Double for loop creating cells in our grid array.
	}
	
	
};