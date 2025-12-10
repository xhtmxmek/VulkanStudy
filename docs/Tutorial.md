# 튜토리얼

공식 튜토리얼 사이트 [https://vulkan-tutorial.com/Introduction](https://vulkan-tutorial.com/Introduction)

#### 삼각형을 그리기 위한 개관

**1단계 - 인스턴스 및 물리적 장치 선택**

[`VkInstance`](https://www.khronos.org/registry/vulkan/specs/1.0/man/html/VkInstance.html) 로 vulkan 초기화.  [`VkPhysicalDevice`](https://www.khronos.org/registry/vulkan/specs/1.0/man/html/VkPhysicalDevice.html)Vulkan 지원 하드웨어를 쿼리.



**2단계 - 논리 장치 및 대기열 패밀리**

* 물리적 디바이스를 선택했으니 논리적 디바이스인 [`VkDevice`](https://www.khronos.org/registry/vulkan/specs/1.0/man/html/VkDevice.html) 를 만듬. 다중 뷰포트 렌더링 및 64비트 부동 소수점 수와 같이 디바이스의초기세팅을   [`VkPhysicalDeviceFeatures`](https://www.khronos.org/registry/vulkan/specs/1.0/man/html/VkPhysicalDeviceFeatures.html) 를  통해서  함.&#x20;
* Vulkan으로 수행되는 대부분의 작업(예: 그리기 명령 및 메모리 작업)은 [`VkQueue`](https://www.khronos.org/registry/vulkan/specs/1.0/man/html/VkQueue.html) 에제출하여 비동기적으로 실행.  queue는queue family에 의해 관리되는데, 각 family마다 지원하는 작업이 다름. 예를들어memory와 그래픽 ,컴퓨팅은 각자 다른 대기열을 가질 수 있음



**3단계 - 창 표면 및 스왑 체인**

* 네이티브 플랫폼 API나 GLTF, SDL등의 라이브러리를 이용하여 창 표현가능. 이 튜토리얼은 GLFW.
*   창에 렌더링하려면 창 표면(`VkSurfaceKHR)` 과 스왑 체인( `VkSwapchainKHR`)이 필요.

    * 창에 실제로 렌더링하려면 두 가지 구성 요소, 즉 창 표면( `VkSurfaceKHR`)과 \
      스왑 체인( `VkSwapchainKHR`)이 더 필요. `KHR`접미사는 Vulkan 확장프로그램의일부라는 의미&#x20;
    * 표면은 렌더링할 창에 대한 크로스 플랫폼 추상화이며, Windows의 `HWND` 와 같은 창에 대한 참조로 인스턴스화
    * 스왑체인은 dx의 그것과 같음. 렌더타깃의  집합. 이중 버퍼링 또는 삼중버퍼링 되어 화면에 표시됨. 백버퍼의 역할
    * 특정 플랫폼은 `VK_KHR_display` 와 `VK_KHR_display_swapchain` 를 통해서 윈도우 매니저와 통신하지 않고 전체화면 기능 사용. 이떄는 자체 윈도우 관리 로직 필요



**4단계 - 이미지 뷰 및 프레임 버퍼**

스왑 체인에서 가져온 이미지를 그리려면  해당이미지를 [`VkImageView`](https://www.khronos.org/registry/vulkan/specs/1.0/man/html/VkImageView.html) 와 [`VkFramebuffer`](https://www.khronos.org/registry/vulkan/specs/1.0/man/html/VkFramebuffer.html)로 래핑 필요.

* VkImageView : 이미지의 특정 부분을 참조.dx11의 rtv/srv에 해당
* VkFrameBuffer : 여러 imageView들의묶음.  칼라 버퍼, depth/stencil 버퍼 등



**5단계 - 패스 렌더링**

Vulkan의 렌더 패스는 렌더링 작업 중에 사용되는 이미지 유형, 이미지 사용 방식, 그리고 이미지 내용 처리 방식을 설명. [`VkFramebuffer`](https://www.khronos.org/registry/vulkan/specs/1.0/man/html/VkFramebuffer.html)는 렌더 패스에 사용되는 이미지 뷰들을 바인딩



**6단계 - 그래픽 파이프라인**

* [`VkPipeline`](https://www.khronos.org/registry/vulkan/specs/1.0/man/html/VkPipeline.html) 파이프라인 객체. 고정 파이프라인 상태(뷰포트크기, 뎁스버퍼 설정 등)
* [`VkShaderModule`](https://www.khronos.org/registry/vulkan/specs/1.0/man/html/VkShaderModule.html) 은 셰이더 바이트 코드에서 생성됨. 파이프라인에 세팅.
* 기존 API와의 차이점은 파이프라인의 모든 구성을 미리 설정해야함. 셰이더 전환이나 vertexLayout 변경 등은 [`VkPipeline`](https://www.khronos.org/registry/vulkan/specs/1.0/man/html/VkPipeline.html) (파이프라인)을 완전히 새로만들어야함. 기본 상태 객체 없고 모든 상태는 명시적으로 설명되어야함. 따라서 렌더링에 필요한 모든 조합을 미리 생성해놓아야함.
* 사전 컴파일과 JIT(Just-In-Time) 컴파일에 파이프라인 객체를 전부 생성해 놓는다.<br>

**7단계 - 명령 풀 및 명령 버퍼**

vulkan에서의 많은 작업들은 [`VkCommandBuffer`](https://www.khronos.org/registry/vulkan/specs/1.0/man/html/VkCommandBuffer.html) 에 기록하여 queue에 제출해야함. 명령 버퍼는 특정 queue faimily와 연관된  [`VkCommandPool`](https://www.khronos.org/registry/vulkan/specs/1.0/man/html/VkCommandPool.html) 에서 할당받는다. 삼각형을 그리는 명령은 다음과 같다.

* 렌더 패스 시작
* 그래픽 파이프라인 바인딩
* 3개의 정점을 그립니다
* 렌더 패스 종료

가능한 각 이미지에 대한 명령 버퍼를 기록해 놓고 그리기 시점에 적절한 이미지를 선택하는 것이 효율적이다. 다른 방법은 매 프레임마다 명령 버퍼를 다시 기록하는 것인데 이는 비효율적

**8단계 - 메인 루프**

* `vkAcquireNextImageKHR` 를 호출하여 스왑 체인에서 이미지를 가져옴
* 이미지에 적합한 명령 버퍼를 선택하고 [`vkQueueSubmit`](https://www.khronos.org/registry/vulkan/specs/1.0/man/html/vkQueueSubmit.html) 을 이용하여 실행
* `vkQueuePresentKHR` 호출하여 이미지를 스왑체인으로 반환하여 화면에 표시

큐에 제출된 작업은 비동기적으로 실행된다. 세마포어와 같은 동기화 객체로 적절한 실행순서 보장 필요

* 그리기 명령 버퍼는 이미지 수집이 완료될 때까지 기다려야함. 세마포어 사용
* `vkQueuePresentKHR` 호출은 렌더링 완료될때까지.  세마포어 사용

#### 요약 <a href="#page_summary" id="page_summary"></a>

첫 번째 삼각형을 그리려면 다음이 필요

* [`VkInstance`](https://www.khronos.org/registry/vulkan/specs/1.0/man/html/VkInstance.html) 생성
* 지원되는 그래픽 카드를 선택( [`VkPhysicalDevice`](https://www.khronos.org/registry/vulkan/specs/1.0/man/html/VkPhysicalDevice.html))
* drawing과  스왑체인에 이미지제출을 위한 [`VkDevice`](https://www.khronos.org/registry/vulkan/specs/1.0/man/html/VkDevice.html) , [`VkQueue`](https://www.khronos.org/registry/vulkan/specs/1.0/man/html/VkQueue.html) 필요
* 창, 창 표면 및 스왑 체인 생성
* 스왑 체인 이미지를 [`VkImageView`](https://www.khronos.org/registry/vulkan/specs/1.0/man/html/VkImageView.html) 로 래핑
* 렌더타깃과사용법을 지정하는 렌더 패스를 생성
* 렌더 패스에 대한 프레임 버퍼 생성
* 그래픽 파이프라인 설정
* 가능한 모든 스왑 체인 이미지에 대한 그리기 명령으로 명령 버퍼를 할당하고 기록
* 이미지를 획득 -> 올바른 그리기 명령 버퍼를 제출 -> 이미지를 스왑 체인으로 다시 반환하여 프레임을 렌더링

### API 개념 <a href="#page_api-concepts" id="page_api-concepts"></a>

이 장에서는 Vulkan API가 하위 수준에서 어떻게 구조화되어 있는지에 대한 간략한 개요를 살펴보겠습니다.

#### 코딩 규칙 <a href="#page_coding-conventions" id="page_coding-conventions"></a>

모든 Vulkan 함수, 열거형, 구조체는 [Vulkan SDK](https://lunarg.com/vulkan-sdk/) 의 `vulkan.h` 에 포함된 헤더에 정의&#x20;

* 함수는 vk접두사
* enum이나 구조체에는 Vk접두사
* enum 값에는 VK\_ 접두사

```cpp
VkXXXCreateInfo createInfo{};
createInfo.sType = VK_STRUCTURE_TYPE_XXX_CREATE_INFO;
createInfo.pNext = nullptr;
createInfo.foo = ...;
createInfo.bar = ...;

VkXXX object;
if (vkCreateXXX(&createInfo, nullptr, &object) != VK_SUCCESS) {
    std::cerr << "failed to create object" << std::endl;
    return false;
}
```

Vulkan의 대부분의 구조체는 다음과 같은 특징을 지님

* sType 멤버에 타입 지정 필요
* pNext에 멤버 확장 구조체를 가리킬 수 있음
* 객체를 생성하거나 삭제하는 함수에는 드라이버 메모리에 대한 사용자 지정 할당자를 사용할수있는콜백 ([`VkAllocationCallbacks`](https://www.khronos.org/registry/vulkan/specs/1.0/man/html/VkAllocationCallbacks.html) )이 제공됨

거의 모든 함수는 오류 코드 VkResult 또는 VK\_Success를 반환

**검증 레이어**

* 검증 레이어는 API와 그래픽 드라이버 사이에 삽입할 수 있는 코드 조각으로, 함수 매개변수에 대한 추가 검사 실행 및 메모리 관리 문제 추적 등의 작업을 수행. 개발 중에는 검증 레이어를 활성화하고, 애플리케이션을 출시할 때는 오버헤드 없이 완전히 비활성화할 수 있다
* 검증 계층이 매우 광범위 하기 떄문에 화면이 검은 이유를 추적하기가 쉬움

#### 환경설정

* VulkanSDK&#x20;
* GLM - 선형대수라이브러리
* GLFW - 윈도우창띄움
* 빈 프로젝트에 윈도우 콘솔 응용 프로그램으로 세팅

#### 샘플코드

```cpp
#define GLFW_INCLUDE_VULKAN
#include <GLFW/glfw3.h>

#define GLM_FORCE_RADIANS
#define GLM_FORCE_DEPTH_ZERO_TO_ONE
#include <glm/vec4.hpp>
#include <glm/mat4x4.hpp>

#include <iostream>

int main() {

    //glfw 초기화
    glfwInit();

    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    GLFWwindow* window = glfwCreateWindow(800, 600, "Vulkan window", nullptr, nullptr);

    //시스템이 Vulkan의 필수 확장들을 얼마나 지원하는지. 파라메터로 받아서 vulkan 초기화 부분에 넘겨줌
    uint32_t extensionCount = 0;
    vkEnumerateInstanceExtensionProperties(nullptr, &extensionCount, nullptr);

    std::cout << extensionCount << " extensions supported\n";

    glm::mat4 matrix;
    glm::vec4 vec;
    auto test = matrix * vec;

    //이벤트 처리(winAPI로 치면 MsgProc. 키보드,마우스,리사이징 등의 이벤트 받음)
    while (!glfwWindowShouldClose(window)) {
        glfwPollEvents();
    }

    glfwDestroyWindow(window);

    //glfw 종료
    glfwTerminate();

    return 0;
} 
```

&#x20;
