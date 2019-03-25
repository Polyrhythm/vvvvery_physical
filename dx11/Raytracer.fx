
#include "camera.fxh"
#include "tracer.fxh"

float4 TextureSize : TARGETSIZE;

Texture2D seedTex;

SamplerState seedSampler : IMMUTABLE
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
	AddressW = Wrap;
};

struct VS_IN
{
	float4 PosO : POSITION;
	float4 TexCd : TEXCOORD0;
};

struct vs2ps
{
    float4 PosWVP: SV_POSITION;
    float4 TexCd: TEXCOORD0;
	RandomSampler RandSampler: RANDSAMPLER;
};

float3 render(const float2 uv, const Options options, float4 pos,
	const RandomSampler randSampler)
{
	float scale = tan(radians(options.fov * 0.5));
	float imageAspectRatio = TextureSize.x / TextureSize.y;
	
	float2 st = randSampler.SampleFloat2()-0.5;
	pos.xy += st;
	
	uint3 seedColour = asuint(seedTex.Sample(seedSampler, uv).rgb);
	uint seed = jenkins_hash(seedColour + SampleIndex * 10.0);
	RandomSampler rtSampler = RandomSampler::New(seed);
	
	Ray ray;
	ray.origin = tVI[3].xyz;
	ray.dir = UVtoEYE(uv.xy + st/TextureSize.xy);
	
	return castRay(ray, pos, rtSampler);
}

// ********
// Shaders
// ********
vs2ps VS(VS_IN input)
{
    vs2ps output;
    output.PosWVP  = input.PosO;
    output.TexCd = input.TexCd;
	
	uint seed = jenkins_hash(uint3(input.PosO.yx, SampleIndex));
	RandomSampler randSampler = RandomSampler::New(seed);
	
	output.RandSampler = randSampler;
	
    return output;
}

float4 PS(vs2ps In): SV_Target
{
	Options opts;
	opts.fov = 51.52;
	float3 colour = render(In.TexCd.xy, opts, In.PosWVP, In.RandSampler);
    return float4(colour, 1);
}

technique10 Render
{
	pass P0
	{
		SetVertexShader(CompileShader(vs_4_0, VS()));
		SetPixelShader(CompileShader(ps_5_0, PS()));
	}
}
