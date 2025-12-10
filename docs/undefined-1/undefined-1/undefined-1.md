# 셰이더 모듈

vulkan 셰이더 코드는 glsl로 저장됨.  spir-v로 컴파일 되어 바이트 코드로 변환됨. 이전에는 glsl을 gpu 드라이버마다 다르게 해석하여 컴파일 오류가 나는 문제들이 있었으나 spir-v는 정해진 규격이므로 이런 문제를 줄여준다.

hlsl에서도 spir-v로 컴파일이 가능하다.

*   vertex shader&#x20;

    ```
    dxc -T vs_6_0 -E VSMain shader.hlsl -spirv -fspv-target-env=vulkan1.3 -Fo shader.vert.spv
    ```
*   pixel shader

    ```
    dxc -T ps_6_0 -E PSMain shader.hlsl -spirv -fspv-target-env=vulkan1.3 -Fo shader.frag.spv
    ```

hlsl을 spirv로 변환하기 위해서 다음과 같은 주의점이 필요하다.

*   DX용 register 대신, Vulkan 메타데이터 사용

    ```hlsl
    [[vk::binding(0, 1)]]
    Texture2D tex;
    ```
* Row-major / column-major 주의 필요
  * HLSL은 기본 row-major, GLSL은 기본 column-major
  * → `[[vk::layout(...)]]` 또는 매트릭스 transpose 조심하면 됨
* `SV_` semantics는 Vulkan식으로 모두 지원됨
  * `SV_VertexID`, `SV_InstanceID`, `SV_Position`, `SV_Target0` 등 정상적으로 변
* SPIR-V에 없는 DX 전용 intrinsic은 당연히 불가
  * 예: old SM 5.x Tessellator 관련 일부 Intrinsic\
    (Vulkan 지원 버전만 써야 함)

vertexShader의 코드와 fragment shader의 코드는 다음과 같다

```glsl
#version 450

vec2 positions[3] = vec2[]
(
	vec2(0.0, -0.5),
	vec2(0.5, 0.5),
	vec2(0.0, -0.5)
);

vec3 colors[3] = vec3[](
    vec3(1.0, 0.0, 0.0),
    vec3(0.0, 1.0, 0.0),
    vec3(0.0, 0.0, 1.0)
);

layout(location = 0) out vec3 fragColor;

void main()
{
	gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
	fragColor = colors[gl_VertexIndex];
}

```

```glsl
#version 450

layout(location = 0) in vec3 fragColor;
layout(location = 0) out vec4 outColor;

void main() {
    outColor = vec4(fragColor, 1.0);
}
```

hlsl은 구조체로 vs\_input, ps\_input과 같은 식으로 vertexShader에서 pixelshader로 선형보간되는   버텍스데이터를 전달했다. vulkan, glsl은 다르다.

vertex shader의 경우엔 위의 코드처럼 layout(location = 0)이라는 형태로 전달한다. location 번호만 맞으면 pixelshader에서 이름이 일치할 필요가 없다.

pixel shader같은 경우에는 location 0 값이 렌더타겟의 출력 index를 의미한다. mrt 일경우에 0은 0번 렌더타겟, 1은 1번 렌더타겟이다.

hlsl 같은경우에는 texture나 상수버퍼, sampler등 shader에 전달하는 리소스들은 각각 별도의 레지스터에 할당했으나, vulkan에서는 attribute set을 사용한다.

```glsl
layout(set = 0, binding = 0) uniform sampler2D tex;
layout(set = 0, binding = 1) uniform sampler samp;
layout(set = 1, binding = 0) uniform MyUBO { ... };
```

같은 set에 바인딩 된 리소스들은 함께 업데이트 된다. set0과 set1은 업데이트를 별도로 하고, hlsl과는 달리 레지스터 구분없이 texture, sampler, uniformbuffer등 다양한 리소스들을 set에 포함 시킬 수 있다.

```hlsl
[[vk::binding(0, 0)]]
Texture2D gTexture;

[[vk::binding(0, 1)]] //0은 set 번호, 1은 binding slot!
SamplerState gSampler;
```

셰이더 작성뒤에는 다음과 같이 작성된 배치파일을 돌린다.

```
C:/VulkanSDK/1.4.328.1/Bin/glslc.exe shader.vert -o vert.spv
C:/VulkanSDK/1.4.328.1/Bin/glslc.exe shader.frag -o frag.spv
pause
```

이제 spir-v로 컴파일된 셰이더 모듈을 생성한다.<br>

```cpp
	void initVulkan()
	{
		//.......
		createGraphicsPipeline();
	}
	
	void createGraphicsPipeline()
	{
		auto vertShaderCode = readFile("shaders/vert.spv");
		auto fragShaderCode = readFile("shaders/frag.spv");

		VkShaderModule vertShaderModule = createShaderModule(vertShaderCode);
		VkShaderModule fragShaderModule = createShaderModule(fragShaderCode);

		VkPipelineShaderStageCreateInfo vertShaderStageInfo{};
		vertShaderStageInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
		vertShaderStageInfo.stage = VK_SHADER_STAGE_VERTEX_BIT;
		vertShaderStageInfo.module = vertShaderModule;
		vertShaderStageInfo.pName = "main";

		VkPipelineShaderStageCreateInfo fragShaderStageInfo{};
		fragShaderStageInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
		fragShaderStageInfo.stage = VK_SHADER_STAGE_FRAGMENT_BIT;
		fragShaderStageInfo.module = fragShaderModule;
		fragShaderStageInfo.pName = "main";

		VkPipelineShaderStageCreateInfo shaderStages[] = { vertShaderStageInfo, fragShaderStageInfo };


		vkDestroyShaderModule(device, vertShaderModule, nullptr);
		vkDestroyShaderModule(device, fragShaderModule, nullptr);
	}
	
	VkShaderModule createShaderModule(const std::vector<char>& code)
	{
		VkShaderModuleCreateInfo createInfo{};
		createInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
		createInfo.codeSize = code.size();
		createInfo.pCode = reinterpret_cast<const uint32_t*>(code.data());

		VkShaderModule shaderModule;
		if (vkCreateShaderModule(device, &createInfo, nullptr, &shaderModule) != VK_SUCCESS)
			throw std::runtime_error("failed to create shader module!");

		return shaderModule;
	}
	
	std::vector<char> readFile(const std::string& filename)
	{
		std::ifstream file(filename, std::ios::ate | std::ios::binary);

		if (!file.is_open())
			throw std::runtime_error("failed to open file!");

		size_t fileSize = (size_t)file.tellg();
		std::vector<char> buffer(fileSize);
		file.seekg(0);
		file.read(buffer.data(), fileSize);
		file.close();

		return buffer;
	}
```

셰이더 모듈은 로드된  바이트 코드와 그 안에 정의된 함수들을 감싸는 wrapper다. 실제 spir-v가 gpu가 실행할 수 있는 기계어로 컴파일하고 연결하는 작업은 파이프라인이 생성될 떄까지는 진행되지 않는다. 파이프라인이 생성된 뒤에는 셰이더 모듈을 삭제할 수 있다. 따라서 createpipeline 함수안에서 셰이더 모듈을 지역변수로 두고 파이프라인 생성 뒤에는 모듈을 삭제한다.

셰이더를 파이프라인의 일부로 할당하려면 VkPipelineShaderStageCreateInfo 구조체를 통해서 셰이더 정보를 채워야한다. 선택적인 필드로서 pSpecializationInfo가  있다.&#x20;

퍼뮤테이션 / specialization constant / uniformbuffer의 차이점은 다음과 같다.

* **퍼뮤테이션**&#x20;
  * 컴파일 타임에 동작. 쉽게말해서 전처리기 기반의 컴파일 타임 분기. ifdef 등으로 구분. 중복 코드가 제거 되고 매우 빠르다. 하나의 셰이더 파일에 대해 여러개의 spir-v 바이트 코드 파일이 생성된다.
  * 조합이 많아지면 컴파일 타임 / pso 개수 / pso 캐시 파일 크기가 폭발한다. 예를들어 bool 옵션이 30개라면 2^30 = 10억개의 파일이 생성되어 걷잡을 수 없어진다.
  * 이를 해결하기 위해 실무 엔진에서는 그룹별로 나누거나, 조합제한, 작은 차이가 있는 옵션은 specialization constant, uniform buffer 등을 활용한다.
  * 사용처 : GPU 기능 차이가 큰 분기들에 쓰임
    * Forward / Deferred / Tile-based / Clustered
    * 저/중/고 품질 모드
    * PBR vs Unlit vs Toon 등 shading model 자체 변경
    * Shadow 알고리즘 PCF vs VSM vs ESM
    * NormalMap 사용 여부(프리미티브/재질 별로 자주 바뀌지 않음)
    * Skinning on/off (vertex shader 구조 자체 변화)
* **specialization constant**
  * 런타임에 동작. 다양한 변수를 넘길수 있다. uniform buffer와는 다르게 브랜치, 반복문 등에 대해 퍼뮤테이션처럼 최적화가 가능하다. 또한 퍼뮤테이션과는 다르게 단일 spir-v 바이트코드에서 분기를 태우기 떄문에 여러개의 spir-v 바이트 코드를 준비할 필요가 없어  유지보수가 쉽다. 컴파일 타임 폭발도 방지한다.
  * 많은 constant를 셰이더에 넘기면 조합의 갯수가 많아져 파이프라인 생성 비용이 증가할 수 있기 때문에 실무에서는 pso 캐시를 사용하여 해결한다.
  * 사용처 : 런타임에서 자주 바뀌는 옵션
    * 머티리얼 파라미터에 따른 간단한 분기
      * Metallic workflow 선택
      * Clear Coat on/off
      * Double-Sided on/off
      * Env map type 변경
    * 작은 알고리즘 선택
      * BRDF 선택 0/1/2
      * Light count 제한 값
      * texture LOD 모드 변경 등
* 실제 엔진의 예시
  * Unreal Engine 5
    * 큰 기능 차이(쉐이딩 모델, 루프 구조)는 **퍼뮤테이션**
    * Nanite, Lumen, Virtual Shadow Maps 등\
      주요 모듈도 퍼뮤테이션 기반
    * 조그만 옵션(일부 루프 카운트, bool)은 specialization 사용
  * Frostbite (EA)
    * 플랫폼/콘솔별 차이는 퍼뮤테이션
    * Material 옵션은 specialization + push constant 혼합
  * Source 2 (Valve)
    * SPIR-V 기반 → specialization 적극 활용
    * 대형 분기는 오프라인 permutation

용도를 요약하면 다음과 같다.

🔵 **퍼뮤테이션 (Permutation)**

* “코드 자체가 달라질 정도의 큰 기능 차이”에 사용
* 오프라인에서 여러 SPIR-V 생성
* 런타임 비용 zero
* 가장 빠르고 최적화도 좋지만, 조합 폭발 위험

🟠 **스페셜라이제이션 상수 (Specialization Constant)**

* “자주 바뀌며 최적화를 일부 받는 옵션”에 사용
* SPIR-V는 하나지만 파이프라인 생성 시 최적화 적용
* 퍼뮤테이션보다는 덜 강력하지만 훨씬 유연

🟢 **Uniform Buffer (UBO)**

* “실시간 머티리얼 파라미터 전달”
* 최적화는 거의 없음(실행시간 분기문 유지)
* 가장 동적이고 빠르게 업데이트 가능
* 단순 값 전달할 때 사용
