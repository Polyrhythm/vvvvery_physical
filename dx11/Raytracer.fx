
#include "camera.fxh"
#include "tracer.fxh"

float4 TextureSize : TARGETSIZE;

struct VS_IN
{
	float4 PosO : POSITION;
	float4 TexCd : TEXCOORD0;
};

struct vs2ps
{
    float4 PosWVP: SV_POSITION;
    float4 TexCd: TEXCOORD0;
};

float3 render(const float2 uv, const Options options, float4 pos)
{
	float scale = tan(radians(options.fov * 0.5));
	float imageAspectRatio = TextureSize.x / TextureSize.y;
	
	uint seed = jenkins_hash(uint3(pos.yx,SampleIndex));
	RandomSampler randSampler = RandomSampler::New( seed );
	float2 st = randSampler.SampleFloat2()-0.5;
	pos.xy += st;
	
	Ray ray;
	ray.origin = tVI[3].xyz;
	ray.dir = UVtoEYE(uv.xy + st/TextureSize.xy);
	
	return castRay(ray, pos);
}

// ********
// Shaders
// ********
vs2ps VS(VS_IN input)
{
    vs2ps output;
    output.PosWVP  = input.PosO;
    output.TexCd = input.TexCd;
    return output;
}

float4 PS(vs2ps In): SV_Target
{
	Options opts;
	opts.fov = 51.52;
	float3 colour = render(In.TexCd.xy, opts, In.PosWVP);
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
