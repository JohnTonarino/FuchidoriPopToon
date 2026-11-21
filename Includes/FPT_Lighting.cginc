// Copyright (c) 2026 JohnTonarino
// Released under the MIT license
// FuchidoriPopToon v 1.2.0
// FPT_Lighting.cginc
#ifndef FPT_LIGHTING_INCLUDED
#define FPT_LIGHTING_INCLUDED

#include "FPT_Core.cginc"
#include "JTN_Lighting.cginc"

inline half3 FPT_Specular(float3 positionWS, half3 normalWS, half3 lightDirection, half3 viewDirection)
{
    half3 halfDirection = normalize(lightDirection + viewDirection);
    half normalHalf = saturate(dot(normalWS, halfDirection));

    float2 specUV   = JTN_TriplanarUV3D(positionWS, normalWS, _SpecPatternScale);
    float  specPat  = FPT_SAMPLE(_SpecPatternTex, specUV).r;

    half specular = JTN_AAStep(_SpecularSize, _SpecularSmoothness, normalHalf);
    return _SpecularStrength*_SpecularColor.rgb*specPat*specular;
}

inline half3 FPT_MatCap(float3 baseColor, float2 uv, half3 normalWS)
{
    half3 normalVS = mul((half3x3)UNITY_MATRIX_V, normalWS);
    float2 matCapUV = normalVS.xy * 0.5 + 0.5;
    half3 matCap = tex2D(_MatCap, matCapUV).rgb;
    half mask = FPT_SAMPLE(_MatCapMask, uv).r * _MatCapStrength;

    if (_MatCapType != 0u)
    {
        return baseColor * (half3(1.0h, 1.0h, 1.0h) + matCap * mask);
    }
    else
    {
        // Lerp: black is transparent, MatCap RGB is the visible color
        half matCapLevel = max(matCap.r, max(matCap.g, matCap.b));
        half amount = (matCapLevel * mask);
        return baseColor * (1.0h - amount) + matCap * mask;
    }
}

inline half3 FPT_Rim(float3 positionWS, half3 baseColor, float2 uv, half3 normalWS, half3 viewDirection)
{
    half rimBase = 1.0h - saturate(dot(normalWS, viewDirection));
    half rimShape = pow(max(rimBase, 0.0001h), max(_RimPower, 0.0001h));

    half rim = smoothstep(0.5h - _RimSmoothness, 0.5h + _RimSmoothness, rimShape);
    rim *= FPT_SAMPLE(_RimLightMask, uv).r * _RimLightStrength;

    float2 rimUV  = JTN_TriplanarUV3D(positionWS, normalWS, _RimPatternScale);
    half rimPat = FPT_SAMPLE(_RimPatternTex, rimUV).r;
    rim *= rimPat;

    return 1.0h - (1.0h - baseColor.rgb) * (1.0h - _RimColor.rgb * rim);
}

inline half3 FPT_BaseLighting(g2f i, half3 albedo, half3 normalWS, half3 lightDirection, half attenuation)
{
    half lightLevel = JTN_LitFactor(i.uv, normalWS, lightDirection);

    half3 shadowTint = _UseSDF != 0u ?
        JTN_SDFFaceShadowTint(i.uv, lightLevel):
        JTN_ShadowTint(i.uv, lightLevel);

    float2 toneUV  = JTN_TriplanarUV3D(i.positionWS, normalWS, _ShadowPatternScale);
    half tone = FPT_SAMPLE(_ShadowPatternTex, toneUV).r;
    shadowTint = 1.0h - tone * (1.0-shadowTint);

    OpenLitLightDatas lightDatas;
    FPT_UnpackOpenLitData(i, lightDatas);
    half3 ambient = lightDatas.indirectLight;
    half3 direct = lightDatas.directLight;
    half receiveAttenuation = lerp(1.0h, attenuation, (half)_ReceiveShadow);
    direct *= receiveAttenuation;

    half bandMultiplier = lerp(1.0h, lightLevel, _ShadowStrength);
    half3 openLitLight = lerp(ambient, direct, bandMultiplier);
    half3 lightColor = openLitLight;
    if (_VRCLightVolumesOn != 0u)
    {
        half3 volumeLight = JTN_LightVolumeLighting(i.positionWS, normalWS);
        half volumeBlend = _VRCLightVolumesStrength * LightVolumesEnabled();
        lightColor = lerp(openLitLight, volumeLight, volumeBlend);
    }
    lightColor = lerp(lightColor, half3(1.0h, 1.0h, 1.0h), _AsUnlit);

    return albedo * shadowTint * lightColor;
}
#endif // FPT_LIGHTING_INCLUDED