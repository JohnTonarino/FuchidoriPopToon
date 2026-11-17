// Copyright (c) 2026 JohnTonarino
// Released under the MIT license
// JTN_Lighting v 1.1.0
#ifndef JTN_LIGHTING_INCLUDED
#define JTN_LIGHTING_INCLUDED

#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
#include "VRCLightVolumes/LightVolumes.cginc"
#include "OpenLit/OpenLit.cginc"
#include "JTN_Properties.cginc"

inline half JTN_Luminance(half3 color)
{
    return dot(color, half3(0.299h, 0.587h, 0.114h));
}

inline half3 JTN_LimitLight(half3 lightColor)
{
    half luminance = JTN_Luminance(lightColor);
    lightColor = lerp(lightColor, luminance.xxx, _MonochromeLighting);
    lightColor = min(lightColor, _LightMaxLimit.xxx);
    return max(lightColor, _LightMinLimit.xxx);
}

inline float2 JTN_TriplanarUV3D(float3 positionWS, float3 normalWS, float scale) {
    float3 localPos = mul(unity_WorldToObject, float4(positionWS, 1.0)).xyz;
    float3 localNormal = UnityWorldToObjectDir(normalWS);
    float3 n = abs(normalize(localNormal));

    if (n.z >= n.x && n.z >= n.y) { return localPos.xy * scale; }
    else if (n.x >= n.y) { return float2(localPos.z, localPos.y) * scale; }
    else { return float2(localPos.x, localPos.z) * scale; }
}

inline half3 JTN_LightVolumeLighting(float3 positionWS, half3 normalWS)
{
    float3 lightL0;
    float3 lightL1R;
    float3 lightL1G;
    float3 lightL1B;

    LightVolumeSH(positionWS, lightL0, lightL1R, lightL1G, lightL1B);
    half3 volumeLight = LightVolumeEvaluate(normalize(normalWS), lightL0, lightL1R, lightL1G, lightL1B);

    return JTN_LimitLight(volumeLight);
}

inline half JTN_SDFFaceLitFactor(float2 uv, half3 lightDirection)
{
    half3 objectRight   = normalize(unity_ObjectToWorld._m00_m10_m20);
    half3 objectUp      = normalize(unity_ObjectToWorld._m01_m11_m21);
    half3 objectForward = normalize(unity_ObjectToWorld._m02_m12_m22);

    half isUpright = (objectUp.y - lightDirection.y) < 0.0h ? 1.0h : -1.0h;
    half rightDotLight = dot(objectRight.xz, lightDirection.xz)*isUpright;
    half forwardDotLight = dot(objectForward.xz, lightDirection.xz)*isUpright;

    half sdfRight = tex2D(_SDFMaskTex, float2(1.0 - uv.x, uv.y)).r;
    half sdfLeft = tex2D(_SDFMaskTex, uv).r;
    half sdfThreshold = rightDotLight < 0.0h ? sdfRight : sdfLeft;

    half directionalValue = forwardDotLight * 0.5h + 0.5h;
    half signedDist = directionalValue - sdfThreshold;

    half aa = fwidth(signedDist);
    half edge = max(max(_ShadowSmoothness, aa), 0.0001h);
    return 1.0h- smoothstep(-edge, edge, signedDist);
}

inline half3 JTN_SDFFaceShadowTint(float2 uv, half litFactor)
{
    half3 shadowTexture = tex2D(_ShadowTex, uv).rgb;
    half3 faceShadow = shadowTexture * _ShadowColor1.rgb;
    half3 toonTint = lerp(faceShadow, half3(1, 1, 1), litFactor);

    return lerp(half3(1, 1, 1), toonTint, saturate(_ShadowStrength));
}

inline half3 JTN_ShadowTint(float2 uv, half lightLevel)
{
    half aa = fwidth(lightLevel);
    half edge = max(max(_ShadowSmoothness, aa), 0.0001h);
    half leaveSecondShadow = smoothstep(_ShadowStep1 - edge, _ShadowStep1 + edge, lightLevel);
    half becomeLit = smoothstep(_ShadowStep2 - edge, _ShadowStep2 + edge, lightLevel);

    half3 shadowTexture = tex2D(_ShadowTex, uv).rgb;
    half3 secondShadow = shadowTexture * _ShadowColor2.rgb;
    half3 firstShadow = shadowTexture * _ShadowColor1.rgb;
    half3 toonTint = lerp(secondShadow, firstShadow, leaveSecondShadow);
    toonTint = lerp(toonTint, half3(1.0h, 1.0h, 1.0h), becomeLit);

    return lerp(half3(1.0h, 1.0h, 1.0h), toonTint, _ShadowStrength);
}

inline half JTN_LitFactor(float2 uv, half3 normalWS, half3 lightDirection)
{
    if (_UseSDF != 0u)
    {
        return JTN_SDFFaceLitFactor(uv, lightDirection);
    }

    half normalLight = dot(normalWS, lightDirection) * 0.5h + 0.5h;
    return normalLight;
}

#endif