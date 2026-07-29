Shader "Char_Hair"
{
    Properties
    {
        [Header(BaseInfo)]
        _BaseMap("BaseMap", 2D) = "white" {}
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [Normal] _NormalMap("NormalMap", 2D) = "bump" {}
        _RoughnessAdjust("Roughness Adjust", Range(-1, 1)) = 0.0

        [Header(Specular)]
        _AnisoMap("Aniso Map", 2D) = "gray" {}
        _SpecColor1("Specular Color 1", Color) = (1, 1, 1, 1)
        _SpecShininess1("Spec Shininess 1", Range(0, 1)) = 0.1
        _SpecNoise1("Spec Noise 1", Float) = 1
        _SpecOffset1("Spec Offset 1", Float) = 0

        _SpecColor2("Specular Color 2", Color) = (1, 1, 1, 1)
        _SpecShininess2("Spec Shininess 2", Range(0, 1)) = 0.1
        _SpecNoise2("Spec Noise 2", Float) = 1
        _SpecOffset2("Spec Offset 2", Float) = 0

        [Header(IBL)]
        _EnvMap("Env Map", Cube) = "white" {}
        _Expose("Expose", Float) = 1.0

        [Toggle(_DIFFUSECHECK_ON)] _DiffuseCheck("Diffuse Check", Float) = 1.0
        [Toggle(_SPECCHECK_ON)] _SpecCheck("Spec Check", Float) = 1.0
        [Toggle(_IBLCHECK_ON)] _IBLCheck("IBL Check", Float) = 1.0
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }
        LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        TEXTURE2D(_BaseMap);        SAMPLER(sampler_BaseMap);
        TEXTURE2D(_NormalMap);      SAMPLER(sampler_NormalMap);
        TEXTURE2D(_AnisoMap);       SAMPLER(sampler_AnisoMap);
        TEXTURECUBE(_EnvMap);       SAMPLER(sampler_EnvMap);

        CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float4 _AnisoMap_ST;
            float4 _EnvMap_HDR;
            half4 _BaseColor;
            half4 _SpecColor1;
            half4 _SpecColor2;
            half _RoughnessAdjust;
            half _SpecShininess1;
            half _SpecNoise1;
            half _SpecOffset1;
            half _SpecShininess2;
            half _SpecNoise2;
            half _SpecOffset2;
            half _Expose;
        CBUFFER_END
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForwardOnly" }

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex CharacterHairVertex
            #pragma fragment CharacterHairFragment

            #pragma shader_feature_local_fragment _DIFFUSECHECK_ON
            #pragma shader_feature_local_fragment _SPECCHECK_ON
            #pragma shader_feature_local_fragment _IBLCHECK_ON

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile_instancing

            #include "CharacterHairForwardPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex CharacterShadowVertex
            #pragma fragment CharacterShadowFragment
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #pragma multi_compile_instancing
            #include "CharacterShadowCasterPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            ZWrite On
            ColorMask R

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex CharacterDepthVertex
            #pragma fragment CharacterDepthFragment
            #pragma multi_compile_instancing
            #include "CharacterDepthOnlyPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode" = "DepthNormalsOnly" }
            ZWrite On

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex CharacterDepthNormalsVertex
            #pragma fragment CharacterDepthNormalsFragment
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile_instancing
            #include "CharacterDepthNormalsPass.hlsl"
            ENDHLSL
        }
    }

    FallBack Off
}
