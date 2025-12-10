# 스왑 체인

스왑 체인은 dx의 그것과 같음. 화면에 표시되기를 기다리는 이미지들의 대기열. 애플리케이션은 이 이미지들을 가져와서 그린후 대기열로 반환한다. 스왑 체인의 일반적인 목적은 이미지 표시를 화면 주사율과 동기화하는 것이다.

#### 스왑 체인 지원 확인

모든 그래픽 카드가 화면에 이미지를 직접 표시할 수 있는 것은 아니다. 예를들어 서버용은 디스플레이 출력이없는경우도 있음. 이미지 표시는 윈도우 시스템혹은 윈도우 surface와 밀접하게 관련되어있기 떄문에 vulkan 코어의 일부가 아니다. VK\_KHR\_swapchian지원 여부를 쿼리하고 확장 프로그램을 활성화 해야한다.

```cpp
const std::vector<const char*> deviceExtensions = { VK_KHR_SWAPCHIAN_EXTENSION_NAME };
	bool isDeviceSuitable(VkPhysicalDevice device)
	{ 
		QueueFamilyIndices indices = findQueueFamilies(device);
		bool extensionsSupported = checkDeviceExtensionSupport(device);
		bool swapChainAdequate = false;
		if (extensionsSupported)
		{
			SwapChainSupportDetails swapChainSupport = querySwapChianSupport(device);
			swapChainAdequate = !swapChainSupport.formats.empty() && !swapChainSupport.presentModes.empty();
		}
		return indices.isComplete() && extensionsSupported && swapChainAdequate;
	}

	bool checkDeviceExtensionSupport(VkPhysicalDevice device)
	{
		uint32_t extensionCount;
		vkEnumerateDeviceExtensionProperties(device, nullptr, &extensionCount, nullptr);
		std::vector<VkExtensionProperties> availableExtensions(extensionCount);
		vkEnumerateDeviceExtensionProperties(device, nullptr, &extensionCount, availableExtensions.data());

		std::set<std::string> requiredExtensions(deviceExtensions.begin(), deviceExtensions.end());

		for (const auto& extension : availableExtensions)
		{
			requiredExtensions.erase(extension.extensionName);
		}

		return requiredExtensions.empty();
	}
```

#### 장치 확장 기능 활성화

스왑체인을 사용하려면 VK\_KHR\_swapchain 확장 기능을 활성화 해야한다. 논리 디바이스 만들때 구조체에 관련 내용 추가.

```cpp
	createInfo.enabledExtensionCount = static_cast<uint32_t>(deviceExtensions.size());
	createInfo.ppEnabledExtensionNames = deviceExtensions.data();
```

#### 스왑 체인 지원 세부 정보 쿼리

스왑 체인을 사용할수 있는지 확인 되었다면 윈도우 surface와 실제로 호환되는지 확인해야한다. 확인해야할 기능은 3가지

* capability(스왑체인의 최소/최대 이미지 개수, 이미지의 최소/최대 사이즈)
  * VkGetPhysicalDeviceSurfaceCapabilitiesKHR
* surface format(color format, color space)
  * VkGetPhysicalDeviceSurfaceFormatsKHR
* presentation mode
  * VkGetPhysicalDeviceSurfacePresentModesKHR

지원되는 정보를 얻어오기 위해 physicalDevice와 surface 두가지를 인자로 넘긴다.

```cpp
struct SwapChainSupportDetails
{
	VkSurfaceCapabilitiesKHR capabilites;
	std::vector<VkSurfaceFormatKHR> formats;
	std::vector<VkPresentModeKHR> presentModes;
};

SwapChainSupportDetails querySwapChianSupport(VkPhysicalDevice device)
{
	SwapChainSupportDetails details;
	vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &details.capabilites);

	uint32_t formatCount;
	vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &formatCount, nullptr);
	if (formatCount != 0)
	{
		details.formats.resize(formatCount);
		vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &formatCount, details.formats.data());
	}

	uint32_t presentModeCount;
	vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &presentModeCount, nullptr);

	if (presentModeCount != 0)
	{
		details.presentModes.resize(presentModeCount);
		vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &presentModeCount, details.presentModes.data());
	}

	return details;
}
```

#### 스왑 체인에 적합한 설정 선택

스왑 체인이 사용 가능하다면 최적의 설정을 찾는다. 세가지를 결정한다

* surface format(color, depth)
  * srgb를 사용하는걸 추천. 정확한 색상 인식을 위하여
* presentation mode
  * 트리플 버퍼링(VK\_PRESENT\_MODE\_MAILBOX\_KHR)이 품질이가장좋음. 찢어짐 방지.
  * 성능을 위해서는 수직동기화(VK\_PRESENT\_MODE\_FIFO\_KHR). 모바일 디바이스에 적합
* swap extent(스왑체인 안쪽의 이미지의 해상도)
  * 모바일과 같은 특정 플랫폼들은 os단계에서 capability의   swap extent 에 제약사항을 더많이  만든다. 반면 linux와 같은 플랫폼에서는 application에 맡긴다. currentExtent.with가 max가 되고 제약사항안에서 framebuffer가 지원하는 해상도로 swapchain을 맞춰주면된다.
    * gl fwGetFrameBufferSize는 디스플레이의 dpi가 적용된 해상도. 논리 해상도와는 다른 실제해상도. 논리해상도는 4k모니터에서 2k로 해상도를 설정해놓고 쓰는경우고, 이 경우에 frameBufferSize는 윈도우사이즈가 2k라도  dpi가 적용되어 4k가 나온다.

```cpp
VkSurfaceFormatKHR chooseSwapSurfaceFormat(const std::vector<VkSurfaceFormatKHR>& availableFormats)
{
	for (const auto& availableFormat : availableFormats)
	{
		if (availableFormat.format == VK_FORMAT_B8G8R8A8_SRGB &&
			availableFormat.colorSpace == VK_COLORSPACE_SRGB_NONLINEAR_KHR)
		{
			return availableFormat;
		}
	}
	return availableFormats[0];
}

VkPresentModeKHR chooseSwapPresentMode(const std::vector<VkPresentModeKHR>& availablePresentModes)
{
	for (const auto& availablePresentMode : availablePresentModes)
	{
		if (availablePresentMode == VK_PRESENT_MODE_MAILBOX_KHR)
		{
			return availablePresentMode;
		}
	}

	return VK_PRESENT_MODE_FIFO_KHR;
}

VkExtent2D chooseSwapExtent(const VkSurfaceCapabilitiesKHR& capabilities)
{
	if (capabilities.currentExtent.width != std::numeric_limits<uint32_t>::max())
	{
		return capabilities.currentExtent;
	}
	else
	{
		int width, height;
		glfwGetFramebufferSize(window, &width, &height);

		VkExtent2D actualExtent =
		{
			static_cast<uint32_t>(width),
			static_cast<uint32_t>(height)
		};

		actualExtent.width = std::clamp(actualExtent.width, capabilities.minImageExtent.width, 
			capabilities.maxImageExtent.width);
		actualExtent.height = std::clamp(actualExtent.height, capabilities.minImageExtent.height,
			capabilities.maxImageExtent.height);

		return actualExtent;
	}
}
```

#### 스왑 체인 생성

* 스왑 체인 이미지 카운트는 최소보다 + 1로 설정하는 것이 좋다
* imgArrayLayers는 z 차원 레이어 수. 일반 스왑체인은 하나로 된다. 스테레오 렌더링 같은 경우가 아니면 하나로 가능하다
* VK\_IMAGE\_USAGE\_COLOR\_ATTATCHMENT\_BIT가 기본. 데이터 복사를 위해서는 VK\_IMAGE\_TRANSFER\_DST\_BIT 같은 플래그도 사용 가능하다
* compistAlpha는 거의 무시하는게 좋기 때문에 OPAQUE로
* clipped는 가려진 픽셀에 대해서는 신경 안쓰는 옵션
* oldSwaphian은 창 크기 같은 변경이 있을때 이전 스왑체인에 대한 참조를 지원할지.

```cpp
void CreateSwapChain()
{
	SwapChainSupportDetails swapChainSupport = querySwapChianSupport(physicalDevice);

	VkSurfaceFormatKHR surfaceFormat = chooseSwapSurfaceFormat(swapChainSupport.formats);
	VkPresentModeKHR presentMode = chooseSwapPresentMode(swapChainSupport.presentModes);
	VkExtent2D extent = chooseSwapExtent(swapChainSupport.capabilites);
	uint32_t imageCount = swapChainSupport.capabilites.minImageCount + 1;
	if (swapChainSupport.capabilites.maxImageCount > 0 && imageCount > swapChainSupport.capabilites.maxImageCount)
	{
		imageCount = swapChainSupport.capabilites.maxImageCount;
	}

	VkSwapchainCreateInfoKHR createInfo{};
	createInfo.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
	createInfo.surface = surface;
	createInfo.minImageCount = imageCount;
	createInfo.imageFormat = surfaceFormat.format;
	createInfo.imageColorSpace = surfaceFormat.colorSpace;
	createInfo.imageExtent = extent;
	createInfo.imageArrayLayers = 1;
	createInfo.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
	
	QueueFamilyIndices indices = findQueueFamilies(physicalDevice);
	uint32_t queueFamilyIndices[] = { indices.graphicsFamily.value(), indices.presentFamily.value() };

	if (indices.graphicsFamily != indices.presentFamily)
	{
		createInfo.imageSharingMode = VK_SHARING_MODE_CONCURRENT;
		createInfo.queueFamilyIndexCount = 2;
		createInfo.pQueueFamilyIndices = queueFamilyIndices;
	}
	else
	{
		createInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
		createInfo.queueFamilyIndexCount = 0;
		createInfo.pQueueFamilyIndices = nullptr;
	}

	createInfo.preTransform = swapChainSupport.capabilites.currentTransform;
	createInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
	createInfo.presentMode = presentMode;
	createInfo.clipped = VK_TRUE;
	createInfo.oldSwapchain = VK_NULL_HANDLE;

	if (vkCreateSwapchainKHR(device, &createInfo, nullptr, &swapChain) != VK_SUCCESS)
		throw std::runtime_error("failed to create swap chain!");

	vkGetSwapchainImagesKHR(device, swapChain, &imageCount, nullptr);
	swapChainImages.resize(imageCount);
	vkGetSwapchainImagesKHR(device, swapChain, &imageCount, swapChainImages.data());

	swapChainImageFormat = surfaceFormat.format;
	swapChainExtent = extent;
}

private: 
	VkSurfaceKHR surface; 
	VkQueue presentQueue; 
	VkSwapchainKHR swapChain; 
	std::vector swapChainImages; 
	VkFormat swapChainImageFormat; 
	VkExtent2D swapChainExtent;
```
