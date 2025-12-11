# 프레임 버퍼

RenderPass에서 정의한 attachment 구조를 실제로 사용하려면, 그 구조에 맞는 실제 이미지 뷰들을 Framebuffer로 묶어서 RenderPass에 연결해야 한다
즉 FrameBuffer{vkimageView(fromSwapChain)} <-> RenderPass{Attachment}
와 같이 되는 것이다.
스왑 체인에는 여러개의 이미지가 들어가면서 버퍼링을 하지만, 해당 스왑체인이 연결된 renderpass는 단 하나의 attachment를 가지고있을 수 있다.

```c++
Swap Chain: [이미지1, 이미지2, 이미지3]  ← 여러 개의 이미지가 있음
Render Pass: "color attachment 하나 사용하겠다"  ← 어떤 이미지인지는 모름
```

다음과 같을 수 있다. 따라서 **swapChain의 각 이미지마다 Framebuffer를 하나씩 생성**하고, 렌더링 시 현재 사용할 이미지에 맞는 Framebuffer를 선택해야한다.

**구조 요약**:
- SwapChain: 이미지 3개 (예시)
- **Framebuffer: 3개** (각 이미지마다 1개씩)
- **각 Framebuffer: attachment 1개** (해당 swapchain 이미지의 ImageView)
- RenderPass: attachment 1개 정의

즉, "Framebuffer에 attachment가 3개"가 아니라 **"Framebuffer가 3개이고, 각 Framebuffer는 attachment 1개"**입니다.

```c++
	void initVulkan()
	{
        //....
		createRenderPass();
		createGraphicsPipeline();
		createFramebuffers();
	}

    void cleanup() 
    {
	    for (auto framebuffer : swapChainFrameBuffers)
	        vkDestroyPipeline(device, graphicsPipeline, nullptr);
        //.....
    }

	void createFramebuffers()
	{
		swapChainFrameBuffers.resize(swapChainImageViews.size());

		for (size_t i = 0; i < swapChainImageViews.size(); i++)
		{
			VkImageView attachments[] = {swapChainImageViews[i]};

			VkFramebufferCreateInfo frameBufferInfo{};
			frameBufferInfo.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
			frameBufferInfo.renderPass = renderPass;
			frameBufferInfo.attachmentCount = 1;
			frameBufferInfo.pAttachments = attachments;
			frameBufferInfo.width = swapChainExtent.width;
			frameBufferInfo.height = swapChainExtent.height;
			frameBufferInfo.layers = 1;

			if (vkCreateFramebuffer(device, &frameBufferInfo, nullptr, &swapChainFrameBuffers[i]) != VK_SUCCESS)
			{
				throw std::runtime_error("failed to create framebuffer!");
			}
		}
	}
private:
	std::vector<VkFramebuffer> swapChainFramebuffers;
```

실제 렌더링 시점에는 다음과 같이 선택을 할 것이다.
```c++
    //실제 렌더링 시점에
    uint32_t imageIndex;  // 현재 사용할 이미지 인덱스
    vkAcquireNextImageKHR(...);  // Swap Chain에서 이미지 가져오기

    // 해당 이미지에 맞는 Framebuffer 사용
    VkFramebuffer framebuffer = swapChainFramebuffers[imageIndex];
```

#### Attachment 인덱스 매핑

Framebuffer의 `attachmentCount`와 `pAttachments` 파라미터는 **RenderPass의 `pAttachments` 배열에 정의된 각 attachment description에 바인딩될 실제 VkImageView 객체들을 지정**합니다.

**현재 코드의 경우** (attachment 1개):
```cpp
// RenderPass: color attachment 1개 정의
VkAttachmentDescription colorAttachment;  // 인덱스 0
renderPassInfo.attachmentCount = 1;
renderPassInfo.pAttachments = &colorAttachment;  // [0]=color

// Framebuffer: 각각 attachment 1개씩 제공
VkImageView attachments[] = {swapChainImageViews[i]};  // 인덱스 0
frameBufferInfo.attachmentCount = 1;
frameBufferInfo.pAttachments = attachments;  // [0]=swapChainImageViews[i]
```

**인덱스 기반 매핑**:
- Framebuffer의 `pAttachments[0]` → RenderPass의 `pAttachments[0]` (첫 번째 attachment description)
- Framebuffer의 `pAttachments[1]` → RenderPass의 `pAttachments[1]` (두 번째 attachment description)
- ...

**여러 attachment가 있는 경우 예시** (depth buffer 추가 시):

```cpp
// RenderPass 생성 시
VkAttachmentDescription attachments[2];
attachments[0] = colorAttachment;      // 인덱스 0: color attachment
attachments[1] = depthAttachment;      // 인덱스 1: depth attachment

VkRenderPassCreateInfo renderPassInfo{};
renderPassInfo.attachmentCount = 2;
renderPassInfo.pAttachments = attachments;  // [0]=color, [1]=depth
```

Framebuffer에서는 **같은 인덱스 순서**로 실제 이미지 뷰를 제공해야 합니다:

```cpp
// Framebuffer 생성 시 (각 swapchain 이미지마다)
VkImageView framebufferAttachments[2];
framebufferAttachments[0] = swapChainImageViews[i];  // 인덱스 0 → RenderPass의 attachments[0]에 바인딩
framebufferAttachments[1] = depthImageView;          // 인덱스 1 → RenderPass의 attachments[1]에 바인딩

VkFramebufferCreateInfo frameBufferInfo{};
frameBufferInfo.renderPass = renderPass;
frameBufferInfo.attachmentCount = 2;
frameBufferInfo.pAttachments = framebufferAttachments;  // [0]=colorImageView, [1]=depthImageView
```

**중요**: Framebuffer의 `pAttachments` 배열 인덱스는 RenderPass의 `pAttachments` 배열 인덱스와 **1:1로 대응**됩니다. 즉, Framebuffer의 `pAttachments[i]`는 RenderPass의 `pAttachments[i]`에 정의된 attachment description을 구현하는 실제 이미지 뷰입니다.

---

## DX11 기준 비유: 포스트 프로세스 예시

DX11과 Vulkan의 개념을 비교하면 다음과 같습니다:

### DX11에서의 개념
- **RenderTarget (Texture2D)** = `VkImage`
- **RenderTargetView (RTV)** = `VkImageView`
- **DeviceContext::OMSetRenderTargets()** = Framebuffer에 attachment 바인딩
- **여러 RTV를 묶어서 사용 (MRT)** = Subpass에서 여러 color attachment 사용

### 포스트 프로세스 예시: G-Buffer + 포스트 프로세싱

#### 시나리오
1. **Subpass 0**: G-Buffer 생성 (MRT 3개 + depth)
2. **Subpass 1**: G-Buffer 결과를 텍스처로 읽어서 포스트 프로세싱, 스크린 쿼드에 그림

#### 최종 출력 대상
- **케이스 1**: 하나의 렌더타겟 이미지
- **케이스 2**: 스왑체인

---

### 케이스 1: 하나의 렌더타겟 이미지에 출력

#### DX11에서의 코드 (비유)
```cpp
// DX11
ID3D11RenderTargetView* gBufferRTVs[3];  // G-Buffer MRT 3개
ID3D11RenderTargetView* depthRTV;
ID3D11RenderTargetView* finalRTV;  // 최종 출력용 렌더타겟

// Subpass 0: G-Buffer 생성
context->OMSetRenderTargets(3, gBufferRTVs, depthRTV);
// ... 지오메트리 렌더링 ...

// Subpass 1: 포스트 프로세싱
context->OMSetRenderTargets(1, &finalRTV, nullptr);
// ... 스크린 쿼드 렌더링 ...
```

#### Vulkan에서의 구조

**RenderPass 정의** (어떤 attachment가 필요한지 설명):
```cpp
// RenderPass: 전체 attachment 구조 정의
VkAttachmentDescription attachments[5];
// 인덱스 0, 1, 2: G-Buffer MRT 3개
attachments[0] = gBuffer0Attachment;  // Albedo
attachments[1] = gBuffer1Attachment;  // Normal
attachments[2] = gBuffer2Attachment;  // Material
attachments[3] = depthAttachment;     // Depth
attachments[4] = finalColorAttachment; // 최종 출력

// Subpass 0: G-Buffer 생성
VkAttachmentReference gBufferRefs[3];
gBufferRefs[0] = {0, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL};  // attachments[0]
gBufferRefs[1] = {1, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL};  // attachments[1]
gBufferRefs[2] = {2, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL};  // attachments[2]
VkAttachmentReference depthRef = {3, VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL};

VkSubpassDescription subpass0{};
subpass0.colorAttachmentCount = 3;
subpass0.pColorAttachments = gBufferRefs;  // MRT 3개
subpass0.pDepthStencilAttachment = &depthRef;

// Subpass 1: 포스트 프로세싱
VkAttachmentReference finalColorRef = {4, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL};
VkAttachmentReference inputRefs[3];  // G-Buffer를 입력으로 읽음
inputRefs[0] = {0, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL};  // attachments[0]을 읽기
inputRefs[1] = {1, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL};  // attachments[1]을 읽기
inputRefs[2] = {2, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL};  // attachments[2]를 읽기

VkSubpassDescription subpass1{};
subpass1.colorAttachmentCount = 1;
subpass1.pColorAttachments = &finalColorRef;  // attachments[4]에 출력
subpass1.inputAttachmentCount = 3;
subpass1.pInputAttachments = inputRefs;  // G-Buffer를 입력으로 사용

VkRenderPassCreateInfo renderPassInfo{};
renderPassInfo.attachmentCount = 5;
renderPassInfo.pAttachments = attachments;  // [0]=gBuffer0, [1]=gBuffer1, [2]=gBuffer2, [3]=depth, [4]=final
renderPassInfo.subpassCount = 2;
renderPassInfo.pSubpasses = &subpass0, &subpass1;
```

**Framebuffer 생성** (실제 이미지 뷰들을 바인딩):
```cpp
// 실제 이미지 뷰들
VkImageView gBuffer0View, gBuffer1View, gBuffer2View;  // G-Buffer 이미지 뷰
VkImageView depthView;                                  // Depth 이미지 뷰
VkImageView finalColorView;                             // 최종 출력 이미지 뷰

// Framebuffer: RenderPass의 attachment 구조에 실제 이미지 뷰를 바인딩
VkImageView framebufferAttachments[5];
framebufferAttachments[0] = gBuffer0View;   // RenderPass의 attachments[0]에 바인딩
framebufferAttachments[1] = gBuffer1View;   // RenderPass의 attachments[1]에 바인딩
framebufferAttachments[2] = gBuffer2View;   // RenderPass의 attachments[2]에 바인딩
framebufferAttachments[3] = depthView;      // RenderPass의 attachments[3]에 바인딩
framebufferAttachments[4] = finalColorView; // RenderPass의 attachments[4]에 바인딩

VkFramebufferCreateInfo frameBufferInfo{};
frameBufferInfo.renderPass = renderPass;  // 위에서 정의한 RenderPass 사용
frameBufferInfo.attachmentCount = 5;
frameBufferInfo.pAttachments = framebufferAttachments;  // 인덱스 순서대로 매핑
```

**핵심**:
- **RenderPass** = "어떤 attachment가 필요한지, 어떤 서브패스가 있는지" 정의 (템플릿)
- **Framebuffer** = RenderPass의 attachment 구조에 **실제 이미지 뷰들을 바인딩** (구현체)
- **인덱스 매핑**: `framebufferAttachments[i]` → `renderPassAttachments[i]`

---

### 케이스 2: 스왑체인에 출력

#### DX11에서의 코드 (비유)
```cpp
// DX11
ID3D11RenderTargetView* gBufferRTVs[3];
ID3D11RenderTargetView* depthRTV;
IDXGISwapChain* swapChain;
ID3D11RenderTargetView* swapChainRTV;  // 스왑체인의 현재 백버퍼

// Subpass 0: G-Buffer 생성
context->OMSetRenderTargets(3, gBufferRTVs, depthRTV);
// ... 지오메트리 렌더링 ...

// Subpass 1: 포스트 프로세싱 (스왑체인에 출력)
swapChain->GetBuffer(0, ..., &backBuffer);
device->CreateRenderTargetView(backBuffer, ..., &swapChainRTV);
context->OMSetRenderTargets(1, &swapChainRTV, nullptr);
// ... 스크린 쿼드 렌더링 ...
```

#### Vulkan에서의 구조

**RenderPass 정의** (동일):
```cpp
// RenderPass는 동일 (스왑체인 이미지도 하나의 attachment일 뿐)
VkAttachmentDescription attachments[5];
attachments[0] = gBuffer0Attachment;
attachments[1] = gBuffer1Attachment;
attachments[2] = gBuffer2Attachment;
attachments[3] = depthAttachment;
attachments[4] = swapChainColorAttachment;  // 스왑체인용 attachment

// Subpass 정의는 동일...
```

**Framebuffer 생성** (스왑체인 이미지마다):
```cpp
// 스왑체인에는 여러 이미지가 있음
std::vector<VkImageView> swapChainImageViews;  // 스왑체인 이미지 뷰들

// G-Buffer와 Depth는 공통으로 사용
VkImageView gBuffer0View, gBuffer1View, gBuffer2View;
VkImageView depthView;

// 각 스왑체인 이미지마다 Framebuffer 생성
for (size_t i = 0; i < swapChainImageViews.size(); i++)
{
    VkImageView framebufferAttachments[5];
    framebufferAttachments[0] = gBuffer0View;           // 공통
    framebufferAttachments[1] = gBuffer1View;           // 공통
    framebufferAttachments[2] = gBuffer2View;          // 공통
    framebufferAttachments[3] = depthView;              // 공통
    framebufferAttachments[4] = swapChainImageViews[i]; // 스왑체인 이미지 i번째

    VkFramebufferCreateInfo frameBufferInfo{};
    frameBufferInfo.renderPass = renderPass;
    frameBufferInfo.attachmentCount = 5;
    frameBufferInfo.pAttachments = framebufferAttachments;
    
    VkFramebuffer framebuffer;
    vkCreateFramebuffer(device, &frameBufferInfo, nullptr, &framebuffer);
    swapChainFramebuffers.push_back(framebuffer);
}
```

**핵심**:
- **RenderPass는 1개**: "G-Buffer 3개 + Depth + 최종 출력" 구조 정의
- **Framebuffer는 여러 개**: 스왑체인 이미지 개수만큼 (각각 최종 출력 attachment만 다름)
- **G-Buffer와 Depth는 공통**: 모든 Framebuffer에서 같은 이미지 뷰 사용
- **최종 출력만 다름**: 각 Framebuffer마다 다른 스왑체인 이미지 뷰 사용

#### ⚠️ 중요: 스왑체인 이미지 3개의 목적

**오해**: "스왑체인 이미지 3개 중 1개는 표현용, 나머지 2개는 오프스크린 타겟용"

**정확한 이유**: 스왑체인 이미지 3개는 모두 **백버퍼**입니다. 이는 **이중/삼중 버퍼링**을 위한 구조입니다.

**동작 방식**:
```cpp
// 매 프레임마다
uint32_t imageIndex;
vkAcquireNextImageKHR(device, swapChain, UINT64_MAX, imageAvailableSemaphore, VK_NULL_HANDLE, &imageIndex);
// imageIndex는 0, 1, 2 중 하나 (어떤 백버퍼를 사용할지 결정)

// 해당 인덱스의 Framebuffer 사용
VkFramebuffer framebuffer = swapChainFramebuffers[imageIndex];
vkCmdBeginRenderPass(commandBuffer, &renderPassBeginInfo, VK_SUBPASS_CONTENTS_INLINE);
// ... 렌더링 ...

// 렌더링 완료 후 Present
vkQueuePresentKHR(presentQueue, &presentInfo);  // imageIndex의 이미지를 화면에 표시
```

**왜 3개인가?**
- **이중 버퍼링**: 프론트 버퍼(화면 표시 중) + 백 버퍼(렌더링 중) = 2개
- **삼중 버퍼링**: 프론트 버퍼 + 백 버퍼 1 + 백 버퍼 2 = 3개
- GPU가 한 이미지를 렌더링하는 동안, 다른 이미지를 화면에 표시할 수 있음
- **오프스크린 타겟(G-Buffer 등)은 별도의 이미지**이며, 스왑체인과는 무관

**구조 요약**:
```
스왑체인 이미지들 (백버퍼):
├─ 이미지 0: 현재 프레임에서 렌더링 중일 수 있음
├─ 이미지 1: 다음 프레임에서 렌더링 중일 수 있음
└─ 이미지 2: 화면에 표시 중일 수 있음

오프스크린 타겟 (별도 이미지):
├─ G-Buffer 0: Albedo
├─ G-Buffer 1: Normal
├─ G-Buffer 2: Material
└─ Depth Buffer

Framebuffer 구조:
Framebuffer[0]: G-Buffer 3개 + Depth + 스왑체인 이미지 0
Framebuffer[1]: G-Buffer 3개 + Depth + 스왑체인 이미지 1  ← G-Buffer는 공통!
Framebuffer[2]: G-Buffer 3개 + Depth + 스왑체인 이미지 2  ← G-Buffer는 공통!
```

**결론**: Framebuffer를 3개 만드는 이유는 **스왑체인 이미지가 3개**이기 때문이며, 각 이미지는 **백버퍼**로 사용됩니다. 오프스크린 타겟은 별도로 생성하는 별도의 이미지입니다.

---

### 대안: RenderPass 분리 방식

위의 예시는 **하나의 RenderPass에 모든 것을 포함**한 방식입니다. 하지만 실제로는 **G-Buffer 생성과 포스트 프로세싱을 별도의 RenderPass로 분리**하는 것이 더 일반적입니다.

#### 방식 1: 하나의 RenderPass (위 예시)
- **장점**: Subpass 간 자동 동기화, 타일 기반 렌더링 최적화 가능
- **단점**: G-Buffer와 스왑체인이 같은 RenderPass에 묶여 있음

#### 방식 2: RenderPass 분리 (더 일반적)

```cpp
// RenderPass 1: G-Buffer 생성 (스왑체인과 무관)
VkAttachmentDescription gBufferAttachments[4];
gBufferAttachments[0] = gBuffer0Attachment;  // Albedo
gBufferAttachments[1] = gBuffer1Attachment;  // Normal
gBufferAttachments[2] = gBuffer2Attachment;  // Material
gBufferAttachments[3] = depthAttachment;     // Depth

VkSubpassDescription gBufferSubpass{};
gBufferSubpass.colorAttachmentCount = 3;
gBufferSubpass.pColorAttachments = gBufferRefs;
gBufferSubpass.pDepthStencilAttachment = &depthRef;

VkRenderPassCreateInfo gBufferRenderPassInfo{};
gBufferRenderPassInfo.attachmentCount = 4;
gBufferRenderPassInfo.pAttachments = gBufferAttachments;
gBufferRenderPassInfo.subpassCount = 1;
gBufferRenderPassInfo.pSubpasses = &gBufferSubpass;
VkRenderPass gBufferRenderPass;
vkCreateRenderPass(device, &gBufferRenderPassInfo, nullptr, &gBufferRenderPass);

// Framebuffer 1개만 필요 (스왑체인과 무관)
VkImageView gBufferFramebufferAttachments[4];
gBufferFramebufferAttachments[0] = gBuffer0View;
gBufferFramebufferAttachments[1] = gBuffer1View;
gBufferFramebufferAttachments[2] = gBuffer2View;
gBufferFramebufferAttachments[3] = depthView;

VkFramebufferCreateInfo gBufferFramebufferInfo{};
gBufferFramebufferInfo.renderPass = gBufferRenderPass;
gBufferFramebufferInfo.attachmentCount = 4;
gBufferFramebufferInfo.pAttachments = gBufferFramebufferAttachments;
VkFramebuffer gBufferFramebuffer;  // 1개만!
vkCreateFramebuffer(device, &gBufferFramebufferInfo, nullptr, &gBufferFramebuffer);

// RenderPass 2: 포스트 프로세싱 (스왑체인에 출력)
VkAttachmentDescription postProcessAttachments[1];
postProcessAttachments[0] = swapChainColorAttachment;

VkSubpassDescription postProcessSubpass{};
postProcessSubpass.colorAttachmentCount = 1;
postProcessSubpass.pColorAttachments = &finalColorRef;
// G-Buffer는 텍스처로 읽음 (Input Attachment가 아님, 일반 텍스처)

VkRenderPassCreateInfo postProcessRenderPassInfo{};
postProcessRenderPassInfo.attachmentCount = 1;
postProcessRenderPassInfo.pAttachments = postProcessAttachments;
postProcessRenderPassInfo.subpassCount = 1;
postProcessRenderPassInfo.pSubpasses = &postProcessSubpass;
VkRenderPass postProcessRenderPass;
vkCreateRenderPass(device, &postProcessRenderPassInfo, nullptr, &postProcessRenderPass);

// Framebuffer는 스왑체인 이미지 개수만큼
for (size_t i = 0; i < swapChainImageViews.size(); i++)
{
    VkImageView postProcessAttachments[1];
    postProcessAttachments[0] = swapChainImageViews[i];
    
    VkFramebufferCreateInfo postProcessFramebufferInfo{};
    postProcessFramebufferInfo.renderPass = postProcessRenderPass;
    postProcessFramebufferInfo.attachmentCount = 1;
    postProcessFramebufferInfo.pAttachments = postProcessAttachments;
    
    VkFramebuffer framebuffer;
    vkCreateFramebuffer(device, &postProcessFramebufferInfo, nullptr, &framebuffer);
    postProcessFramebuffers.push_back(framebuffer);
}
```

**렌더링 순서**:
```cpp
// 1. G-Buffer 생성 (스왑체인과 무관)
vkCmdBeginRenderPass(commandBuffer, &gBufferRenderPassBeginInfo, ...);
// ... 지오메트리 렌더링 ...
vkCmdEndRenderPass(commandBuffer);

// Resource Barrier: G-Buffer를 읽기 가능하게
VkImageMemoryBarrier barrier{};
barrier.oldLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
barrier.newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
// ... G-Buffer 이미지들을 텍스처로 전환 ...

// 2. 포스트 프로세싱 (스왑체인에 출력)
uint32_t imageIndex;
vkAcquireNextImageKHR(..., &imageIndex);
vkCmdBeginRenderPass(commandBuffer, &postProcessRenderPassBeginInfo, ...);
// ... 스크린 쿼드 렌더링 (G-Buffer를 텍스처로 읽음) ...
vkCmdEndRenderPass(commandBuffer);
```

**비교**:

| 방식 | G-Buffer Framebuffer | Post-Process Framebuffer | 장점 |
|------|---------------------|-------------------------|------|
| **방식 1 (하나의 RenderPass)** | 3개 (스왑체인마다) | 3개 (같은 것) | Subpass 간 자동 동기화, 타일 최적화 |
| **방식 2 (분리)** | 1개 (공통) | 3개 (스왑체인마다) | 구조가 명확, G-Buffer와 스왑체인 분리 |

**결론**: 
- **G-Buffer는 스왑체인과 무관**하므로 별도 RenderPass로 분리하는 것이 더 일반적입니다.
- **Framebuffer를 3개 만드는 이유**는 **스왑체인 이미지가 3개**이기 때문이며, 각 프레임마다 다른 스왑체인 이미지에 렌더링해야 하기 때문입니다.

---

### 요약: DX11 vs Vulkan

| DX11 | Vulkan |
|------|--------|
| `ID3D11RenderTargetView` | `VkImageView` |
| `OMSetRenderTargets(RTVs, count, DSV)` | `VkFramebuffer` (여러 `VkImageView` 묶음) |
| 매 프레임마다 RTV 설정 | RenderPass 정의 + Framebuffer 생성 (재사용) |
| MRT: 여러 RTV 배열 | Subpass에서 여러 color attachment |
| 서브패스 개념 없음 (수동 관리) | `VkSubpassDescription` (자동 동기화) |
| Resource Barrier 수동 설정 | RenderPass가 자동으로 barrier 삽입 |

**Vulkan의 장점**:
- RenderPass가 전체 렌더링 구조를 미리 알고 있어서 최적화 가능 (타일 기반 렌더링 등)
- Subpass 간 데이터 공유 시 자동 동기화
- 드라이버가 렌더링 패턴을 미리 알 수 있어 최적화 가능

---

## 핵심 개념 정리

### RenderPass와 Framebuffer의 관계

1. **RenderPass의 Attachment (슬롯)**
   - DX11의 MRT 슬롯 개념과 유사
   - "어떤 타입의 슬롯이 필요한지"를 정의하는 래퍼/설명
   - 예: "color attachment 3개, depth attachment 1개 필요"

2. **Subpass와 Attachment 참조**
   - 각 Subpass는 자신에게 맞는 슬롯 타입에 따라 Attachment를 지정
   - `VkAttachmentReference`를 통해 RenderPass의 attachment 배열 인덱스를 참조
   - 슬롯 개수는 타입에 따라 여러 개일 수 있음 (MRT의 경우) 또는 없을 수도 있음

3. **Framebuffer의 역할**
   - RenderPass에서 정의한 모든 슬롯(attachment)을 참조
   - **인덱스 기반 매핑**: RenderPass의 attachment 인덱스와 일치하게 실제 `VkImageView`를 매핑
   - `framebuffer.pAttachments[i]` → `renderPass.pAttachments[i]`

4. **Framebuffer = RenderPass의 슬롯과 이미지를 엮어주는 래퍼**
   - Framebuffer는 단순히 렌더타겟 하나를 나타내는 것이 아님
   - RenderPass에서 사용되는 모든 슬롯(attachment)에 적절한 ImageView를 할당해주는 역할

5. **일반적인 구조**
   - **오프스크린 렌더타겟용**: RenderPass 1개 & Framebuffer 1개 (G-Buffer 등, 스왑체인과 무관)
   - **스왑체인 렌더용**: RenderPass 1개 & Framebuffer 여러 개 (스왑체인 이미지 개수만큼)
     - **중요**: RenderPass는 1개만 필요 (스왑체인 이미지와 무관하게 구조만 정의)
     - Framebuffer만 스왑체인 이미지 개수만큼 생성 (각 이미지마다 다른 Framebuffer)
   - 일반적으로 여러 RenderPass를 사용하여 구분

6. **RenderPass & Framebuffer는 묶음**
   - Framebuffer는 항상 특정 RenderPass를 참조
   - Framebuffer는 해당 RenderPass의 attachment 구조에 맞게 ImageView를 제공해야 함

### 비유 정리

```
RenderPass = "레스토랑 메뉴판"
  - Attachment = "메뉴 항목" (예: 스테이크, 파스타, 샐러드)
  - Subpass = "코스" (예: 전채 코스는 샐러드, 메인 코스는 스테이크)

Framebuffer = "실제 음식"
  - RenderPass의 메뉴 항목(attachment)에 맞게 실제 음식(ImageView)을 제공
  - 메뉴 항목[0] = 스테이크 → 실제 스테이크(ImageView[0]) 제공
  - 메뉴 항목[1] = 파스타 → 실제 파스타(ImageView[1]) 제공
```

**결론**: Framebuffer는 RenderPass의 "슬롯(attachment) 정의"와 "실제 이미지(ImageView)"를 연결하는 매핑 테이블입니다.