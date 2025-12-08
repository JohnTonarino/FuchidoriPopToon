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
fixed fpt_rimLighting(float3 worldPos, float2 uv, float3 viewDir, float3 N) {
    fixed4 rimLightMask = tex2D(_RimLightMask, uv);

    float2 rimUV  = TriplanarUV3D(worldPos, N, _RimPatternScale);
    float  rimPat = tex2D(_RimPatternTex, rimUV).r;

    return pow(1. - saturate(dot(viewDir, N)), 2.) * _RimLightStrength * rimLightMask.x*rimPat;
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

fixed3 CalculateShadow(g2f i, float3 N, float3 L, float NdotL){
    fixed4 shadowTexColor = tex2D(_ShadowTex, i.uv);
    fixed4 shadowColor1st = shadowTexColor * _ShadowOverlayColor1st;
    fixed4 shadowColor2nd = shadowTexColor * _ShadowOverlayColor2nd;

    float  shadowBlend = smoothstep(NdotL-_ShadowEdgeSmoothness, NdotL+_ShadowEdgeSmoothness, NdotL*NdotL-_ShadowWidth);
    fixed3 shadowColor = lerp(shadowColor1st.rgb, shadowColor2nd.rgb, shadowBlend);

    float lightIntensity = 0.;

    if(_SDFOn){
        half3 right = unity_ObjectToWorld._m00_m10_m20;
        half3 up = unity_ObjectToWorld._m01_m11_m21;
        half3 forward = unity_ObjectToWorld._m02_m12_m22;
        // Up or not
        half isUpright = (up.y - L.y) < 0.? 1.:-1.;
        
        half FdotL = dot(forward.xz, L.xz)*isUpright;
        half RdotL = dot(right.xz, L.xz)*isUpright;

        half4 R_sdfMask = tex2D(_SDFMaskTex, float2(1.-i.uv.x,i.uv.y));
        half4 L_sdfMask  = tex2D(_SDFMaskTex, i.uv);

        half faceShadowThreshold = RdotL < 0.? R_sdfMask.r : L_sdfMask.r;

        float normalizedFdotL = (.5*FdotL)+.5;
        lightIntensity = 1.-smoothstep(faceShadowThreshold-_ShadowEdgeSmoothness, faceShadowThreshold+_ShadowEdgeSmoothness, normalizedFdotL);
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

void CalculateMaterialEffects(inout fixed4 col, g2f i, float3 viewDir, float3 N) {
    // MatCap
    fixed4 matcap = tex2D(_MatCap, i.viewUV) * tex2D(_MatCapMask, i.uv);
    col.rgb = _MatCapType==0?
                lerp(col.rgb, matcap.rgb, _MatCapStrength):
                col.rgb*lerp(1., matcap.rgb, _MatCapStrength);

    // RimLighting
    fixed rim = fpt_rimLighting(i.positionWS, i.uv, viewDir, N);
    col.rgb = lerp(col.rgb, col.rgb*_RimColor.rgb, rim);

    // alpha
    fixed4 alphaMask = tex2D(_TransparentMask, i.uv);
    col.a *= OpenLitGray(alphaMask.rgb);
    if (col.a < _TransparentLevel) discard;

    // emissive
    fixed4 emissiveTex = tex2D(_EmissiveTex, i.uv);
    col.rgb += emissiveTex.rgb * _EmissiveColor;
}
#endif // FPT_LIGHTING_INCLUDED