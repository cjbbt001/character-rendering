Shader "Learning/Character Body URP Single File"
{
    Properties
    {
        [Header(Base Info)]
        _BaseMap("Base Map", 2D) = "white" {}
        _CompMask("Comp Mask (Roughness, Metal, Skin)", 2D) = "white" {}
        [Normal] _NormalMap("Normal Map", 2D) = "bump" {}
        _RoughnessAdjust("Roughness Adjust", Range(-1, 1)) = 0.0
        _MetalAdjust("Metal Adjust", Range(-1, 1)) = 0.0
        _SpecShininess("Specular Shininess", Float) = 10

        [Header(Skin)]
        _SkinLUT("Skin LUT", 2D) = "white" {}
        _SSSOffset("SSS Offset", Range(-1, 1)) = 0

        [Header(IBL)]
        _EnvMap("Environment Map", Cube) = "white" {}
        _Expose("Environment Exposure", Float) = 1.0

        [Toggle(_DIFFUSECHECK_ON)] _DiffuseCheck("Diffuse", Float) = 1.0
        [Toggle(_SPECCHECK_ON)] _SpecCheck("Specular", Float) = 1.0
        [Toggle(_SHCHECK_ON)] _SHCheck("Custom SH", Float) = 1.0
        [Toggle(_IBLCHECK_ON)] _IBLCheck("IBL", Float) = 1.0

        [HideInInspector] custom_SHAr("Custom SHAr", Vector) = (0, 0, 0, 0)
        [HideInInspector] custom_SHAg("Custom SHAg", Vector) = (0, 0, 0, 0)
        [HideInInspector] custom_SHAb("Custom SHAb", Vector) = (0, 0, 0, 0)
        [HideInInspector] custom_SHBr("Custom SHBr", Vector) = (0, 0, 0, 0)
        [HideInInspector] custom_SHBg("Custom SHBg", Vector) = (0, 0, 0, 0)
        [HideInInspector] custom_SHBb("Custom SHBb", Vector) = (0, 0, 0, 0)
        [HideInInspector] custom_SHC("Custom SHC", Vector) = (0, 0, 0, 1)
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        // HLSLINCLUDE is shared by every Pass in this SubShader.
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        TEXTURE2D(_BaseMap);
        SAMPLER(sampler_BaseMap);
        TEXTURE2D(_CompMask);
        SAMPLER(sampler_CompMask);
        TEXTURE2D(_NormalMap);
        SAMPLER(sampler_NormalMap);
        TEXTURE2D(_SkinLUT);
        SAMPLER(sampler_SkinLUT);
        TEXTURECUBE(_EnvMap);
        SAMPLER(sampler_EnvMap);

        // All per-material values stay in one buffer for SRP Batcher compatibility.
        CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float4 _EnvMap_HDR;
            half _RoughnessAdjust;
            half _MetalAdjust;
            half _SpecShininess;
            half _SSSOffset;
            half _Expose;
            half4 custom_SHAr;
            half4 custom_SHAg;
            half4 custom_SHAb;
            half4 custom_SHBr;
            half4 custom_SHBg;
            half4 custom_SHBb;
            half4 custom_SHC;
        CBUFFER_END
        ENDHLSL

        // -----------------------------------------------------------------
        // 1. Forward lighting Pass
        // URP accumulates the main light and additional lights in this Pass.
        // -----------------------------------------------------------------
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForwardOnly" }

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex ForwardVertex
            #pragma fragment ForwardFragment

            #pragma shader_feature_local_fragment _DIFFUSECHECK_ON
            #pragma shader_feature_local_fragment _SPECCHECK_ON
            #pragma shader_feature_local_fragment _SHCHECK_ON
            #pragma shader_feature_local_fragment _IBLCHECK_ON

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile_instancing

            struct ForwardAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct ForwardVaryings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                half3 normalWS : TEXCOORD2;
                half4 tangentWS : TEXCOORD3;
                float4 shadowCoord : TEXCOORD4;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            half3 EvaluateCustomSH(half3 normalWS)
            {
                half4 normalForSH = half4(normalWS, 1.0h);

                half3 linearContribution;
                linearContribution.r = dot(custom_SHAr, normalForSH);
                linearContribution.g = dot(custom_SHAg, normalForSH);
                linearContribution.b = dot(custom_SHAb, normalForSH);

                half4 quadraticTerms = normalForSH.xyzz * normalForSH.yzzx;
                half3 quadraticContribution;
                quadraticContribution.r = dot(custom_SHBr, quadraticTerms);
                quadraticContribution.g = dot(custom_SHBg, quadraticTerms);
                quadraticContribution.b = dot(custom_SHBb, quadraticTerms);

                half finalTerm = normalForSH.x * normalForSH.x
                    - normalForSH.y * normalForSH.y;

                return max(
                    0.0h,
                    linearContribution
                    + quadraticContribution
                    + custom_SHC.rgb * finalTerm);
            }

            float3 ACESFilm(float3 color)
            {
                const float a = 2.51;
                const float b = 0.03;
                const float c = 2.43;
                const float d = 0.59;
                const float e = 0.14;
                return saturate(
                    (color * (a * color + b))
                    / (color * (c * color + d) + e));
            }

            // One function handles both the main light and each additional light.
            half3 EvaluateDirectLight(
                Light light,
                half3 normalWS,
                half3 viewDirectionWS,
                half3 baseColor,
                half3 specularColor,
                half roughness,
                half skinArea)
            {
                half attenuation = light.distanceAttenuation
                    * light.shadowAttenuation;
                half NdotL = saturate(dot(normalWS, light.direction));
                half halfLambert = (NdotL + 1.0h) * 0.5h;

                half3 directDiffuse = 0.0h;
                #if defined(_DIFFUSECHECK_ON)
                    half3 commonDiffuse = NdotL * baseColor
                        * light.color * attenuation;

                    half2 skinUV = half2(
                        saturate(NdotL * attenuation + _SSSOffset),
                        1.0h);
                    half3 skinLUT = SAMPLE_TEXTURE2D(
                        _SkinLUT, sampler_SkinLUT, skinUV).rgb;
                    skinLUT = PositivePow(skinLUT, 2.2h);

                    half3 skinDiffuse = skinLUT * baseColor
                        * halfLambert * light.color * attenuation;
                    directDiffuse = lerp(
                        commonDiffuse, skinDiffuse, skinArea);
                #endif

                half3 directSpecular = 0.0h;
                #if defined(_SPECCHECK_ON)
                    half3 halfDirection = SafeNormalize(
                        light.direction + viewDirectionWS);
                    half NdotH = saturate(dot(normalWS, halfDirection));
                    half smoothness = 1.0h - roughness;
                    half shininess = lerp(
                        1.0h, _SpecShininess, smoothness);
                    half specularTerm = PositivePow(
                        NdotH,
                        max(0.0001h, shininess * smoothness));
                    half3 finalSpecularColor = lerp(
                        specularColor, 0.02h.xxx, skinArea);
                    directSpecular = specularTerm
                        * finalSpecularColor
                        * light.color
                        * attenuation;
                #endif

                return directDiffuse + directSpecular;
            }

            ForwardVaryings ForwardVertex(ForwardAttributes input)
            {
                ForwardVaryings output = (ForwardVaryings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs positionInputs =
                    GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInputs =
                    GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.positionCS = positionInputs.positionCS;
                output.positionWS = positionInputs.positionWS;
                output.normalWS = normalInputs.normalWS;
                output.tangentWS = half4(
                    normalInputs.tangentWS,
                    input.tangentOS.w * GetOddNegativeScale());
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.shadowCoord = GetShadowCoord(positionInputs);
                return output;
            }

            half4 ForwardFragment(ForwardVaryings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // Decode material textures.
                half4 albedo = SAMPLE_TEXTURE2D(
                    _BaseMap, sampler_BaseMap, input.uv);
                half4 compMask = SAMPLE_TEXTURE2D(
                    _CompMask, sampler_CompMask, input.uv);
                half roughness = saturate(
                    compMask.r + _RoughnessAdjust);
                half metal = saturate(compMask.g + _MetalAdjust);
                half skinArea = 1.0h - compMask.b;
                half3 baseColor = albedo.rgb * (1.0h - metal);
                half3 specularColor = albedo.rgb * metal;

                // Build TBN and transform the tangent-space normal to world space.
                half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(
                    _NormalMap, sampler_NormalMap, input.uv));
                half3 normalWS = NormalizeNormalPerPixel(input.normalWS);
                half3 tangentWS = normalize(input.tangentWS.xyz);
                half3 bitangentWS = input.tangentWS.w
                    * cross(normalWS, tangentWS);
                normalWS = NormalizeNormalPerPixel(TransformTangentToWorld(
                    normalTS,
                    half3x3(tangentWS, bitangentWS, normalWS)));

                half3 viewDirectionWS =
                    GetWorldSpaceNormalizeViewDir(input.positionWS);

                // Main light includes its realtime shadow attenuation.
                Light mainLight = GetMainLight(input.shadowCoord);
                half3 directLighting = EvaluateDirectLight(
                    mainLight,
                    normalWS,
                    viewDirectionWS,
                    baseColor,
                    specularColor,
                    roughness,
                    skinArea);

                // Built-in ForwardAdd becomes a light loop inside the URP Pass.
                #if defined(_ADDITIONAL_LIGHTS)
                    InputData inputData = (InputData)0;
                    inputData.positionWS = input.positionWS;
                    inputData.normalizedScreenSpaceUV =
                        GetNormalizedScreenSpaceUV(input.positionCS);

                    uint additionalLightCount = GetAdditionalLightsCount();
                    LIGHT_LOOP_BEGIN(additionalLightCount)
                        Light additionalLight = GetAdditionalLight(
                            lightIndex, input.positionWS);
                        directLighting += EvaluateDirectLight(
                            additionalLight,
                            normalWS,
                            viewDirectionWS,
                            baseColor,
                            specularColor,
                            roughness,
                            skinArea);
                    LIGHT_LOOP_END
                #endif

                half halfLambert = (
                    saturate(dot(normalWS, mainLight.direction)) + 1.0h)
                    * 0.5h;

                half3 indirectDiffuse = 0.0h;
                #if defined(_SHCHECK_ON)
                    indirectDiffuse = EvaluateCustomSH(normalWS)
                        * baseColor * halfLambert;
                #endif

                half3 indirectSpecular = 0.0h;
                #if defined(_IBLCHECK_ON)
                    half3 reflectionDirection = reflect(
                        -viewDirectionWS, normalWS);
                    half perceptualRoughness = roughness
                        * (1.7h - 0.7h * roughness);
                    half4 encodedEnvironment = SAMPLE_TEXTURECUBE_LOD(
                        _EnvMap,
                        sampler_EnvMap,
                        reflectionDirection,
                        perceptualRoughness * 6.0h);
                    half3 environment = DecodeHDREnvironment(
                        encodedEnvironment, _EnvMap_HDR);
                    indirectSpecular = environment
                        * _Expose
                        * specularColor
                        * halfLambert
                        * (1.0h - skinArea);
                #endif

                half3 finalColor = directLighting
                    + indirectDiffuse
                    + indirectSpecular;
                return half4(ACESFilm(finalColor), 1.0h);
            }
            ENDHLSL
        }

        // -----------------------------------------------------------------
        // 2. ShadowCaster Pass
        // Writes the character into URP realtime shadow maps.
        // -----------------------------------------------------------------
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex ShadowVertex
            #pragma fragment ShadowFragment
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            float3 _LightDirection;
            float3 _LightPosition;

            struct ShadowAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct ShadowVaryings
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            ShadowVaryings ShadowVertex(ShadowAttributes input)
            {
                ShadowVaryings output = (ShadowVaryings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                float3 positionWS = TransformObjectToWorld(
                    input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(
                    input.normalOS);

                #if defined(_CASTING_PUNCTUAL_LIGHT_SHADOW)
                    float3 lightDirectionWS = normalize(
                        _LightPosition - positionWS);
                #else
                    float3 lightDirectionWS = _LightDirection;
                #endif

                output.positionCS = TransformWorldToHClip(
                    ApplyShadowBias(
                        positionWS,
                        normalWS,
                        lightDirectionWS));
                output.positionCS = ApplyShadowClamping(
                    output.positionCS);
                return output;
            }

            half4 ShadowFragment(ShadowVaryings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                return 0.0h;
            }
            ENDHLSL
        }

        // -----------------------------------------------------------------
        // 3. DepthOnly Pass
        // Writes depth when the URP camera requests a depth texture/prepass.
        // -----------------------------------------------------------------
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            ZWrite On
            ColorMask R

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex DepthVertex
            #pragma fragment DepthFragment
            #pragma multi_compile_instancing

            struct DepthAttributes
            {
                float4 positionOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct DepthVaryings
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            DepthVaryings DepthVertex(DepthAttributes input)
            {
                DepthVaryings output = (DepthVaryings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                output.positionCS = TransformObjectToHClip(
                    input.positionOS.xyz);
                return output;
            }

            half4 DepthFragment(DepthVaryings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                return 0.0h;
            }
            ENDHLSL
        }

        // -----------------------------------------------------------------
        // 4. DepthNormals Pass
        // Writes depth plus the normal-mapped world-space normal for SSAO.
        // -----------------------------------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode" = "DepthNormalsOnly" }
            ZWrite On

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"

            struct DepthNormalsAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct DepthNormalsVaryings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                half3 normalWS : TEXCOORD1;
                half4 tangentWS : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            DepthNormalsVaryings DepthNormalsVertex(
                DepthNormalsAttributes input)
            {
                DepthNormalsVaryings output =
                    (DepthNormalsVaryings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexNormalInputs normalInputs =
                    GetVertexNormalInputs(
                        input.normalOS,
                        input.tangentOS);
                output.positionCS = TransformObjectToHClip(
                    input.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.normalWS = normalInputs.normalWS;
                output.tangentWS = half4(
                    normalInputs.tangentWS,
                    input.tangentOS.w * GetOddNegativeScale());
                return output;
            }

            half4 DepthNormalsFragment(
                DepthNormalsVaryings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);

                half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(
                    _NormalMap, sampler_NormalMap, input.uv));
                half3 normalWS = NormalizeNormalPerPixel(
                    input.normalWS);
                half3 tangentWS = normalize(input.tangentWS.xyz);
                half3 bitangentWS = input.tangentWS.w
                    * cross(normalWS, tangentWS);
                normalWS = NormalizeNormalPerPixel(
                    TransformTangentToWorld(
                        normalTS,
                        half3x3(
                            tangentWS,
                            bitangentWS,
                            normalWS)));

                #if defined(_GBUFFER_NORMALS_OCT)
                    float2 octNormalWS =
                        PackNormalOctQuadEncode(normalWS);
                    float2 remappedOctNormalWS = saturate(
                        octNormalWS * 0.5 + 0.5);
                    return half4(
                        PackFloat2To888(remappedOctNormalWS),
                        0.0h);
                #else
                    return half4(normalWS, 0.0h);
                #endif
            }
            ENDHLSL
        }
    }

    FallBack Off
}
