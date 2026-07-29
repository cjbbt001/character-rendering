#ifndef CHARACTER_HAIR_FORWARD_PASS_INCLUDED
#define CHARACTER_HAIR_FORWARD_PASS_INCLUDED

struct CharacterHairAttributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct CharacterHairVaryings
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

float3 HairACES(float3 color)
{
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return saturate((color * (a * color + b)) / (color * (c * color + d) + e));
}

half3 EvaluateHairSpecular(
    Light light,
    half3 normalWS,
    half3 tangentWS,
    half3 bitangentWS,
    half3 viewDirectionWS,
    half3 baseColor,
    half anisotropyNoise)
{
    half attenuation = light.distanceAttenuation * light.shadowAttenuation;
    half3 halfDirection = SafeNormalize(light.direction + viewDirectionWS);
    half NdotL = saturate(dot(normalWS, light.direction));
    half halfLambert = (NdotL + 1.0h) * 0.5h;
    half NdotV = max(0.0001h, dot(viewDirectionWS, normalWS));
    half anisotropyAttenuation = saturate(sqrt(halfLambert / NdotV)) * attenuation;
    half NdotH = dot(normalWS, halfDirection);
    half TdotH = dot(halfDirection, tangentWS);

    half3 offsetBitangent1 = normalize(bitangentWS + normalWS
        * (anisotropyNoise * _SpecNoise1 + _SpecOffset1));
    half BdotH1 = dot(halfDirection, offsetBitangent1) / max(0.0001h, _SpecShininess1);
    half specularTerm1 = exp(-(TdotH * TdotH + BdotH1 * BdotH1)
        / max(0.0001h, 1.0h + NdotH));
    half3 specular1 = specularTerm1 * (_SpecColor1.rgb + baseColor);

    half3 offsetBitangent2 = normalize(bitangentWS + normalWS
        * (anisotropyNoise * _SpecNoise2 + _SpecOffset2));
    half BdotH2 = dot(halfDirection, offsetBitangent2) / max(0.0001h, _SpecShininess2);
    half specularTerm2 = exp(-(TdotH * TdotH + BdotH2 * BdotH2)
        / max(0.0001h, 1.0h + NdotH));
    half3 specular2 = specularTerm2 * (_SpecColor2.rgb + baseColor);

    return (specular1 + specular2) * anisotropyAttenuation * light.color;
}

CharacterHairVaryings CharacterHairVertex(CharacterHairAttributes input)
{
    CharacterHairVaryings output = (CharacterHairVaryings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    output.positionCS = positionInputs.positionCS;
    output.positionWS = positionInputs.positionWS;
    output.normalWS = normalInputs.normalWS;
    output.tangentWS = half4(normalInputs.tangentWS, input.tangentOS.w * GetOddNegativeScale());
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.shadowCoord = GetShadowCoord(positionInputs);
    return output;
}

half4 CharacterHairFragment(CharacterHairVaryings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    half3 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).rgb;
    half roughness = saturate(_RoughnessAdjust);
    half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv));
    half3 normalWS = NormalizeNormalPerPixel(input.normalWS);
    half3 tangentWS = normalize(input.tangentWS.xyz);
    half3 bitangentWS = input.tangentWS.w * cross(normalWS, tangentWS);
    normalWS = NormalizeNormalPerPixel(TransformTangentToWorld(
        normalTS, half3x3(tangentWS, bitangentWS, normalWS)));
    half3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    half2 anisotropyUV = input.uv * _AnisoMap_ST.xy + _AnisoMap_ST.zw;
    half anisotropyNoise = SAMPLE_TEXTURE2D(_AnisoMap, sampler_AnisoMap, anisotropyUV).r - 0.5h;

    half3 directDiffuse = 0.0h;
    #if defined(_DIFFUSECHECK_ON)
        directDiffuse = baseColor * 2.0h;
    #endif

    half3 directSpecular = 0.0h;
    #if defined(_SPECCHECK_ON)
        Light mainLight = GetMainLight(input.shadowCoord);
        directSpecular = EvaluateHairSpecular(
            mainLight, normalWS, tangentWS, bitangentWS,
            viewDirectionWS, baseColor, anisotropyNoise);

        #if defined(_ADDITIONAL_LIGHTS)
            InputData inputData = (InputData)0;
            inputData.positionWS = input.positionWS;
            inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
            uint additionalLightCount = GetAdditionalLightsCount();
            LIGHT_LOOP_BEGIN(additionalLightCount)
                Light additionalLight = GetAdditionalLight(lightIndex, input.positionWS);
                directSpecular += EvaluateHairSpecular(
                    additionalLight, normalWS, tangentWS, bitangentWS,
                    viewDirectionWS, baseColor, anisotropyNoise);
            LIGHT_LOOP_END
        #endif
    #endif

    half3 indirectSpecular = 0.0h;
    #if defined(_IBLCHECK_ON)
        half3 reflectionDirection = reflect(-viewDirectionWS, normalWS);
        half perceptualRoughness = roughness * (1.7h - 0.7h * roughness);
        half4 encodedEnvironment = SAMPLE_TEXTURECUBE_LOD(
            _EnvMap, sampler_EnvMap, reflectionDirection, perceptualRoughness * 6.0h);
        half3 environment = DecodeHDREnvironment(encodedEnvironment, _EnvMap_HDR);
        half NdotL = saturate(dot(normalWS, GetMainLight().direction));
        half halfLambert = (NdotL + 1.0h) * 0.5h;
        indirectSpecular = environment * _Expose * halfLambert * anisotropyNoise;
    #endif

    return half4(HairACES(directDiffuse + directSpecular + indirectSpecular), 1.0h);
}

#endif
