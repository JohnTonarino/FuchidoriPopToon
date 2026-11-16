// Copyright (c) 2026 JohnTonarino
// Released under the MIT license
// JTN_Lighting v 1.1.0
#ifndef JTN_PROPERTIES_INCLUDED
#define JTN_PROPERTIES_INCLUDED

// Toon Shadow
sampler2D _ShadowTex;
fixed4    _ShadowColor1;
fixed4    _ShadowColor2;
half      _ShadowStep1;
half      _ShadowStep2;
half      _ShadowSmoothness;
half      _ShadowStrength;
sampler2D _SDFMaskTex;
uint      _UseSDF;

// Lighting Control (OpenLit)
half      _AsUnlit;
half      _LightMinLimit;
half      _LightMaxLimit;
half      _MonochromeLighting;

// VRCLightVolumes
half      _VRCLightVolumesStrength;

#endif // JTN_PROPERTIES_INCLUDED
