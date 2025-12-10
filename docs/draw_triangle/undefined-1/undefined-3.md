# 렌더 패스

파이프라인을 만들기 전에 vulkan에 렌더링 할때 framebuffer attchment를 사용한다고 말해야 한다. 얼마나 많은 color buffer, depth buffer, stencil 버퍼가 있는지, 멀티샘플링을 위한 샘플카운트는 얼마나 되는지, frambuffer의 내용이 어떻게 다뤄질지를 결정해야 한다. vulkan에서는 이를 Render pass 객체로 래핑해서 세팅한다. createRenderPass 함수를 만들어createGraphicsPipeline 전에 만들고 호출한다..

```cpp
void initVulkan() {
//.......
    createRenderPass();
    createGraphicsPipeline();
}

...

void createRenderPass() {

}
```

#### Attachment Description

우리는 스왑체인과 대응되는 하나의 칼라 버퍼만 사용할 예정이기에, attachment도 하나만 선언해준다.\
멀티샘플링은 수행하지 않을 것이기에 샘플카운트는 1로 고정해주고, 이미지의 포맷은 스왑체인의 포맷과 같게 설정해준다.

loadOp와 storeOp는 attachment에 있는 데이터가 렌더링을 시작할 때, 그리고 렌더링을 마칠때 어떻게 다뤄질지를 결정한다. loadop를 위해선 다음과 같은 옵션이 있다.

* `VK_ATTACHMENT_LOAD_OP_LOAD`: attachment의 기존 데이터를 보존한다
* `VK_ATTACHMENT_LOAD_OP_CLEAR`: 패스가 시작할때 clear value로 초기화한다
* `VK_ATTACHMENT_LOAD_OP_DONT_CARE`: 기존 내용은 신경쓰지 않는다. gpu 최적화에 용이하다.
* VK\_ATTACHMENT\_LOAD\_OP\_NONE : 현재 내용 유지. vulkan 1.3에 새로 추가된 기능. color/depth buffer에 대해서는 사실상 dont\_care와 용도가 같다. 명확하게 로드 생략이 되므로 드라이버 최적화가 된다.

store를 위해선 다음과 같은 옵션이 있다.

* `VK_ATTACHMENT_STORE_OP_STORE`: 렌더링된 내용이 보존되고 이후에 사용된다.
* `VK_ATTACHMENT_STORE_OP_DONT_CARE`: 렌더링 이후에 내용이 undefined 된다.

color/depth는 loadOp, stencilOp를, stencil은 stencilLoadOp, stencilStoreOp를 사용한다.

레거시 api에서는 드라이버가 암시적으로 loadOp, StoreOp를 수행하였다. 매 프레임 렌더링 되기 때문에 이전 내용을 보존할 필요가 없는 프레임버퍼도 무조건 vram에서 load를 수행하였고 렌더링 이후에도 암시적으로 driver가 store를 하기에 오버헤드가 발생했다. vram 접근/쓰기 비용이 발생하는건 덤이다. 즉 사용자가 렌더패스에서 리소스에대한 vram에읽기/쓰기 여부를 선택할 수 없었다. 모던 api에서는 이를 명시적으로 선택 가능하도록 해줘서 불필요한 vram 접근/쓰기 비용을 없애고 드라이버 오버헤드도 줄인다.&#x20;

layout 또한 지정되어야 하는데, 그 종류는 다음과 같다.

* `VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL`: 이미지가 color attachment로서 사용된다.
* `VK_IMAGE_LAYOUT_PRESENT_SRC_KHR`: 이미지가 스왑체인에서 present된다.
* `VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL`: 이미지가 복사같은 연산의 대상이된다.

이 상태의 전이 역시 레거시 api가 암시적으로 수행하던것을 명시적으로 수행하여 드라이버 오버헤드를 줄인 것이다.

*   **dx11**

    ```
    swapchain 이미지 → Clear → Draw → Present
    ```
*   **dx12/vulkan**

    ```
    Swapchain 이미지: PRESENT 상태
    ↓
    (Barrier) → RENDER_TARGET 상태로 전환
    ↓
    Clear / Draw
    ↓
    (Barrier) → 다시 PRESENT 상태로 전환
    ↓
    Present
    ```

gpu명령은 순차적이지만 실제 실행은 비동기이다. 레거시에서는 이명령들에 대해 드라이버가 추론하여 암시적인 배리어를 추가하였다. 그에따른 드라이버 오버헤드도 발생. 다만 모던api에서는 명시적으로 설정한다. renderPass에서는 barrier를 자동으로 삽입해주지만 renderPass간의 데이터 공유라던지, renderpass와 computePass의 데이터를 주고받을때는 resourceBarrier를 꼭 사용해야 한다.&#x20;

```cpp
void createRenderPass() {
    VkAttachmentDescription colorAttachment{};
    colorAttachment.format = swapChainImageFormat;
    colorAttachment.samples = VK_SAMPLE_COUNT_1_BIT;
    colorAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
    colorAttachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
    colorAttachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    colorAttachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    colorAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    colorAttachment.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
}
```

#### 서브패스와 attchment reference

하나의 renderpass는 여러개의 subpass로 구성된다. bloom과 같은 pp를 예로들자면 g버퍼 서브패스와 bloom패스를 혼합할 수 있다. 모바일 gpu와 같은 타일 기반 렌더링에 renderPass는 최적화 되어있다. 렌더패스 사용시 vram이아닌 chipset memory를 적극적으로 활용한다.각 서브패스간 결과를 vram으로 보내지 않고 칩셋 메모리에 저장했다가 재사용하는것이다.

서브 패스는 하나 이상의 attachment를 가질 수 있다. attchment는 RenderPass에 전역적인 배열로 할당하고 해당 attachment의 index를 attachmentRef를 통해서참조한다. &#x20;

```cpp
		VkAttachmentReference colorAttachmentRef{};
		colorAttachmentRef.attachment = 0;
		colorAttachmentRef.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
		
		VkSubpassDescription subpass{};
		subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
		subpass.colorAttachmentCount = 1;
		subpass.pColorAttachments = &colorAttachmentRef;

		VkRenderPassCreateInfo renderPassInfo{};
		renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
		renderPassInfo.attachmentCount = 1;
		renderPassInfo.pAttachments = &colorAttachment;
		renderPassInfo.subpassCount = 1;
		renderPassInfo.pSubpasses = &subpass;
```

구조를 보면 다음과 같다.

```cpp
RenderPass
 ├─ Attachments [color0, depth0, ...]
 ├─ Subpass 0
 │    ├─ colorAttachments: attachmentRef(index=0)  -> color0
 │    └─ depthAttachment: attachmentRef(index=1)  -> depth0
 └─ Subpass 1
      ├─ colorAttachments: attachmentRef(index=0)  -> color0
      └─ depthAttachment: attachmentRef(index=1)  -> depth0
```

서브패스는 종류별로  여러개의 attachment를 가질 수 있다. fragment shader에서는 이 인덱스가 layout을 통해서 전달된다.

```
layout(location = 0) out vec4 OutColor0;
layout(location = 1) out vec4 OutColor1;
layout(location = 2) out vec4 OutColor2;
```

이렇게 받을 수도 있다.

#### 렌더 패스

```cpp
VkRenderPassCreateInfo renderPassInfo{};
renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
renderPassInfo.attachmentCount = 1;
renderPassInfo.pAttachments = &colorAttachment;
renderPassInfo.subpassCount = 1;
renderPassInfo.pSubpasses = &subpass;

if (vkCreateRenderPass(device, &renderPassInfo, nullptr, &renderPass) != VK_SUCCESS) {
    throw std::runtime_error("failed to create render pass!");
}
```

앱을 종료할때 renderPass 관련 정리도 수행한다.

```cpp
void cleanup() {
    vkDestroyPipelineLayout(device, pipelineLayout, nullptr);
    vkDestroyRenderPass(device, renderPass, nullptr);
    ...
}
```
