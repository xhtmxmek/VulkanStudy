# 결론

이전 장에서 다른 구조체들과 객체들을 결합하여 파이프라인을 생성할 준비가 되었다. 현재 준비된 객체 유형들은 다음과 같다.

* shader stage: 셰이더 모듈
* 고정 기능 state : input assembly, 래스터라이저, 색상 혼합, 뷰포트 같은 파이프라인 고정 기능
* 파이프라인 레이아웃 : 셰이더에서 참조되는 uniform과 push constant. 동적으로 드로우 타임에 업데이트 가능
* 렌더링 패스 : 파이프라인 단계에서 참조되는 attachment 및 사용 방법

이 모든 것이 합쳐져 그래픽스 파이프라인이 정의된다. **VkGraphicsPipelineCreateInfo** 구조체를 초기화 하면된다. **vkDestroyShaderModule** 함수는 파이프라인 생성 이후에 호출한다.

```cpp
VkGraphicsPipelineCreateInfo pipelineCreateInfo{};
pipelineInfo.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
pipelineInfo.stageCount = 2;
pipelineInfo.pStages = shaderStages;
pipelineInfo.pVertexInputState = &vertexInputInfo;
pipelineInfo.pInputAssemblyState = &inputAssembly;
pipelineInfo.pViewportState = &viewportState;
pipelineInfo.pRasterizationState = &rasterizer;
pipelineInfo.pMultisampleState = &multisampling;
pipelineInfo.pDepthStencilState = nullptr;
pipelineInfo.pColorBlendState = &colorBlending;
pipelineInfo.pDynamicState = &dynamicState;
pipelineInfo.layout = pipelineLayout;
pipelineInfo.renderPass = renderPass;
pipelineInfo.subpass = 0;
pipelineInfo.basePipelineHandle = VK_NULL_HANDLE;
pipelineInfo.basePipelineIndex = -1;

if (vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, &pipelineInfo, nullptr, &graphicsPipeline) != VK_SUCCESS)
{
	throw std::runtime_error("failed to create graphics pipeline!");
}
```

셰이더 단계와 고정 기능 state, layout을 지정하고 renderpass와 renderpass 안에서의 subpass의 인덱스도 지정해준다. 
vkGraphicsPipelines 함수의 두번째 인자는 vkPipelineCache 객체를 참조한다. 파이프라인 캐시는 파이프라인 생성과 관련된 데이터를 저장하고 재사용하는데 사용할 수 있다. 해당 캐시를 파일에 저장할 경우 프로그램 실행간에도 재사용이 가능하다. 이를 통해 나중에 파이프라인을 생성할 때 속도를 크게 향상시킬 수 있다. 추후에 다룰 예정

#### 서브패스와 파이프라인의 관계

정확하게는, **서브패스와 그래픽스 파이프라인이 1:1 매칭이 된다**. 서브패스가 여러개면 파이프라인도 여러개가 필요하다. 

**중요한 점**: 파이프라인 생성 시 `subpass` 필드는 해당 파이프라인이 어떤 서브패스에서 사용될 수 있는지를 지정한다. 따라서 같은 파이프라인 설정을 여러 서브패스에서 사용하려면, 각 서브패스마다 별도의 파이프라인 객체를 생성해야 한다.

**효율적인 방법**: `VkGraphicsPipelineCreateInfo` 구조체는 재사용할 수 있다. 같은 설정을 여러 서브패스에서 사용할 경우, 구조체를 한 번 설정한 후 `subpass` 필드만 바꿔서 여러 파이프라인을 생성하면 된다. 최종적으로 생성되는 `VkPipeline` 객체만 별도로 관리하면 된다.

```cpp
// 예시: 같은 설정의 파이프라인을 서브패스 0과 1에서 사용
VkGraphicsPipelineCreateInfo pipelineInfo{};
// ... 동일한 셰이더, 고정 기능 설정들 ...
pipelineInfo.renderPass = renderPass;

// 서브패스 0용 파이프라인 생성
pipelineInfo.subpass = 0;
VkPipeline pipeline0;
vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, &pipelineInfo, nullptr, &pipeline0);

// pipelineInfo 구조체 재사용, subpass 필드만 변경
pipelineInfo.subpass = 1;
VkPipeline pipeline1;
vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, &pipelineInfo, nullptr, &pipeline1);
```

파이프라인 객체(`VkPipeline`)는 특정 서브패스 인덱스와 바인딩되므로, 같은 설정이라도 서브패스가 다르면 별도의 파이프라인 객체가 필요하다. 하지만 `VkGraphicsPipelineCreateInfo` 구조체는 재사용 가능하므로 효율적으로 여러 파이프라인을 생성할 수 있다.

