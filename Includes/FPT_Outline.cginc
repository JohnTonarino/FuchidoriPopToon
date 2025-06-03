// Copyright (c) 2024 JohnTonarino
// Released under the MIT license
// FuchidoriPopToon v 1.0.8
// FPT_Outline.cginc
#ifndef FPT_OUTLINE_INCLUDED
#define FPT_OUTLINE_INCLUDED

#include "FPT_Core.cginc"

float4 CalculateOutlineVertex(half3 normalOS, float2 uv, float4 vertex, fixed width){
    float3 normalWS = UnityObjectToWorldNormal(normalOS);
    float3 norm = mul((float3x3)UNITY_MATRIX_V, normalWS);
    
    float normLength = length(norm);
    norm = normLength > 0.0001 ? norm / normLength : float3(0, 0, 1);

    fixed4 outlineMask = tex2Dlod(_OutlineMask, float4(uv.xy, 0., 0.));
    float2 offset = TransformViewToProjection(norm.xy)*outlineMask.r;

    float4 outline_vertex = UnityObjectToClipPos(vertex);
    outline_vertex.xy += (offset * width);

    return outline_vertex;
}

g2f vert_outlinebase(appdata v, fixed width)
{
    g2f o;
    o = vert_base(v);
    o.pos = CalculateOutlineVertex(v.normalOS, v.uv, v.vertex, width);

    // [OpenLit] Calculate and copy light datas
    OpenLitLightDatas lightDatas;
    ComputeLights(lightDatas, _LightDirectionOverride);
    CorrectLights(lightDatas, _LightMinLimit, _LightMaxLimit, _MonochromeLighting, _AsOutlineUnlit);
    PackLightDatas(o.lightDatas, lightDatas);

    return o;
}

fixed4 frag_outline(g2f i) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
    UNITY_LIGHT_ATTENUATION(attenuation, i, i.positionWS);

    // Lighting
    // [OpenLit] Copy light datas from the input
    OpenLitLightDatas lightDatas;
    UnpackLightDatas(lightDatas, i.lightDatas);

    float factor = 1.;
    if (_ReceiveShadow) factor *= attenuation;

    fixed4 col = i.color;
    col.rgb *= lerp(lightDatas.indirectLight, lightDatas.directLight, factor);
    fixed3 albedo = col.rgb;
#if !defined(LIGHTMAP_ON) && UNITY_SHOULD_SAMPLE_SH
    col.rgb += albedo * i.vertexLight;
    col.rgb = min(col.rgb, albedo.rgb * _LightMaxLimit);
#endif
    UNITY_APPLY_FOG(i.fogCoord, col);

    return col;
}

[maxvertexcount(6)]
void geom_outline(triangle appdata IN[3], inout TriangleStream<g2f> stream) {
    g2f o;
    UNITY_INITIALIZE_OUTPUT(g2f, o);
    UNITY_SETUP_INSTANCE_ID(IN[0]);
    UNITY_SETUP_INSTANCE_ID(IN[1]);
    UNITY_SETUP_INSTANCE_ID(IN[2]);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

    // 1st Outline
    for (int i = 0; i < 3; ++i) {
        appdata v = IN[i];
        o = vert_outlinebase(v, _OuterOutlineRatio * _OuterOutlineWidth);
        o.color = _OuterOutlineColor1st;
        UNITY_TRANSFER_FOG(o, o.pos);

        stream.Append(o);
    }
    stream.RestartStrip();

    // 2nd Outline
    for (int j = 0; j < 3; ++j) {
        appdata v = IN[j];
        o = vert_outlinebase(v, _OuterOutlineWidth);
        o.color = _OuterOutlineColor2nd;
        UNITY_TRANSFER_FOG(o, o.pos);

        stream.Append(o);
    }
    stream.RestartStrip();
}
#endif // FPT_OUTLINE_INCLUDED