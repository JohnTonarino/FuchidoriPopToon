// Copyright (c) 2024 JohnTonarino
// Released under the MIT license
// FuchidoriPopToon v 1.0.7
// FPT_Lighting.cginc
#ifndef FPT_LIGHTING_INCLUDED
#define FPT_LIGHTING_INCLUDED

#include "FPT_Core.cginc"

fixed fpt_rimLighting(float2 INuv, float4 INscreenPos, float3 viewDir, float3 normalWS) {
    float2 viewportPos = INscreenPos.xy / INscreenPos.w;
    float2 screenPos = viewportPos * _ScreenParams.xy;
    fixed4 rimLightMask = tex2D(_RimLightMask, INuv);
    return lerp(0., pow(1. - saturate(dot(viewDir, normalWS)), 2.), _RimLightStrength) * rimLightMask.x;
}
fixed fpt_specular(float3 L, float3 viewDir, float3 N){
    float3 H = normalize(L-viewDir);
    return _SpecularStrength*max(0.,smoothstep( _SpecularBias - .02, _SpecularBias + .02, dot(N, H)));
}
fixed3 lv_SampleVolumes(fixed3 albedo, g2f i, float3 viewDir) {
    // VRC Light Volumes
    float3 lv_L0, lv_L1r, lv_L1g, lv_L1b;
    LightVolumeSH(i.positionWS, lv_L0, lv_L1r, lv_L1g, lv_L1b);

    // Diffuse Contribution from Light Volumes
    fixed3 LVEvaluate = LightVolumeEvaluate(i.normalWS, lv_L0, lv_L1r, lv_L1g, lv_L1b);

    // Specular Contribution from Light Volumes
    fixed3 LVSpecular = LightVolumeSpecular(albedo, _Smoothness, 0.0, i.normalWS, viewDir, lv_L0, lv_L1r, lv_L1g, lv_L1b);

    // Light Volume の拡散光はアルベドに乗算して加算
    return LVEvaluate * albedo + LVSpecular;
}

g2f vert_main_pass(appdata v)
{
    g2f o;
    o = vert_base(v);

    // [OpenLit] Calculate and copy light datas
    OpenLitLightDatas lightDatas;
    ComputeLights(lightDatas, _LightDirectionOverride);
    CorrectLights(lightDatas, _LightMinLimit, _LightMaxLimit, _MonochromeLighting, _AsUnlit);
    PackLightDatas(o.lightDatas, lightDatas);

    return o;
}

fixed3 CalculateShadow(g2f i, float3 N, float3 L, float NdotL){
    fixed4 shadowTexColor = tex2D(_ShadowTex, i.uv);
    fixed4 shadowColor1st = shadowTexColor * _ShadowOverlayColor1st;
    fixed4 shadowColor2nd = shadowTexColor * _ShadowOverlayColor2nd;

    float  shadowBlend = smoothstep(NdotL-_ShadowEdgeSmoothness, NdotL+_ShadowEdgeSmoothness, NdotL*NdotL-_ShadowWidth);
    fixed3 shadowColor = lerp(shadowColor1st.rgb, shadowColor2nd.rgb, shadowBlend);

    fixed3 factor = 0.;
    float factorBlend = 0.;

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

        half faceShadowMap = RdotL < 0.? R_sdfMask.r : L_sdfMask.r;

        float normalizedFdotL = .5*FdotL+.5;
        factor = 1.-smoothstep(faceShadowMap-_ShadowEdgeSmoothness, faceShadowMap+_ShadowEdgeSmoothness, normalizedFdotL);
    }
    else{
        factor = NdotL;
    }
    factorBlend = smoothstep(_ShadowThreshold-_ShadowEdgeSmoothness, _ShadowThreshold+_ShadowEdgeSmoothness, factor);
    factor = lerp(shadowColor, 1., factorBlend);
    factor = lerp(1., factor, _ShadowStrength);

    return factor;
}

void CalculateMaterialEffects(inout fixed4 col, g2f i, float3 viewDir) {
    // MatCap
    fixed4 matcap = tex2D(_MatCap, i.viewUV) * tex2D(_MatCapMask, i.uv);
    col.rgb = lerp(col.rgb, matcap.rgb, _MatCapStrength);

    // RimLighting
    fixed rim = fpt_rimLighting(i.uv, i.screenPos, viewDir, i.normalWS);
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