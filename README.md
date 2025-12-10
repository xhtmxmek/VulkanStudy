# Vulkan Graphics Library Study

Vulkan 그래픽스 라이브러리 학습 프로젝트입니다.

## 요구사항

- Visual Studio 2019 이상
- Vulkan SDK
- GLFW 3.4 (Windows 64-bit)
- GLM (OpenGL Mathematics) 라이브러리

## 설정

### 라이브러리 다운로드 및 설정

#### GLFW 라이브러리

1. [GLFW 다운로드 페이지](https://www.glfw.org/download.html)에서 Windows 64-bit 바이너리를 다운로드
2. 압축을 풀고 `Tutorial/Libs/` 폴더에 `glfw-3.4.bin.WIN64` 폴더를 배치

#### GLM 라이브러리

1. [GLM GitHub 릴리스 페이지](https://github.com/g-truc/glm/releases)에서 최신 버전을 다운로드
2. 압축을 풀고 `Tutorial/Libs/` 폴더에 `glm` 폴더를 배치

최종 폴더 구조:
```
Tutorial/
└── Libs/
    ├── glfw-3.4.bin.WIN64/
    │   ├── include/
    │   └── lib-vc2022/  (또는 사용하는 Visual Studio 버전에 맞는 lib 폴더)
    └── glm/
        └── glm/  (헤더 파일들이 있는 폴더)
```

### Visual Studio 프로젝트 설정

프로젝트 속성에서 다음을 설정해야 합니다:

#### 포함 디렉토리 (Additional Include Directories)

1. 프로젝트 우클릭 → **속성(Properties)**
2. **구성 속성(Configuration Properties)** → **C/C++** → **일반(General)**
3. **추가 포함 디렉토리(Additional Include Directories)**에 다음 경로 추가:
   - `$(ProjectDir)Libs\glfw-3.4.bin.WIN64\include`
   - `$(ProjectDir)Libs\glm`
   - `$(VULKAN_SDK)\Include`

#### 라이브러리 디렉토리 (Additional Library Directories)

1. **구성 속성(Configuration Properties)** → **링커(Linker)** → **일반(General)**
2. **추가 라이브러리 디렉토리(Additional Library Directories)**에 다음 경로 추가:
   - `$(VULKAN_SDK)\Lib`
   - `$(ProjectDir)Libs\glfw-3.4.bin.WIN64\lib-vc2022` (또는 사용하는 Visual Studio 버전에 맞는 폴더)

#### 링커 입력 (Additional Dependencies)

1. **구성 속성(Configuration Properties)** → **링커(Linker)** → **입력(Input)**
2. **추가 종속성(Additional Dependencies)**에 다음 라이브러리 추가:
   - `vulkan-1.lib`
   - `glfw3.lib`

**참고**: GLM은 헤더 전용 라이브러리이므로 링커 설정이 필요 없습니다.

## 빌드

Visual Studio에서 `Tutorial.sln`을 열고 빌드하세요.

## 참고

- 셰이더 파일(`.vert`, `.frag`)은 `Tutorial/shaders/` 폴더에 있습니다.
- 컴파일된 셰이더(`.spv`)는 Git에 포함되지 않으며, 빌드 시 자동 생성됩니다.
