// Copyright (c) 2024 JohnTonarino
// Released under the MIT license
// FuchidoriPopToon v 1.1.0
// FPT_Lighting.cginc
#ifndef FPT_LIGHTING_INCLUDED
#define FPT_LIGHTING_INCLUDED

#include "FPT_Core.cginc"

float2 TriplanarUV3D(float3 worldPos, float3 normal, float scale) {
    float3 localPos = mul(unity_WorldToObject, float4(worldPos, 1.0)).xyz;
    float3 localNormal = UnityWorldToObjectDir(normal);
    float3 n = abs(normalize(localNormal));

    // 前後面
    if (n.z >= n.x && n.z >= n.y) { return localPos.xy * scale; }
    // 左右面
    else if (n.x >= n.y) { return float2(localPos.z, localPos.y) * scale; }
    // 上下面
    else { return float2(localPos.x, localPos.z) * scale; }
}

inline void FPT_UnpackOpenLitData(g2f i, out OpenLitLightDatas lightDatas)
{
    UnpackLightDatas(lightDatas, i.lightDatas);
}

inline half3 FPT_Specular(float3 worldPos, half3 normalWS, half3 lightDirection, half3 viewDirection)
{
    half3 halfDirection = normalize(lightDirection + viewDirection);
    half normalHalf = saturate(dot(normalWS, halfDirection));

    float2 specUV   = TriplanarUV3D(worldPos, normalWS, _SpecPatternScale);
    float  specPat  = tex2D(_SpecPatternTex, specUV).r;

    half aa   = fwidth(normalHalf);
    half edge = max(max(_SpecularSmoothness, aa), 0.0001h);

    half specular = smoothstep( _SpecularSize - edge, _SpecularSize + edge, normalHalf);
    return _SpecularStrength*_SpecularColor.rgb*specPat*specular;
}


inline half FPT_SDFFaceLitFactor(float2 uv, half3 lightDirection)
{
    half3 objectRight   = normalize(unity_ObjectToWorld._m00_m10_m20);
    half3 objectUp      = normalize(unity_ObjectToWorld._m01_m11_m21);
    half3 objectForward = normalize(unity_ObjectToWorld._m02_m12_m22);

    half isUpright = (objectUp.y - lightDirection.y) < 0.0h ? 1.0h : -1.0h;
    half rightDotLight   = dot(objectRight.xz, lightDirection.xz)*isUpright;
    half forwardDotLight = dot(objectForward.xz, lightDirection.xz)*isUpright;

    half sdfRight = tex2D(_SDFMaskTex, float2(1.0 - uv.x, uv.y)).r;
    half sdfLeft  = tex2D(_SDFMaskTex, uv).r;
    half sdfThreshold = rightDotLight < 0.0h ? sdfRight : sdfLeft;

    half directionalValue = forwardDotLight * 0.5h + 0.5h;
    half signedDist = directionalValue - sdfThreshold;
    float aa = fwidth(signedDist);
    float edge = max(_ShadowEdgeSmoothness, aa);
    return 1.0h- smoothstep(-edge, edge, signedDist);
}

inline half FPT_LitFactor(g2f i, half3 normalWS, half3 lightDirection)
{
    if (_SDFOn > 0)
    {
        return FPT_SDFFaceLitFactor(i.uv, lightDirection);
    }
    else{
        return dot(normalWS, lightDirection) * 0.5h + 0.5h;
    }
}

inline half3 FPT_SDFFaceShadowTint(float2 uv, half lightLevel)
{
    half3 shadowTexture = tex2D(_ShadowTex, uv).rgb;
    half3 faceShadow = shadowTexture * _ShadowOverlayColor1st.rgb;

    half3 toonTint = lerp(faceShadow, half3(1.0h, 1.0h, 1.0h), lightLevel);
    return toonTint;
}

inline half3 FPT_ShadowTint(float2 uv, half lightLevel)
{
    float aa = fwidth(lightLevel);
    half edge = max(_ShadowEdgeSmoothness, aa);
    half leaveSecondShadow = smoothstep(_ShadowStep1 - edge, _ShadowStep1 + edge, lightLevel);
    half becomeLit = smoothstep(_ShadowStep2 - edge, _ShadowStep2 + edge, lightLevel);

    half3 shadowTexture = tex2D(_ShadowTex, uv).rgb;
    half3 secondShadow = shadowTexture * _ShadowOverlayColor2nd.rgb;
    half3 firstShadow  = shadowTexture * _ShadowOverlayColor1st.rgb;

    half3 toonTint = lerp(secondShadow, firstShadow, leaveSecondShadow);
    toonTint = lerp(toonTint, half3(1.0h, 1.0h, 1.0h), becomeLit);
    return toonTint;
}

inline half3 FPT_MatCap(float3 baseColor, float2 uv, half3 normalWS)
{
    half3 normalVS = mul((half3x3)UNITY_MATRIX_V, normalWS);
    float2 matCapUV = normalVS.xy * 0.5 + 0.5;
    half3 matCap = tex2D(_MatCap, matCapUV).rgb;
    half mask = tex2D(_MatCapMask, uv).r * _MatCapStrength;

    if (_MatCapType == 1)
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

inline half3 FPT_Rim(float3 worldPos, half3 baseColor, float2 uv, half3 normalWS, half3 viewDirection)
{
    half rimBase = 1.0h - saturate(dot(normalWS, viewDirection));
    half rimShape = pow(max(rimBase, 0.0001h), max(_RimPower, 0.0001h));

    half rim = smoothstep(0.5h - _RimSmoothness, 0.5h + _RimSmoothness, rimShape);
    rim *= tex2D(_RimLightMask, uv).r * _RimLightStrength;

    float2 rimUV  = TriplanarUV3D(worldPos, normalWS, _RimPatternScale);
    half rimPat = tex2D(_RimPatternTex, rimUV).r;
    rim *= rimPat;

    return 1.0h - (1.0h - baseColor.rgb) * (1.0h - _RimColor * rim);
}

inline half3 FPT_LightVolumeLighting(g2f i, half3 normalWS)
{
    float3 lightL0;
    float3 lightL1R;
    float3 lightL1G;
    float3 lightL1B;

    LightVolumeSH(i.positionWS, lightL0, lightL1R, lightL1G, lightL1B);
    half3 volumeLight = LightVolumeEvaluate(normalize(normalWS), lightL0, lightL1R, lightL1G, lightL1B);

    return clamp(volumeLight, 0.0h, _LightMaxLimit);
}

inline half3 FPT_BaseLighting(g2f i, half3 albedo, half3 normalWS, half3 lightDirection, half attenuation)
{
    half lightLevel = FPT_LitFactor(i, normalWS, lightDirection);

    half3 shadowTint = _SDFOn > 0 ?
        FPT_SDFFaceShadowTint(i.uv, lightLevel):
        FPT_ShadowTint(i.uv, lightLevel);
    shadowTint = lerp(half3(1.0h, 1.0h, 1.0h), shadowTint, _ShadowStrength);

    float2 toneUV  = TriplanarUV3D(i.positionWS, normalWS, _ShadowPatternScale);
    half tone = tex2D(_ShadowPatternTex, toneUV).r;
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
    if (_VRCLightVolumesOn > 0)
    {
        half3 volumeLight = FPT_LightVolumeLighting(i, normalWS);
        half volumeBlend = _VRCLightVolumesStrength * LightVolumesEnabled();
        lightColor = lerp(openLitLight, volumeLight, volumeBlend);
    }
    lightColor = lerp(lightColor, half3(1.0h, 1.0h, 1.0h), _AsUnlit);

    return albedo * shadowTint * lightColor;
}
#endif // FPT_LIGHTING_INCLUDED