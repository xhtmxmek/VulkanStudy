# 고정 함수

이전 그래픽스 API(dx11, opengl)은 파이프라인 대부분의 단계에 대해 동적으로 변경 가능한 상태 지정을 할 수 있었다. vulkan에서는 대부분의 파이프라인 상태가 변경 불가능한 파이프라인 객체로 변환되므로 명시적으로 지정해야한다.

#### **Dynamic state**

pipline state 대부분은 베이크되어야하지만, 제한된 양의 state는 draw 시점에 파이프라인을 다시 생성하지 않고 변경할수 있음. 이런 state들은 gpu에 부담이 거의 없고 자주 바뀌는 값들이다. 자주 바뀌기에 파이프라인 상태가 폭발적으로 증가하는 걸 막기 위해서 vulkan에서 dynamic state로 열어 두었다. 예를들면 다음과 같은 state들이다.

* Viewport
* Scissor
* Blend constants
* Depth bias
* Stencil reference

반면 파이프라인에 베이크 되어야 하는 state들은 다음과 같다.

* 렌더 패스 / attachment format
* 프래그먼트 출력 수
* blend enable 여부
* depth test enable 여부
* primitive topology
* sample count
* shader modules (당연)
* descriptor layout

dynamic state는 다음과 같이 구성한다.

```cpp
		std::vector<VkDynamicState> dynamicStates = {
			VK_DYNAMIC_STATE_VIEWPORT,
			VK_DYNAMIC_STATE_SCISSOR
		};

		VkPipelineDynamicStateCreateInfo dynamicState{};
		dynamicState.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
		dynamicState.dynamicStateCount = static_cast<uint32_t>(dynamicStates.size());
		dynamicState.pDynamicStates = dynamicStates.data();
```

#### Vertex Input

vertex shader에 전달될 형태의 구조체가 필요하다. dx의 vertexLayout에 대응된다. 다음과 같이 두가지 요소가 필요하다

*   바인딩 : 데이터 stride(간격) 및 정점별인지 인스턴스별인지 여부

    ```cpp
    VkVertexInputBindingDescription binding = {};
    binding.binding = 0;           // 정점 버퍼 슬롯 번호
    binding.stride = sizeof(Vertex); // 한 정점의 크기
    binding.inputRate = VK_VERTEX_INPUT_RATE_VERTEX; // 정점 별 or 인스턴스 별

    ```
*   attribue description : vertex shader에 전달된 attribute(속성. 각 element를 의미)의 유형, attribute를 로드할 바인딩 및 오프셋

    ```cpp
    VkVertexInputAttributeDescription pos = {};
    pos.location = 0;                 // vertex shader의 layout(location = 0)
    pos.binding = 0;                  // 위에서 설명한 binding 0번
    pos.format = VK_FORMAT_R32G32B32_SFLOAT; // float3
    pos.offset = offsetof(Vertex, position); // 구조체 내 offset
    ```


*   attribute는 셰이더 안에서 이렇게 매핑됨

    ```cpp
    struct Vertex {
        float3 pos;     // location 0
        float3 normal;  // location 1
        float2 uv;      // location 2
    };
    ```

binding과 location이 구분되어있는 경우는 여러 개의 정점 버퍼를 스트림으로 입력할 수 있기 때문이다.(예:binding 0 = pos, binding1 = normal/specular). 셰이더에서는 location으로만 입력을 구분하기 때문에 서로 다른 바인딩 간에도 location이 절대로 중복되면 안된다. location은 고유해야 한다.

```cpp
VkPipelineVertexInputStateCreateInfo vertexInputInfo{};
vertexInputInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
vertexInputInfo.vertexBindingDescriptionCount = 0;
vertexInputInfo.pVertexBindingDescriptions = nullptr;
vertexInputInfo.vertexAttributeDescriptionCount = 0;
vertexInputInfo.pVertexBindingDescriptions = nullptr;
```

지금 삼각형 예제에서는 vertex를 셰이더에서 하드코딩하고있으므로 vertex 관련 필드는 추후 vertex buffer 내용에서 다시 살펴보고 nullptr로 채워둔다.

#### Input Assembly

**VkPipelineInputAssemblyStateCreateInfo** 구조체를 채워서 세팅한다.

primitiveTopology와 strip시 기본 재시작을 활성화 할지 여부를 결정한다. topology는 dx와 크게 다르지않다.STRIP은 마지막 정점들로부터 재사용,  list는 재사용 없음

* `VK_PRIMITIVE_TOPOLOGY_POINT_LIST`: points from vertices
* `VK_PRIMITIVE_TOPOLOGY_LINE_LIST`: line from every 2 vertices without reuse
* `VK_PRIMITIVE_TOPOLOGY_LINE_STRIP`: the end vertex of every line is used as start vertex for the next line
* `VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST`: triangle from every 3 vertices without reuse
* `VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP`: the second and third vertex of every triangle are used as first two vertices of the next triangle

primitiveRestartEnable 필드를 true로  설정하면 strip 사용시 인덱스 버퍼에서 0xFFFF 같은 특수한 인덱스를 넣어서 선과 삼각형을 강제로 분할할 수 있다.

```cpp
VkPipelineInputAssemblyStateCreateInfo inputAssembly{};
inputAssembly.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
inputAssembly.primitiveRestartEnable = VK_FALSE;
```

#### 뷰포트와 가위 판정

뷰포트는 이미지에서 프레임버퍼로의 변환이다. ( gpu는 ndc좌표를쓰기때문에 해상도 좌표계인 프레임버퍼로의 변환이 뷰포트를 통해서 이뤄진다.) 뷰포트가 스왑체인보다 크기가 작으면 그만큼 축소되어보이고 나머지 영역은 빈공간이기에 스왑체인이나뷰포트의clearColor로 매핑됨. 뷰포트가 스왑체인보다 크면 확대되서 늘어난 것처럼 보이고 일부분이 잘리게 된다.

가위판정은 프레임버퍼가 실제로 보일 영역 자체를 자르는 것이다.

<figure><img src="../../.gitbook/assets/viewports_scissors.png" alt=""><figcaption></figcaption></figure>

출처 : vulkan 튜토리얼 [https://vulkan-tutorial.com/Drawing\_a\_triangle/Graphics\_pipeline\_basics/Fixed\_functions](https://vulkan-tutorial.com/Drawing_a_triangle/Graphics_pipeline_basics/Fixed_functions)

이번 예제에서는 프레임 버퍼를 비율 변경 없이 보여줄것이기 때문에 뷰포트와 가위 판정 크기를 스왑체인 크기만큼 동일하게 설정한다.

뷰포트와 가위 판정은 파이프라인의 다른상태들처럼정적인 상태로 베이크 하거나 동적인 상태로 지정 할 수 있다. 둘다 동적으로 지정하는게 일반적이며 성능 저하가 없다.

```cpp
std::vector<VkDynamicState> dynamicStates = {
    VK_DYNAMIC_STATE_VIEWPORT,
    VK_DYNAMIC_STATE_SCISSOR
};

VkPipelineDynamicStateCreateInfo dynamicState{};
dynamicState.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
dynamicState.dynamicStateCount = static_cast<uint32_t>(dynamicStates.size());
dynamicState.pDynamicStates = dynamicStates.data();
```

동적 뷰포트 상태 혹은 가위 판정을 사용하는경우 pipeline 구조체를 통해서 상태를 생성하는 것이 아니라 렌더링 시점에 설정한다. 파이프라인생성시점에서는 갯수만 지정해 주면 된다.

```cpp
//렌더링 시점에 사용
VkRect2D scissor{};
scissor.offset = {0, 0};
scissor.extent = swapChainExtent;

//파이프라인 생성 시점에는 개수만 할당.
VkPipelineViewportStateCreateInfo viewportState{};
viewportState.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
viewportState.viewportCount = 1;
viewportState.scissorCount = 1;
//파이프라인 생성 객체에 지정할 경우 뷰포트나 가위 판정을 변경하려면 파이프라인을 새로 만들어야함.
viewportState.pViewports = &viewport;
viewportState.pScissors = &scissor;
```

#### 래스터라이저

래스터라이저는 익히 아는것처럼 버텍스 셰이더에서 프래그먼트 셰이더에서 채색할 프래그먼트들을 가져옴.

뎁스 테스트, 페이스 컬링,  가위테스트등을수행.   와이어프레임 출력 기능.

```cpp
VkPipelineRasterizationStateCreateInfo rasterizer{};
rasterizer.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
rasterizer.depthClampEnable = VK_FALSE;
rastierzer.rasterizerDiscardEnable = VK_FALSE;
```

depthClampEnable를 true로 설정하면, near plane과 far plane을 벗어나는 애들도 보존한다. ratsterizerDiscardEnable을 VK\_TRUE로 설정하면 framebuffer로 출력이 안된다.

```cpp
rasterizer.lineWidth = 1.0f;
```

lineWidth는 1.0보다 더 크게 설정할 수 있는데 GPU에 따라 다르다. gpu 기능 widelines를 활성화 해야한다.

그 외에는 fillMode, frontFace, cull mode 등이 포함된다. 그림자 매핑을 위한 depthbias 옵션도 있다.

#### MSAA

msaa는 단순 슈퍼샘플링 보다 저렴하다. 사용하려면 gpu 기능을 활성화 해야한다.

```cpp
VkPipelineMultisampleStateCreateInfo multisampling{};
multisampling.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
multisampling.sampleShadingEnable = VK_FALSE;
multisampling.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;
multisampling.minSampleShading = 1.0f; // Optional
multisampling.pSampleMask = nullptr; // Optional
multisampling.alphaToCoverageEnable = VK_FALSE; // Optional
multisampling.alphaToOneEnable = VK_FALSE; /
```

#### 깊이 및 스텐실 테스트

VkPipelineDepthStencilCreateInfo 구조체를 채워서 만든다. 지금 당장은 뎁스버퍼가 필요하지 않다. 이후 뎁스버퍼 챕터에서 다룬다.

#### 색상 혼합

프레임 버퍼당 할당되는 VkPipelineColorBlendAttachmentState와 전역파이프라인설정인VkPipelineColorBlendStateCreateInfo가 있다.

```cpp
VkPipelineColorBlendAttachmentState colorblendAttachment{};
colorblendAttachment.blendEnable = VK_TRUE;
colorblendAttachment.colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT 
	| VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT;
colorblendAttachment.srcColorBlendFactor = VK_BLEND_FACTOR_SRC_ALPHA;
colorblendAttachment.dstColorBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
colorblendAttachment.colorBlendOp = VK_BLEND_OP_ADD;
colorblendAttachment.srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE;
colorblendAttachment.dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO;
colorblendAttachment.alphaBlendOp = VK_BLEND_OP_ADD;

VkPipelineColorBlendStateCreateInfo colorBlending;
colorBlending.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
colorBlending.logicOpEnable = VK_FALSE;
colorBlending.logicOp = VK_LOGIC_OP_COPY;
colorBlending.attachmentCount = 1;
colorBlending.pAttachments = &colorblendAttachment;
colorBlending.blendConstants[0] = 0.f;
colorBlending.blendConstants[1] = 0.f;
colorBlending.blendConstants[2] = 0.f;
colorBlending.blendConstants[3] = 0.f;
```

#### 파이프라인 레이아웃

셰이더에전달되는 동적인 uniform 변수들은 VkPipelineLayoutCreateInfo 객체를 통해서 전달되어야 한다. uniform 변수가 존재하지 않을지라도 빈 pipelineLayout을 설정해야한다.

uniform 변수 말고도 pushConstatnt를 통해서 동적인 값을 전달할수 있다.uniform과 pushConstant에 대해서는 추후 다룰 예정이다.

파이프라인 레이아웃은 실행 내내 참조되므로 종료시에 해제한다.

```cpp
VkPipelineLayoutCreateInfo pipelineLayoutInfo{};
pipelineLayoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
pipelineLayoutInfo.setLayoutCount = 0;
pipelineLayoutInfo.pSetLayouts = nullptr;
pipelineLayoutInfo.pushConstantRangeCount = 0;
pipelineLayoutInfo.pPushConstantRanges = nullptr;

if (vkCreatePipelineLayout(device, &pipelineLayoutInfo, nullptr, &pipelineLayout) != VK_SUCCESS)
{
//...
}

void cleanup() 
{
		vkDestroyPipelineLayout(device, pipelineLayout, nullptr);
		//...
}
```

#### 결론

vulkan의 파이프라인의 핵심은 파이프라인객체들을 opengl/dx11과는 달리 베이크하는 방식이다. 매번 파이프라인 상태의유효성을검사하고 갱신하던 dx11과는 달리 pso 핸들만 교체하면 되서 cpu 드라이버에서 발생하는 오버헤드가 극단적으로 적다.&#x20;

또한 이 베이크 방식의 장점은 이전 api에서는 상태 객체들이 파편화 되있었기때문에 이전 상태가 현재 렌더링에 영향을 미칠 수 있어서 상태 객체에 대한 디버그가 매우 어려웠으나, vulkan이나 dx12같은현대적인 api에서는현재 바인딩된 파이프라인 안에서 상태를 디버깅하면 되기 때문에 렌더 스테이트로 인한 버그도 매우 줄어든다.

