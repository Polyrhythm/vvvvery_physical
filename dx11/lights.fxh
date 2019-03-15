#ifndef __LIGHTS_FXH__
#define __LIGHTS_FXH__

#include "common.fxh"

static const int POINT = 0;
static const int SPOTLIGHT = 1;

struct Light
{
	int type;
	float4 colour;
	float intensity;
	row_major float4x4 transform;
	float2 params;
};

interface ILight {
	float getAttenuation(float3 p);
};

class AbstractLight : ILight {
	float4x4 transform;
	float getAttenuation(float3 p);
};

class PointLight : AbstractLight {
	float3 pos;
	
	void init(float3 pos)
	{
		this.pos = pos;
	}
	
	static PointLight New(float3 pos)
	{
		PointLight light;
		light.init(pos);
		
		return light;
	}
	
	float getAttenuation(float3 p)
	{
		float3 diff = p - pos;
		float d2 = dot(diff, diff);
		return 1.0 / d2;
	}
};

class SpotLight : AbstractLight {
	float3 pos;
	float3 dir;
	float penumbra;
	float umbra;
	
	void init(float3 pos, float3 dir, float penumbra, float umbra)
	{
		this.pos = pos;
		this.dir = dir;
		this.penumbra = penumbra;
		this.umbra = umbra;
	}
	
	static SpotLight New(float3 pos, float3 dir, float penumbra, float umbra)
	{
		SpotLight light;
		light.init(pos, dir, penumbra, umbra);
		
		return light;
	}
	
	float getAttenuation(float3 p)
	{
		float3 surfDir = normalize(p - pos);
		float s = degrees(acos(dot(surfDir, dir)));
		
		float res = 0.0;
		
		if (s < penumbra)
		{
			res = 1.0;
		}
		else if (s < umbra)
		{
			res = (s - umbra) / (penumbra - umbra); 
		}
		else
		{
			res =  0.0;
		}
		
		return res;
	}
};

interface ILightModel {
	float getAtten(Light light, float3 p);
};

class PrimitiveLightModel : ILightModel {
	float getAtten(Light light, float3 p)
	{
		float res = 0.0;
		
		switch(light.type) {
			case POINT:
				PointLight pl = PointLight::New(light.transform[3].xyz);
				res = pl.getAttenuation(p);
				break;
			
			case SPOTLIGHT:
				float3 pos = light.transform[3].xyz;
				float3 dir = normalize(light.transform[2].xyz);
				float penumbra = light.params.x;
				float umbra = light.params.y;
			
				SpotLight sl = SpotLight::New(pos, dir, penumbra, umbra);
				res = sl.getAttenuation(p);
				break;
			
			default:
				break;
		}
		
		return res;
	}
	
	float3 getPos(Light light)
	{
		return light.transform[3].xyz;
	}
};

#endif