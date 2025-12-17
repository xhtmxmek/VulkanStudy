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