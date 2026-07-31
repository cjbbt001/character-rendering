#ifndef CHARACTER_BODY_FORWARD_PASS_INCLUDED
#define CHARACTER_BODY_FORWARD_PASS_INCLUDED

struct CharacterBodyAttributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct CharacterBodyVaryings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    half3 normalWS : TEXCOORD2;
    half4 tangentWS : TEXCOORD3;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

half3 CharacterCustomSH(half3 normalWS)
{
    half4 normalForSH = half4(normalWS, 1.0h);
    half3 linearContribution;
    linearContribution.r = dot(custom_SHAr, normalForSH);
    linearContribution.g = dot(custom_SHAg, normalForSH);
    linearContribution.b = dot(custom_SHAb, normalForSH);

    half4 quadraticTerms = normalForSH.xyzz * normalForSH.yzzx;
    half3 quadratic;
    quadratic.r = dot(custom_SHBr, quadraticTerms);
    quadratic.g = dot(custom_SHBg, quadraticTerms);
    quadratic.b = dot(custom_SHBb, quadraticTerms);

    half finalTerm = normalForSH.x * normalForSH.x
        - normalForSH.y * normalForSH.y;
    return max(0.0h, linearContribution + quadratic + custom_SHC.rgb * finalTerm);
}

float3 CharacterACES(float3 color)
{
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return saturate((color * (a * color + b)) / (color * (c * color + d) + e));
}

half3 EvaluateBodyDirectLight(
    Light light,
    half3 normalWS,
    half3 viewDirectionWS,
    half3 baseColor,
    half3 specColor,
    half roughness,
    half skinArea)
{
    half attenuation = light.distanceAttenuation * light.shadowAttenuation;
    half NdotL = saturate(dot(normalWS, light.direction));
    half halfLambert = (NdotL + 1.0h) * 0.5h;

    half3 directDiffuse = 0.0h;
    #if defined(_DIFFUSECHECK_ON)
        half3 commonDiffuse = NdotL * baseColor * light.color * attenuation;
        half2 skinUV = half2(saturate(NdotL + _SSSOffset), 1.0h);
        half3 skinLUT = SAMPLE_TEXTURE2D(_SkinLUT, sampler_SkinLUT, skinUV).rgb;
        skinLUT = PositivePow(skinLUT, 2.2h);
        half3 skinDiffuse = skinLUT * baseColor * halfLambert
            * light.color * attenuation;
        directDiffuse = lerp(commonDiffuse, skinDiffuse, skinArea);
    #endif

    half3 directSpecular = 0.0h;
    #if defined(_SPECCHECK_ON)
        half3 halfDirection = SafeNormalize(light.direction + viewDirectionWS);
        half NdotH = saturate(dot(normalWS, halfDirection));
        half smoothness = 1.0h - roughness;
        half shininess = lerp(1.0h, _SpecShininess, smoothness);
        half specularTerm = PositivePow(NdotH, max(0.0001h, shininess * smoothness));
        half3 skinSpecColor = lerp(specColor, CHARACTER_SKIN_SPECULAR_F0.xxx, skinArea);
        directSpecular = specularTerm * skinSpecColor * light.color * attenuation;
    #endif

    return directDiffuse + directSpecular;
}

CharacterBodyVaryings CharacterBodyVertex(CharacterBodyAttributes input)
{
    CharacterBodyVaryings output = (CharacterBodyVaryings)0;
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
    return output;
}

half4 CharacterBodyFragment(CharacterBodyVaryings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
    half4 compMask = SAMPLE_TEXTURE2D(_CompMask, sampler_CompMask, input.uv);

    #if defined(_SWIMSUIT_MASK_LAYOUT)
        half clothArea = saturate(compMask.g);
        half skinArea = saturate(compMask.r - clothArea);
        half roughness = saturate(_RoughnessAdjust);
        half3 baseColor = albedo.rgb;
        half3 specColor = albedo.rgb * clothArea;
        half iblArea = clothArea;
        half3 emission = albedo.rgb * _EmissionColor.rgb
            * compMask.b * _EmissionIntensity;
    #else
        half roughness = saturate(compMask.r + _RoughnessAdjust);
        half metal = saturate(compMask.g + _MetalAdjust);
        half skinArea = 1.0h - compMask.b;
        half3 baseColor = albedo.rgb * (1.0h - metal);
        half3 specColor = albedo.rgb * metal;
        half iblArea = 1.0h - skinArea;
        half3 emission = 0.0h;
    #endif

    half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv));
    half3 normalWS = NormalizeNormalPerPixel(input.normalWS);
    half3 tangentWS = normalize(input.tangentWS.xyz);
    half3 bitangentWS = input.tangentWS.w * cross(normalWS, tangentWS);
    normalWS = NormalizeNormalPerPixel(TransformTangentToWorld(
        normalTS, half3x3(tangentWS, bitangentWS, normalWS)));
    half3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

    float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    Light mainLight = GetMainLight(shadowCoord);

    half3 directLighting = EvaluateBodyDirectLight(
        mainLight, normalWS, viewDirectionWS, baseColor, specColor, roughness, skinArea);

    #if defined(_ADDITIONAL_LIGHTS)
        InputData inputData = (InputData)0;
        inputData.positionWS = input.positionWS;
        inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
        uint additionalLightCount = GetAdditionalLightsCount();
        LIGHT_LOOP_BEGIN(additionalLightCount)
            Light additionalLight = GetAdditionalLight(lightIndex, input.positionWS);
            directLighting += EvaluateBodyDirectLight(
                additionalLight, normalWS, viewDirectionWS,
                baseColor, specColor, roughness, skinArea);
        LIGHT_LOOP_END
    #endif

    half halfLambert = (saturate(dot(normalWS, mainLight.direction)) + 1.0h) * 0.5h;
    half3 indirectDiffuse = 0.0h;
    #if defined(_SHCHECK_ON)
        indirectDiffuse = CharacterCustomSH(normalWS) * baseColor * halfLambert;
    #endif

    half3 indirectSpecular = 0.0h;
    #if defined(_IBLCHECK_ON)
        half3 reflectionDirection = reflect(-viewDirectionWS, normalWS);
        half perceptualRoughness = roughness * (1.7h - 0.7h * roughness);
        half4 encodedEnvironment = SAMPLE_TEXTURECUBE_LOD(
            _EnvMap, sampler_EnvMap, reflectionDirection, perceptualRoughness * 6.0h);
        half3 environment = DecodeHDREnvironment(encodedEnvironment, _EnvMap_HDR);
        indirectSpecular = environment * _Expose * specColor
            * halfLambert * iblArea;
    #endif

    half3 finalColor = directLighting + indirectDiffuse
        + indirectSpecular + emission;
    return half4(CharacterACES(finalColor), 1.0h);
}

#endif
