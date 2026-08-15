# Mobile Character Rendering

一个简单、低成本的移动端角色渲染方案。项目参考 Kerry 的角色渲染教程，将 Built-in Shader 的材质逻辑移植到 URP，并保留可拆分、可调试的光照模块。

![角色效果](Screenshots/lethe.jpg)

## 技术要点

- **间接漫反射**：使用球谐光照（SH）近似环境漫反射。
- **间接镜面反射**：使用 Cubemap IBL，并根据粗糙度选择采样 mip。
- **皮肤直接光**：使用预积分 LUT 近似次表面散射（3S）质感。
- **头发高光**：使用两层各向异性高光模拟发丝反射。
- **URP 适配**：包含 Forward、ShadowCaster、DepthOnly 和 DepthNormals Pass，面向移动端控制实现成本。

## 角色渲染图

| 角色正面 | 角色视角 | 角色近景 |
| --- | --- | --- |
| ![角色正面](Screenshots/lethe.jpg) | ![角色视角](Screenshots/lethe%20%282%29.png) | ![角色近景](Screenshots/lethe%20%283%29.png) |

## 头发特写

| 发丝高光 1 | 发丝高光 2 | 发丝高光 3 |
| --- | --- | --- |
| ![头发特写 1](Screenshots/hair%20%281%29.png) | ![头发特写 2](Screenshots/hair%20%282%29.png) | ![头发特写 3](Screenshots/hair%20%283%29.png) |
| ![头发特写 4](Screenshots/hair%20%284%29.png) | ![头发特写 5](Screenshots/hair%20%285%29.png) | |

## 皮肤 3S 特写

预积分 LUT 用于近似皮肤次表面散射（3S）效果。

| 3S 特写 1 | 3S 特写 2 |
| --- | --- |
| ![3S 特写 1](Screenshots/3s%20%281%29.png) | ![3S 特写 2](Screenshots/3s%20%282%29.png) |

## 环境

- Unity `6000.3.16f1`
- Universal Render Pipeline `17.3.0`
