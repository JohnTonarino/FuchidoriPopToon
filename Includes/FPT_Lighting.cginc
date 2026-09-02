// Copyright (c) 2024 JohnTonarino
// Released under the MIT license
// FuchidoriPopToon v 1.0.10
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
float fpt_specular(float3 worldPos, float3 L, float3 viewDir, float3 N){
    float3 H = normalize(L-viewDir);
    float NH = saturate(dot(N,H));

    float2 specUV   = TriplanarUV3D(worldPos, N, _SpecPatternScale);
    float  specPat  = tex2D(_SpecPatternTex, specUV).r;

    return _SpecularStrength*specPat*smoothstep( _SpecularBias - .02, _SpecularBias + .02, NH);
}
fixed3 lv_SampleVolumes(fixed3 albedo, g2f i, float3 viewDir) {
    // VRC Light Volumes
    float3 lv_L0, lv_L1r, lv_L1g, lv_L1b;
    LightVolumeSH(i.positionWS, lv_L0, lv_L1r, lv_L1g, lv_L1b);

    // Diffuse Contribution from Light Volumes
    fixed3 LVEvaluate = LightVolumeEvaluate(i.normalWS, lv_L0, lv_L1r, lv_L1g, lv_L1b);

    return LVEvaluate * albedo;
}

inline half FPT_SDFFaceLitFactor(float2 uv, half3 lightDirection)
{
    half3 objectRight = normalize(unity_ObjectToWorld._m00_m10_m20);
    half3 objectForward = normalize(unity_ObjectToWorld._m02_m12_m22);
    half rightDotLight = dot(objectRight.xz, lightDirection.xz);
    half forwardDotLight = dot(objectForward.xz, lightDirection.xz);

    half sdfRight = tex2D(_SDFMaskTex, float2(1.0 - uv.x, uv.y)).r;
    half sdfLeft = tex2D(_SDFMaskTex, uv).r;
    half sdfThreshold = rightDotLight < 0.0h ? sdfRight : sdfLeft;
    half directionalValue = forwardDotLight * 0.5h + 0.5h;

    return 1.0h - smoothstep(
        sdfThreshold - _ShadowEdgeSmoothness,
        sdfThreshold + _ShadowEdgeSmoothness,
        directionalValue
    );
}

fixed3 CalculateShadow(g2f i, float3 N, float3 L){
    float NdotL = dot(N, L);
    fixed4 shadowTexColor = tex2D(_ShadowTex, i.uv);
    fixed4 shadowColor1st = shadowTexColor * _ShadowOverlayColor1st;
    fixed4 shadowColor2nd = shadowTexColor * _ShadowOverlayColor2nd;

    float  shadowBlend = smoothstep(NdotL-_ShadowEdgeSmoothness, NdotL+_ShadowEdgeSmoothness, NdotL*NdotL-_ShadowWidth);
    fixed3 shadowColor = lerp(shadowColor1st.rgb, shadowColor2nd.rgb, shadowBlend);

    float lightIntensity = 0.;

    if(_SDFOn){
        lightIntensity = FPT_SDFFaceLitFactor(i.uv, L);
    }
    else{
        lightIntensity = NdotL;
    }

    float q = fwidth(lightIntensity);
    float e = max(_ShadowEdgeSmoothness, q);

    float litFactor = smoothstep(_ShadowThreshold - e, _ShadowThreshold + e, lightIntensity);
    
    float2 shUV = TriplanarUV3D(i.positionWS, N, _ShadowPatternScale);
    float  shPat  = tex2D(_ShadowPatternTex, shUV).r;
    float finalMask = 1. - shPat * (1. - litFactor);

    fixed3 finalColor = 0.;
    finalColor = lerp(shadowColor, fixed3(1.,1.,1.), finalMask);
    return lerp(fixed3(1.,1.,1.), finalColor, _ShadowStrength);
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

    return 1.0h - (1.0h - baseColor.rgb) * (1.0h - _RimColor * rim) * rimPat;
}

void CalculateMaterialEffects(inout fixed4 col, g2f i, float3 viewDir, float3 N) {
    // alpha
    fixed4 alphaMask = tex2D(_TransparentMask, i.uv);
    col.a *= OpenLitGray(alphaMask.rgb);
    if (col.a < _TransparentLevel) discard;

    // emissive
    fixed4 emissiveTex = tex2D(_EmissiveTex, i.uv);
    col.rgb += emissiveTex.rgb * _EmissiveColor;
}
#endif // FPT_LIGHTING_INCLUDED