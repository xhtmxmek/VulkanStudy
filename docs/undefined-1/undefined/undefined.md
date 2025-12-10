# 인스턴스

####

초기화 시 VkApplicationInfo와 VkInstanceCreateInfo가 필요.  Vulkan은 OS에 완전히 독립적이므로 인스턴스생성시os에서 요구하는 확장정보를 glfw에서 얻어야함. glfwGetRequiredInstanceExtensions로 정보를 얻어서 세팅

<pre class="language-cpp"><code class="lang-cpp">        VkApplicationInfo appInfo{};
        appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
        appInfo.pApplicationName = "Hello Triangle";
        appInfo.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
        appInfo.pEngineName = "No Engine";
        appInfo.engineVersion = VK_MAKE_VERSION(1, 0, 0);
<strong>        appInfo.apiVersion = VK_MAKE_VERSION(1, 0, 0);
</strong>
        VkInstanceCreateInfo createInfo{};
        createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        createInfo.pApplicationInfo = &#x26;appInfo;

        uint32_t glfwExtensionCount = 0;
        const char** glfwExtensions;
        glfwExtensions = glfwGetRequiredInstanceExtensions(&#x26;glfwExtensionCount);

        createInfo.enabledExtensionCount = glfwExtensionCount;
        createInfo.ppEnabledExtensionNames = glfwExtensions;
        createInfo.enabledLayerCount = 0;

        if (vkCreateInstance(&#x26;createInfo, nullptr, &#x26;instance) != VK_SUCCESS)
            throw std::runtime_error("failed to craete instance!");

</code></pre>

종료시에는인스턴스  해제필요

```cpp
vkDestroyInstance(instance, nullptr)
```



