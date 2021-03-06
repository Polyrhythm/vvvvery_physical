#ifndef __LIGHTS_FXH__
#define __LIGHTS_FXH__

#include "common.fxh"

static const int POINT = 0;
static const int SPOTLIGHT = 1;
static const int AREA = 2;

struct Light
{
	int type;
	float4 colour;
	float intensity;
	row_major float4x4 transform;
	row_major float4x4 inverseTransform;
	float2 params;
};

interface ILight {
	float getAttenuation(float3 p, float2 st);
	float getPower();
};

class AbstractLight : ILight {
	float4x4 transform;
	float intensity;
	float getAttenuation(float3 p, float2 st);
	float3 getLightDir(float3 p, float2 st);
	float getPower();
};

class PointLight : AbstractLight {
	float3 pos;
	
	void init(float3 pos, float intensity)
	{
		this.pos = pos;
		this.intensity = intensity;
	}
	
	float getPower()
	{
		return this.intensity;
	}
	
	static PointLight New(float3 pos, float intensity)
	{
		PointLight light;
		light.init(pos, intensity);
		
		return light;
	}
	
	float3 getLightDir(float3 p, float2 st)
	{
		return normalize(this.pos - p);
	}
	
	float getAttenuation(float3 p, float2 st)
	{
		float3 diff = p - pos;
		float d2 = dot(diff, diff);
		return 1.0 / d2;
	}
	
};

class AreaLight : AbstractLight
{
	float3 pos;
	float2 size;
	float3 normal;
	float3 samplePoint;
	
	void init(float4x4 transform, float2 size, float intensity)
	{
		this.pos = transform[3].xyz;
		this.transform = transform;
		this.size = size;
		this.normal = normalize(mul(float4(0.0, 0.0, 1.0, 0.0), this.transform)).xyz;
		this.samplePoint = float3(-1, -1, -1);
		this.intensity = intensity;
	}
	
	float getPower()
	{
		return this.intensity;
	}
	
	float3 getLightDir(float3 p, float2 st)
	{
		if (this.samplePoint.x == -1.0)
		{
			this.calcSamplePoint(st);
		}
		
		return normalize(this.samplePoint - p);
	}
	
	void calcSamplePoint(float2 st)
	{
		float3 q = float3(1,0,0);
		if (abs(dot(q, this.normal)) > abs(dot(float3(0,1,0), this.normal)))
		{
			q = float3(0,1,0);
		}
		float3 u = cross(this.normal, q);
		float3 v = cross(this.normal, u);
		
		
		float2 r = st * size - (size * 0.5);
		
		this.samplePoint = this.pos + u * r.x + v * r.y;
	}
	
	static AreaLight New(float4x4 transform, float2 size, float intensity)
	{
		AreaLight light;
		light.init(transform, size, intensity);
		
		return light;
	}
	
	float getAttenuation(float3 p, float2 st)
	{
		if (this.samplePoint.x == -1.0)
		{
			this.calcSamplePoint(st);
		}
		
		float3 diff = p - this.samplePoint;
		float d2 = dot(diff, diff);
		return 1.0 / d2 * clamp(dot(normalize(diff), this.normal), 0.0, 1.0);
	}
};

class SpotLight : AbstractLight {
	float3 pos;
	float3 dir;
	float penumbra;
	float umbra;
	
	void init(float3 pos, float3 dir, float penumbra, float umbra, float intensity)
	{
		this.pos = pos;
		this.dir = dir;
		this.penumbra = penumbra;
		this.umbra = umbra;
		this.intensity = intensity;
	}
	
	static SpotLight New(float3 pos, float3 dir, float penumbra, float umbra, float intensity)
	{
		SpotLight light;
		light.init(pos, dir, penumbra, umbra, intensity);
		
		return light;
	}
	
	float3 getLightDir(float3 p, float2 st)
	{
		return normalize(this.pos - p);
	}
	
	float getPower()
	{
		return this.intensity;
	}
	
	float getAttenuation(float3 p, float2 st)
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
	float getAtten(Light light, float3 p, float2 st);
};

class PrimitiveLightModel : ILightModel {
	float getAtten(Light light, float3 p, float2 st)
	{
		float res = 0.0;
		
		switch(light.type) {
			case POINT:
				PointLight pl = PointLight::New(light.transform[3].xyz, light.intensity);
				res = pl.getAttenuation(p, st);
				break;
			
			case SPOTLIGHT:
				float3 pos = light.transform[3].xyz;
				float3 dir = normalize(light.transform[2].xyz);
				float penumbra = light.params.x;
				float umbra = light.params.y;
			
				SpotLight sl = SpotLight::New(pos, dir, penumbra, umbra, light.intensity);
				res = sl.getAttenuation(p, st);
				break;
			
			case AREA:
				float2 size = light.params;
				AreaLight al = AreaLight::New(light.transform, size, light.intensity);
				res = al.getAttenuation(p, st);
				break;
			
			default:
				break;
		}
		
		return res;
	}
	
	float getPower(Light light)
	{
		float res = 0.0;
		
		switch(light.type) {
			case POINT:
				PointLight pl = PointLight::New(light.transform[3].xyz, light.intensity);
				res = pl.getPower();
				break;
			
			case SPOTLIGHT:
				float3 pos = light.transform[3].xyz;
				float3 dir = normalize(light.transform[2].xyz);
				float penumbra = light.params.x;
				float umbra = light.params.y;
			
				SpotLight sl = SpotLight::New(pos, dir, penumbra, umbra, light.intensity);
				res = sl.getPower();
				break;
			
			case AREA:
				float2 size = light.params;
				AreaLight al = AreaLight::New(light.transform, size, light.intensity);
				res = al.getPower();
				break;
			
			default:
				break;
		}
		
		return res;
	}
	
	float3 getLightDir(Light light, float3 p, float2 st)
	{
		float3 res = float3(0,0,0);
		
		switch(light.type) {
			case POINT:
				PointLight pl = PointLight::New(light.transform[3].xyz, light.intensity);
				res = pl.getLightDir(p, st);
				break;
			
			case SPOTLIGHT:
				float3 pos = light.transform[3].xyz;
				float3 dir = normalize(light.transform[2].xyz);
				float penumbra = light.params.x;
				float umbra = light.params.y;
			
				SpotLight sl = SpotLight::New(pos, dir, penumbra, umbra, light.intensity);
				res = sl.getLightDir(p, st);
				break;
			
			case AREA:
				float2 size = light.params;
				AreaLight al = AreaLight::New(light.transform, size, light.intensity);
				res = al.getLightDir(p, st);
				break;
			
			default:
				break;
		}
		
		return res;
	}
};

#endif