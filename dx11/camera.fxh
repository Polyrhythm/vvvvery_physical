#ifndef __CAMERA_FXH__
#define __CAMERA_FXH__

#include "shaderinput.fxh"

float3 UVtoEYE(float2 UV)
{
    return normalize(
        mul(
            float4(
                mul(float4((UV.xy * 2 - 1) * float2(1, -1), 0, 1), tPI).xy,
                1,
                0
            ),
            tVI
        ).xyz
    );
}

#endif