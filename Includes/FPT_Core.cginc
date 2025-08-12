// Copyright (c) 2024 JohnTonarino
// Released under the MIT license
// FuchidoriPopToon v 1.0.9
// FPT_Core.cginc
#ifndef FPT_CORE_INCLUDED
#define FPT_CORE_INCLUDED

#include "UnityCG.cginc"
#include "VRCLightVolumes/LightVolumes.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
#include "OpenLit/OpenLit.cginc"

#define PI 3.141592

sampler2D _MainTex;
float4 _MainTex_ST;
int _StencilRef;
fixed4 _MainTexOverlayColor;

half _BumpScale;
sampler2D _BumpMap;
float4 _BumpMap_ST;

uint _MatCapType;
sampler2D _MatCap;
half _MatCapStrength;
sampler2D _MatCapMask;

half _SpecularStrength;
half _SpecularBias;
half _Smoothness;

sampler2D _ShadowTex;
fixed4 _ShadowOverlayColor1st;
fixed4 _ShadowOverlayColor2nd;
half _ShadowWidth;
half _ShadowEdgeSmoothness;
half _ShadowStrength;
uint _SDFOn;
sampler2D _SDFMaskTex;
float4 _SDFMaskTex_ST;

fixed4 _RimColor;
half _RimLightStrength;
sampler2D _RimLightMask;

fixed4 _OuterOutlineColor1st;
fixed4 _OuterOutlineColor2nd;
fixed4 _InnerOutlineColor;
fixed _OuterOutlineRatio;
fixed _OuterOutlineWidth;
fixed _InnerOutlineWidth;
half   _OutlineWidth;
sampler2D _OutlineMask;
uint _VertexColorNormal;
half   _AsOutlineUnlit;

sampler2D _TransparentMask;
half _TransparentLevel;

sampler2D _EmissiveTex;
float4 _EmissiveColor;

uint _VRCLightVolumesOn;
half _VRCLightVolumesStrength;

// [OpenLit] Properties for lighting
float _LightIntensity;
uint _ReceiveShadow;

float   _AsUnlit;
float   _LightMinLimit;
float   _LightMaxLimit;
float   _BeforeExposureLimit;
float   _MonochromeLighting;
float   _AlphaBoostFA;
float4  _LightDirectionOverride;

float _ShadowThreshold;
//---

struct appdata
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    float3 normalOS : NORMAL;
    float4 tangent : TANGENT;
    fixed4 color : COLOR;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct g2f
{
    float4 pos : SV_POSITION;
    float3 positionWS : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float3 normalWS : TEXCOORD2;

    // [OpenLit] Add light datas
    nointerpolation uint3 lightDatas : TEXCOORD3;
    UNITY_FOG_COORDS(4)
        UNITY_LIGHTING_COORDS(5, 6)
#if !defined(LIGHTMAP_ON) && UNITY_SHOULD_SAMPLE_SH
        float3 vertexLight  : TEXCOORD7;
#endif
    UNITY_VERTEX_OUTPUT_STEREO
    float4 screenPos : TEXCOORD8;
    half3 tangent : TEXCOORD9;
    half3 binormal : TEXCOORD10;
    half2 viewUV : TEXCOORD11;

    fixed4 color : TEXCOORD12;
};

struct v2f_shadow {
    V2F_SHADOW_CASTER;
    float2 uv : TEXCOORD1;
    float4 screenPos : TEXCOORD2;
};

g2f vert_base (appdata v)
{
    g2f o;
    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_INITIALIZE_OUTPUT(g2f, o);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

    o.pos = UnityObjectToClipPos(v.vertex);
    o.positionWS = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1.));
    o.uv = v.uv;
    o.normalWS = UnityObjectToWorldNormal(v.normalOS);

    o.screenPos = ComputeScreenPos(o.pos);
    o.tangent = normalize(mul(unity_ObjectToWorld, v.tangent)).xyz;
    o.binormal = normalize(mul(unity_ObjectToWorld, cross(v.normalOS, v.tangent) * v.tangent.w));

    float3 viewNormal = mul((float3x3)UNITY_MATRIX_V, UnityObjectToWorldNormal(v.normalOS));
    o.viewUV = viewNormal.xy * .5 + .5;

    UNITY_TRANSFER_FOG(o, o.pos);
    UNITY_TRANSFER_LIGHTING(o, v.uv);

    // [OpenLit] Calculate and copy vertex lighting
#if !defined(LIGHTMAP_ON) && UNITY_SHOULD_SAMPLE_SH && defined(VERTEXLIGHT_ON)
    o.vertexLight = 0.;
    o.vertexLight = min(o.vertexLight, _LightMaxLimit);
#endif

    return o;
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
#endif // FPT_CORE_INCLUDED
