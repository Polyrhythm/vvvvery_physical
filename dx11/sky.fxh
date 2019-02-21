#ifndef __SKY_FXH__
#define __SKY_FXH__

#include "common.fxh"

interface IAtmosphere {
	float3 render(Ray ray);
};

class AbstractAtmosphere : IAtmosphere {
	float3 render(Ray ray);
};

class SimpleSky : AbstractAtmosphere {
	static SimpleSky New() {
		SimpleSky simpleSky;
		
		return simpleSky;
	}
	
	float3 render(Ray ray) {
		return float3(0.1, 0.2, 0.3);
	}
};

#endif